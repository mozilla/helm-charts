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
{{- $label_params := list "app_code" "chart" "component_code" "environment" -}}
{{- range $label_param := $label_params -}}
  {{- if index $.Values.global.mozcloud $label_param -}}
    {{- $_ := set $params $label_param (index $.Values.global.mozcloud $label_param) -}}
  {{- end }}
{{- end }}
{{- $params | toYaml }}
{{- end }}
