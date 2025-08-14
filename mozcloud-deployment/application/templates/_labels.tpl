{{- define "mozcloud-deployment.labels" -}}
app.moz.cloud/domain: {{ .Values.global.labels.domain }}
app.moz.cloud/app_code: {{ .Values.global.labels.app_code }}
app.moz.cloud/realm: {{ .Values.global.labels.realm }}
app.moz.cloud/env: {{ .Values.global.labels.env }}
{{- end -}}
