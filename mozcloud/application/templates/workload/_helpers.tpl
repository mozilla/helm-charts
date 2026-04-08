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
Renders init containers for a workload pod template.

Params:
  config (dict):               (required) The workload configuration.
  defaultSecretEnabled (bool): (required) Whether the default secret is enabled.
  defaultSecretName (string):  (required) Name of the default ExternalSecret.
  globals (dict):              (required) .Values.global.mozcloud.
  initContainers (dict):       (required) Formatted init containers.
  name (string):               (required) The workload name.
  prefix (string):             (required) Preview prefix (empty if not preview).

Returns:
  (string) YAML list items for all init containers.
*/ -}}
{{- define "mozcloud.workload.initContainers" -}}
{{- $config := .config -}}
{{- $initContainers := .initContainers -}}
{{- $globals := .globals -}}
{{- $name := .name -}}
{{- $prefix := .prefix -}}
{{- $defaultSecretName := .defaultSecretName -}}
{{- $defaultSecretEnabled := .defaultSecretEnabled -}}
{{- range $containerName, $containerConfig := $initContainers }}
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
  {{- if $containerConfig.env }}
  env:
    {{- range $envVarKey, $envVarValue := $containerConfig.env }}
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
    - secretRef:
        name: {{ printf "%s%s" $prefix $secret }}
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
  resources:
    {{- $resourceParams := dict "requests" (dict "cpu" $containerConfig.resources.cpu "memory" $containerConfig.resources.memory) }}
    {{- include "pod.container.resources" $resourceParams | nindent 4 }}
  {{- /* Sidecars run as init containers need restartPolicy: Always configured */ -}}
  {{- if (dig "sidecar" false $containerConfig) }}
  restartPolicy: Always
  {{- end }}
  securityContext:
    {{- include "pod.container.securityContext" (default dict $containerConfig.securityContext) | nindent 4 }}
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
