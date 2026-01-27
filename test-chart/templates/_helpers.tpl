{{- define "test-chart.foo" -}}
{{- include "test-subchart.foo" . -}}
{{- end -}}
