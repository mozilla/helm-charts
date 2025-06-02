{{/*
Expand the name of the chart.
*/}}
{{- define "mozcloud-service.name" -}}
{{- default .Chart.Name .Values.service.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "mozcloud-service.fullname" -}}
{{- if .Values.service.fullnameOverride }}
{{- .Values.service.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.service.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "mozcloud-service.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "mozcloud-service.labels" -}}
{{- if .Values.service.labels -}}
{{- .Values.service.labels | toYaml }}
{{- else -}}
helm.sh/chart: {{ include "mozcloud-service.chart" . }}
{{ include "mozcloud-service.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/component: service
{{- end }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "mozcloud-service.selectorLabels" -}}
{{- if .Values.service.selectorLabels }}
{{- .Values.service.selectorLabels | toYaml }}
{{- else }}
app.kubernetes.io/name: {{ include "mozcloud-service.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
{{- end }}

{{/*
Merge values with defaults
*/}}
{{- define "mozcloud-service.config.ports" -}}
{{- if .Values.service.config.ports }}
{{- .Values.service.config.ports | toYaml }}
{{- else }}
- port: 80
  targetPort: http
  protocol: TCP
  name: http
{{- end }}
{{- end }}

{{- define "mozcloud-service.config.type" -}}
{{- if .Values.service.config.type -}}
{{ .Values.service.config.type }}
{{- else -}}
ClusterIP
{{- end }}
{{- end }}
