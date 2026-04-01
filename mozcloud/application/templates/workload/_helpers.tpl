{{- /*
Renders the NGINX ConfigMap resource for the NGINX sidecar.

Params:
  config (dict):  (required) The workload configuration.
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
