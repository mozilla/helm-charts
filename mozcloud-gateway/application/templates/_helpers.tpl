{{/*
Expand the name of the chart.
*/}}
{{- define "mozcloud-gateway.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "mozcloud-gateway.fullname" -}}
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
{{- define "mozcloud-gateway.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "mozcloud-gateway.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "mozcloud-gateway.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Create label parameters to be used in library chart if defined as values.
*/}}
{{- define "mozcloud-gateway.labelParams" -}}
{{- $params := dict "chart" (include "mozcloud-gateway.name" .) -}}
{{- $label_params := list "app_code" "chart" "component_code" "env_code" -}}
{{- range $label_param := $label_params -}}
  {{- if index $.Values.global.mozcloud $label_param -}}
    {{- $_ := set $params $label_param (index $.Values.global.mozcloud $label_param) -}}
  {{- end }}
{{- end }}
{{- $params | toYaml }}
{{- end }}
