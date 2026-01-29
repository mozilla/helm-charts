{{/*
Expand the name of the chart.
*/}}
{{- define "mozcloud-workload-stateless.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create label parameters to be used in library chart if defined as values.
*/}}
{{- define "mozcloud-workload-stateless.labelParams" -}}
{{- $params := dict "chart" (include "mozcloud-workload-stateless.name" .) -}}
{{- $label_params := list "app_code" "artifact_id" "chart" "env_code" "project_id" -}}
{{- range $label_param := $label_params -}}
  {{- if index $.Values.global.mozcloud $label_param -}}
    {{- $_ := set $params $label_param (index $.Values.global.mozcloud $label_param) -}}
  {{- end }}
{{- end }}
{{- if and (not .Values.component) (not .Values.global.mozcloud.component_code) }}
  {{- fail "A component must be set. You can set this either using .Values.mozcloud-workload-stateless.component or .Values.global.mozcloud.component_code. See values.yaml in the mozcloud-workload-stateless chart for more details." }}
{{- else }}
  {{- $_ := set $params "component_code" (default (.Values.global.mozcloud.component_code) .Values.component) }}
{{- end }}
{{- $params | toYaml }}
{{- end }}
