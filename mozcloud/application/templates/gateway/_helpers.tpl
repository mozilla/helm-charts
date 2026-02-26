{{/*
Construct gateway name based on app code, type, and configuration
Parameters:
  .appCode - The application code (e.g., $globals.app_code)
  .type - Gateway type ("external" or "internal")
  .hasMultipleTypes - Whether multiple gateway types exist (boolean)
  .multiCluster - Whether this is a multi-cluster gateway (boolean)
*/}}
{{- define "gateway.name" -}}
{{- $appCode := .appCode -}}
{{- $type := .type -}}
{{- $hasMultipleTypes := .hasMultipleTypes -}}
{{- $multiCluster := .multiCluster -}}
{{- $gatewayName := $appCode }}
{{- if or $hasMultipleTypes (eq $type "internal") }}
  {{- $gatewayName = printf "%s-%s" $gatewayName $type }}
{{- end }}
{{- if $multiCluster }}
  {{- $gatewayName = printf "%s-mc" $gatewayName }}
{{- end }}
{{- $gatewayName -}}
{{- end -}}
