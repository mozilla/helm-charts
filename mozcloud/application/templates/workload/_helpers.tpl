{{- /*
Renders the NGINX ConfigMap resource for the NGINX sidecar.

Params:
  labels (dict):  (required) Labels object with .labels key.
  name (string):  (required) The workload name.

Returns:
  (string) YAML for the NGINX ConfigMap resource.
*/ -}}
{{- define "mozcloud.workload.nginxConfigMap" -}}
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ .name }}-nginx
  labels:
    {{- .labels.labels | toYaml | nindent 4 }}
data:
  nginx.conf: |
    {{- include "workload.nginx.conf" . | nindent 4 }}
{{- end -}}


{{- /*
Renders all volume definitions for a workload pod template, including the
NGINX configmap volume (when enabled) and all user-defined volumes.

Params:
  nginxConfigMapName (string): (required) Name of the NGINX configmap.
  nginxEnabled (bool):         (required) Whether the NGINX sidecar is enabled.
  volumes (dict):              (required) All volumes keyed by name.

Returns:
  (string) YAML list items for all volumes.
*/ -}}
{{- define "mozcloud.workload.volumes" -}}
{{- if .nginxEnabled }}
- name: nginx-conf
  configMap:
    name: {{ .nginxConfigMapName }}
{{- end }}
{{- range $volumeName, $volumeConfig := .volumes }}
{{- /* Skip nginx configmap volume since it's already added as nginx-conf above */ -}}
{{- $skip := false }}
{{- if and $.nginxEnabled $.nginxConfigMapName (eq $volumeConfig.type "configMap") }}
  {{- if eq $volumeName $.nginxConfigMapName }}
    {{- $skip = true }}
  {{- end }}
{{- end }}
{{- if not $skip }}
- name: {{ $volumeName }}
  {{- if eq $volumeConfig.type "persistentVolume" }}
  persistentVolumeClaim:
    claimName: {{ $volumeName }}
  {{- else if eq $volumeConfig.type "emptyDir" }}
  {{- if or $volumeConfig.medium $volumeConfig.sizeLimit }}
  emptyDir:
    {{- if $volumeConfig.medium }}
    medium: {{ $volumeConfig.medium }}
    {{- end }}
    {{- if $volumeConfig.sizeLimit }}
    sizeLimit: {{ $volumeConfig.sizeLimit }}
    {{- end }}
  {{- else }}
  emptyDir: {}
  {{- end }}
  {{- else }}
  {{- if eq $volumeConfig.type "configMap" }}
  configMap:
    name: {{ $volumeName }}
  {{- else if eq $volumeConfig.type "secret" }}
  secret:
    secretName: {{ $volumeName }}
  {{- end }}
  {{- end }}
{{- end }}
{{- end }}
{{- end -}}


{{- /*
Renders a list of containers for a workload pod template. Supports both
spec.containers and spec.initContainers via the type param.

When type is "container", liveness and readiness probes are rendered and OTEL
environment variables are injected if enabled. When type is "initContainer",
probes are omitted and a restartPolicy of Always is set for sidecar containers.

Params:
  config (dict):                         (required) The workload configuration.
  containers (dict):                     (required) Formatted containers map.
  defaultSecretEnabled (bool):           (required) Whether the default secret is enabled.
  defaultSecretName (string):            (required) Name of the default ExternalSecret.
  globals (dict):                        (required) .Values.global.mozcloud.
  name (string):                         (required) The workload name.
  otelAutoInstrumentationEnabled (bool): (optional) Whether OTEL auto-instrumentation is enabled.
  otelContainerNames (list):             (optional) Container names with OTEL enabled.
  otelEnabled (bool):                    (optional) Whether OTEL is enabled for the workload.
  prefix (string):                       (required) Preview prefix (empty if not preview).
  type (string):                         (required) "container" or "initContainer".

Returns:
  (string) YAML list items for all containers.
*/ -}}
{{- define "mozcloud.workload.containers" -}}
{{- $config := .config -}}
{{- $containers := .containers -}}
{{- $globals := .globals -}}
{{- $name := .name -}}
{{- $prefix := .prefix -}}
{{- $defaultSecretName := .defaultSecretName -}}
{{- $defaultSecretEnabled := .defaultSecretEnabled -}}
{{- $type := .type -}}
{{- $otelEnabled := default false .otelEnabled -}}
{{- $otelContainerNames := default list .otelContainerNames -}}
{{- $otelAutoInstrumentationEnabled := default false .otelAutoInstrumentationEnabled -}}
{{- range $containerName, $containerConfig := $containers }}
{{- $portName := include "mozcloud.portName" $containerName }}
- name: {{ $containerName }}
  {{- $imageParams := dict "containerImage" $containerConfig.image "globalImage" $globals.image "workloadName" $name "containerName" $containerName }}
  image: {{ include "mozcloud.image" $imageParams }}
  imagePullPolicy: {{ $containerConfig.imagePullPolicy }}
  {{- if $containerConfig.command }}
  command:
    {{- range $line := $containerConfig.command }}
    - {{ $line | quote }}
    {{- end }}
  {{- end }}
  {{- if $containerConfig.args }}
  args:
    {{- range $line := $containerConfig.args }}
    - {{ $line | quote }}
    {{- end }}
  {{- end }}
  {{- $otelContainerEnabled := and $otelEnabled (not $otelAutoInstrumentationEnabled) (has $containerName $otelContainerNames) }}
  {{- if or $containerConfig.envVars $otelContainerEnabled $containerConfig.envFromFields }}
  env:
    {{- if $otelContainerEnabled }}
    - name: HOST_IP
      valueFrom:
        fieldRef:
          apiVersion: v1
          fieldPath: status.hostIP
    {{- end }}
    {{- range $fieldName, $fieldPath := $containerConfig.envFromFields }}
    - name: {{ $fieldName }}
      valueFrom:
        fieldRef:
          fieldPath: {{ $fieldPath }}
    {{- end }}
    {{- range $envVarKey, $envVarValue := $containerConfig.envVars }}
    - name: {{ $envVarKey }}
      value: {{ $envVarValue | quote }}
    {{- end }}
  {{- end }}
  {{- if or $containerConfig.configMaps $defaultSecretEnabled $containerConfig.secrets }}
  envFrom:
    {{- if $containerConfig.configMaps }}
    {{- range $configMap := $containerConfig.configMaps }}
    - configMapRef:
        name: {{ printf "%s%s" $prefix $configMap }}
    {{- end }}
    {{- end }}
    {{- if $defaultSecretEnabled }}
    - secretRef:
        name: {{ $defaultSecretName }}
    {{- end }}
    {{- if $containerConfig.secrets }}
    {{- range $secret := $containerConfig.secrets }}
    {{- $qualifiedName := printf "%s%s" $prefix $secret }}
    {{- if not (and $defaultSecretEnabled (eq $qualifiedName $defaultSecretName)) }}
    - secretRef:
        name: {{ $qualifiedName }}
    {{- end }}
    {{- end }}
    {{- end }}
  {{- end }}
  {{- if or
      $config.hosts
      (($containerConfig.healthCheck).readiness).enabled
      (($containerConfig.healthCheck).liveness).enabled
  }}
  ports:
    - name: {{ $portName }}
      containerPort: {{ $containerConfig.port }}
  {{- end }}
  {{- if eq $type "container" }}
  {{- if (dig "healthCheck" "liveness" "enabled" true $containerConfig) }}
  livenessProbe:
    httpGet:
      {{- if (($containerConfig.healthCheck).liveness).httpHeaders }}
      httpHeaders:
        {{- range $header := $containerConfig.healthCheck.liveness.httpHeaders }}
        - name: {{ $header.name }}
          value: {{ $header.value }}
        {{- end }}
      {{- else if (($containerConfig.healthCheck).readiness).httpHeaders }}
      httpHeaders:
        {{- range $header := $containerConfig.healthCheck.readiness.httpHeaders }}
        - name: {{ $header.name }}
          value: {{ $header.value }}
        {{- end }}
      {{- end }}
      path: {{ default "/__lbheartbeat__" $containerConfig.healthCheck.liveness.path }}
      port: {{ $portName }}
    {{- if (($containerConfig.healthCheck).liveness).probes }}
    {{- range $k, $v := $containerConfig.healthCheck.liveness.probes }}
    {{ $k }}: {{ $v }}
    {{- end }}
    {{- else if (($containerConfig.healthCheck).readiness).probes }}
    {{- range $k, $v := $containerConfig.healthCheck.readiness.probes }}
    {{ $k }}: {{ $v }}
    {{- end }}
    {{- end }}
  {{- end }}
  {{- if (dig "healthCheck" "readiness" "enabled" true $containerConfig) }}
  readinessProbe:
    httpGet:
      {{- if (($containerConfig.healthCheck).readiness).httpHeaders }}
      httpHeaders:
        {{- range $header := $containerConfig.healthCheck.readiness.httpHeaders }}
        - name: {{ $header.name }}
          value: {{ $header.value }}
        {{- end }}
      {{- end }}
      path: {{ default "/__lbheartbeat__" $containerConfig.healthCheck.readiness.path }}
      port: {{ $portName }}
    {{- if (($containerConfig.healthCheck).readiness).probes }}
    {{- range $k, $v := $containerConfig.healthCheck.readiness.probes }}
    {{ $k }}: {{ $v }}
    {{- end }}
    {{- end }}
  {{- end }}
  {{- end }}
  resources:
    {{- $resourceParams := dict "requests" (dict "cpu" $containerConfig.resources.cpu "memory" $containerConfig.resources.memory) }}
    {{- include "pod.container.resources" $resourceParams | nindent 4 }}
  {{- /* Sidecars run as init containers need restartPolicy: Always configured */ -}}
  {{- if and (eq $type "initContainer") (dig "sidecar" false $containerConfig) }}
  restartPolicy: Always
  {{- end }}
  securityContext:
    {{- include "pod.container.securityContext" (default dict $containerConfig.security) | nindent 4 }}
  {{- if $containerConfig.volumes }}
  volumeMounts:
    {{- range $volume := $containerConfig.volumes }}
    - name: {{ $volume.name }}
      mountPath: {{ $volume.path }}
      {{- if $volume.key }}
      subPath: {{ $volume.key }}
      {{- end }}
      {{- if eq $volume.type "secret" }}
      readOnly: true
      {{- else if $volume.readOnly }}
      readOnly: {{ $volume.readOnly }}
      {{- end }}
    {{- end }}
  {{- end }}
{{- end }}
{{- end -}}
