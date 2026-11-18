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
