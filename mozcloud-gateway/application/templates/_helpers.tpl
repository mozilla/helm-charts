{{/*
Expand the name of the chart.
*/}}
{{- define "application.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "application.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
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
{{- define "application.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "application.labels" -}}
helm.sh/chart: {{ include "application.chart" . }}
{{ include "application.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "application.selectorLabels" -}}
app.kubernetes.io/name: {{ include "application.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "application.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "application.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Create label parameters to be used in library chart if defined as values.
*/}}
{{- define "mozcloud-gateway.labelParams" -}}
{{- $params := dict "chartName" (include "mozcloud-gateway.name" .) -}}
{{- $label_params := list "appCode" "component" "environment" -}}
{{- range $label_param := $label_params -}}
  {{- if index $.Values $label_param -}}
    {{- $_ := set $params $label_param (index $.Values $label_param) -}}
  {{- end }}
{{- end }}
{{- $params | toYaml }}
{{- end }}
