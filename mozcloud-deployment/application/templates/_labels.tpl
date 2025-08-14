{{- define "mozcloud-deployment.labels" -}}
moz.cloud/domain: {{ .Values.global.labels.domain }}
moz.cloud/app_code: {{ .Values.global.labels.app_code }}
moz.cloud/realm: {{ .Values.global.labels.realm }}
moz.cloud/env: {{ .Values.global.labels.env }}
{{- end -}}
