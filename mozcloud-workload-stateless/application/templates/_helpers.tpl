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
{{- $params := dict "chartName" (include "mozcloud-workload-stateless.name" .) -}}
{{- $label_params := list "appCode" "component" "environment" -}}
{{- range $label_param := $label_params -}}
  {{- if index $.Values $label_param -}}
    {{- $_ := set $params $label_param (index $.Values $label_param) -}}
  {{- end }}
{{- end }}
{{- $params | toYaml }}
{{- end }}
