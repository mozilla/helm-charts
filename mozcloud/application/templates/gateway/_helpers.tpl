{{/*
Construct gateway name based on app code, type, and configuration
Parameters:
  .appCode - The application code (e.g., $globals.app_code)
  .type - Gateway type ("external" or "internal")
  .hasMultipleTypes - Whether multiple gateway types exist (boolean)
*/}}
{{- define "gateway.name" -}}
{{- $appCode := .appCode -}}
{{- $type := .type -}}
{{- $hasMultipleTypes := .hasMultipleTypes -}}
{{- $gatewayName := $appCode }}
{{- if or $hasMultipleTypes (eq $type "internal") }}
  {{- $gatewayName = printf "%s-%s" $gatewayName $type }}
{{- end }}
{{- $gatewayName -}}
{{- end -}}
