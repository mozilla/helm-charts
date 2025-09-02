{{- define "mozcloud-deployment.labels" -}}
moz.cloud/domain: {{ .Values.global.mozcloud.domain }}
moz.cloud/app_code: {{ .Values.global.mozcloud.app_code }}
moz.cloud/realm: {{ .Values.global.mozcloud.realm }}
moz.cloud/env: {{ .Values.global.mozcloud.env }}
{{- end -}}
