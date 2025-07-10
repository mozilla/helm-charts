{{/*
Expand the name of the chart.
*/}}
{{- define "mozcloud-ingress.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "mozcloud-ingress.fullname" -}}
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
{{- define "mozcloud-ingress.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create label parameters to be used in library chart if defined as values.
*/}}
{{- define "mozcloud-ingress.labelParams" -}}
{{- $params := dict "chartName" (include "mozcloud-ingress.name" .) -}}
{{- $label_params := list "appCode" "component" "environment" -}}
{{- range $label_param := $label_params -}}
  {{- if index $.Values $label_param -}}
    {{- $_ := set $params $label_param (index $.Values $label_param) -}}
  {{- end }}
{{- end }}
{{- $params | toYaml }}
{{- end }}
