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
Renders the volumeMounts list items for a list of volumes, used for app
containers and the NGINX sidecar so both mount volumes the same way.

Params:
  . (list): (required) Volumes, each with name, type and path, and optionally
            key (mounted as subPath) and readOnly.

Returns:
  (string) YAML list items for a container's volumeMounts.
*/ -}}
{{- define "mozcloud.workload.volumeMounts" -}}
{{- range $volume := . }}
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
{{- end -}}


{{- /*
Renders all volume definitions for a pod template, including the NGINX
configmap volume (when enabled) and all user-defined volumes.

Used by both the workload pod template and the task (Job/CronJob) pod template;
task callers pass nginxEnabled false.

Params:
  nginxConfigMapName (string): (optional) Name of the NGINX configmap. Required
                               when nginxEnabled is true; omit otherwise.
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
  {{- else if eq $volumeConfig.type "ephemeral" }}
  ephemeral:
    volumeClaimTemplate:
      spec:
        accessModes:
          {{- range $accessMode := $volumeConfig.accessModes }}
          - {{ $accessMode }}
          {{- end }}
        resources:
          requests:
            storage: {{ $volumeConfig.size }}
        storageClassName: {{ $volumeConfig.storageClassName | default "standard-rwo" }}
  {{- else if eq $volumeConfig.type "gcsFuseCsi" }}
  {{- include "mozcloud.volumes.gcsFuseCsi" (dict "config" $volumeConfig) | nindent 2 }}
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
Returns the Reloader (https://github.com/stakater/Reloader) auto-restart
annotation when enabled via .Values.reloader.enabled, the chart-wide default.
A workload's own reloader.enabled (true or false) overrides that default.
Applied to a workload's own resource annotations only (Deployment/
StatefulSet/Rollout), never the pod template, since that is what Reloader
watches.

Params:
  config (dict):  (required) The workload configuration for this workload.
  context (dict): (required) The Helm root context.

Returns:
  (string) YAML-encoded annotation key-value pair, or an empty string when
           disabled.
*/ -}}
{{- define "mozcloud.workload.reloaderAnnotation" -}}
{{- $chartDefault := dig "enabled" false (default dict .context.Values.reloader) -}}
{{- if dig "reloader" "enabled" $chartDefault (default dict .config) }}
reloader.stakater.com/auto: "true"
{{- end }}
{{- end -}}


{{- /*
Renders containers for workload pods and init containers for task pods.

When type is "container", startup, liveness and readiness probes are rendered
and OTEL environment variables are injected if enabled. Native sidecars get
restartPolicy: Always and render only explicitly enabled probes. Regular init
containers cannot have probes.

Params:
  config (dict):                         (optional) The workload configuration.
  containers (dict):                     (required) Formatted containers map.
  defaultSecretEnabled (bool):           (optional) Whether the default secret is enabled.
  defaultSecretName (string):            (optional) Name of the default ExternalSecret.
  globals (dict):                        (required) .Values.global.mozcloud.
  name (string):                         (required) The workload or task name.
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
{{- $isAppContainer := eq $type "container" }}
{{- $isInitSidecar := and (eq $type "initContainer") (dig "sidecar" false $containerConfig) }}
{{- $portName := include "mozcloud.portName" (dict "name" $containerName "containerConfig" $containerConfig) }}
- name: {{ $containerName }}
  {{- $imageParams := dict "containerImage" $containerConfig.image "globalImage" $globals.image "workloadName" $name "containerName" $containerName }}
  image: {{ include "mozcloud.image" $imageParams }}
  imagePullPolicy: {{ $containerConfig.imagePullPolicy }}
  {{- if $containerConfig.command }}
  command:
    {{- range $line := ternary (list $containerConfig.command) $containerConfig.command (kindIs "string" $containerConfig.command) }}
    - {{ $line | quote }}
    {{- end }}
  {{- end }}
  {{- if $containerConfig.args }}
  args:
    {{- range $line := ternary (list $containerConfig.args) $containerConfig.args (kindIs "string" $containerConfig.args) }}
    - {{ $line | quote }}
    {{- end }}
  {{- end }}
  {{- if $containerConfig.workingDir }}
  workingDir: {{ $containerConfig.workingDir | quote }}
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
  {{- $startupProbe := and (or $isAppContainer $isInitSidecar) (dig "healthCheck" "startup" "enabled" false $containerConfig) }}
  {{- $livenessProbe := and (or $isAppContainer $isInitSidecar) (dig "healthCheck" "liveness" "enabled" $isAppContainer $containerConfig) }}
  {{- $readinessProbe := and (or $isAppContainer $isInitSidecar) (dig "healthCheck" "readiness" "enabled" $isAppContainer $containerConfig) }}
  {{- $emitAppPort := and $isAppContainer (or
      $config.hosts
      (($containerConfig.healthCheck).readiness).enabled
      (($containerConfig.healthCheck).liveness).enabled
      (($containerConfig.healthCheck).startup).enabled
  ) }}
  {{- $emitSidecarPort := and $isInitSidecar (not (empty $containerConfig.port)) (or $startupProbe $livenessProbe $readinessProbe) }}
  {{- $emitPrimaryPort := or $emitAppPort $emitSidecarPort }}
  {{- $probePort := ternary $portName 8000 (or $isAppContainer $emitSidecarPort) }}
  {{- $additionalPorts := default list $containerConfig.additionalPorts }}
  {{- if or $emitPrimaryPort $additionalPorts }}
  ports:
    {{- if $emitPrimaryPort }}
    - name: {{ $portName }}
      containerPort: {{ $containerConfig.port }}
    {{- end }}
    {{- range $additionalPort := $additionalPorts }}
    - containerPort: {{ $additionalPort.port }}
      {{- if $additionalPort.name }}
      name: {{ include "mozcloud.portName" (dict "name" $additionalPort.name) }}
      {{- end }}
    {{- end }}
  {{- end }}
  {{- if $startupProbe }}
  startupProbe:
    {{- if (($containerConfig.healthCheck).startup).exec }}
    exec:
      command:
        {{- toYaml $containerConfig.healthCheck.startup.exec.command | nindent 8 }}
    {{- else if hasKey (dig "healthCheck" "startup" dict $containerConfig) "tcpSocket" }}
    tcpSocket:
      port: {{ dig "healthCheck" "startup" "tcpSocket" "port" $probePort $containerConfig }}
    {{- else }}
    httpGet:
      {{- if (($containerConfig.healthCheck).startup).httpHeaders }}
      httpHeaders:
        {{- range $header := $containerConfig.healthCheck.startup.httpHeaders }}
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
      path: {{ default "/__lbheartbeat__" $containerConfig.healthCheck.startup.path }}
      port: {{ default $probePort $containerConfig.healthCheck.startup.port }}
    {{- end }}
    {{- /*
    Unlike the liveness probe below, the startup probe does not fall back to the
    readiness timings. A startup budget is deliberately chosen per application
    and must not silently inherit an unrelated interval.
    */}}
    {{- if (($containerConfig.healthCheck).startup).probes }}
    {{- range $k, $v := $containerConfig.healthCheck.startup.probes }}
    {{ $k }}: {{ $v }}
    {{- end }}
    {{- end }}
  {{- end }}
  {{- if $livenessProbe }}
  livenessProbe:
    {{- if (($containerConfig.healthCheck).liveness).exec }}
    exec:
      command:
        {{- toYaml $containerConfig.healthCheck.liveness.exec.command | nindent 8 }}
    {{- else if hasKey (dig "healthCheck" "liveness" dict $containerConfig) "tcpSocket" }}
    tcpSocket:
      port: {{ dig "healthCheck" "liveness" "tcpSocket" "port" $probePort $containerConfig }}
    {{- else }}
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
      {{- /* Not inherited from readiness: like path, port picks the probe target. */}}
      port: {{ default $probePort $containerConfig.healthCheck.liveness.port }}
    {{- end }}
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
  {{- if $readinessProbe }}
  readinessProbe:
    {{- if (($containerConfig.healthCheck).readiness).exec }}
    exec:
      command:
        {{- toYaml $containerConfig.healthCheck.readiness.exec.command | nindent 8 }}
    {{- else if hasKey (dig "healthCheck" "readiness" dict $containerConfig) "tcpSocket" }}
    tcpSocket:
      port: {{ dig "healthCheck" "readiness" "tcpSocket" "port" $probePort $containerConfig }}
    {{- else }}
    httpGet:
      {{- if (($containerConfig.healthCheck).readiness).httpHeaders }}
      httpHeaders:
        {{- range $header := $containerConfig.healthCheck.readiness.httpHeaders }}
        - name: {{ $header.name }}
          value: {{ $header.value }}
        {{- end }}
      {{- end }}
      path: {{ default "/__lbheartbeat__" $containerConfig.healthCheck.readiness.path }}
      port: {{ default $probePort $containerConfig.healthCheck.readiness.port }}
    {{- end }}
    {{- if (($containerConfig.healthCheck).readiness).probes }}
    {{- range $k, $v := $containerConfig.healthCheck.readiness.probes }}
    {{ $k }}: {{ $v }}
    {{- end }}
    {{- end }}
  {{- end }}
  resources:
    {{- $resourceParams := dict "requests" (omit $containerConfig.resources "limits") -}}
    {{- if $containerConfig.resources.limits -}}
      {{- $_ := set $resourceParams "limits" $containerConfig.resources.limits -}}
    {{- end -}}
    {{- include "pod.container.resources" $resourceParams | nindent 4 }}
  {{- /* Sidecars run as init containers need restartPolicy: Always configured */ -}}
  {{- if $isInitSidecar }}
  restartPolicy: Always
  {{- end }}
  securityContext:
    {{- include "pod.container.securityContext" (default dict $containerConfig.security) | nindent 4 }}
  {{- if and $containerConfig.lifecycle (or $isAppContainer $isInitSidecar) }}
  lifecycle:
    {{- $containerConfig.lifecycle | toYaml | nindent 4 }}
  {{- end }}
  {{- if $containerConfig.volumes }}
  volumeMounts:
    {{- include "mozcloud.workload.volumeMounts" $containerConfig.volumes | nindent 4 }}
  {{- end }}
{{- end }}
{{- end -}}
