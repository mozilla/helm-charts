{{/*
Expand the name of the chart.
*/}}
{{- define "mozcloud-service-lib.name" -}}
{{- default .Chart.Name (index . "name") | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "mozcloud-service-lib.fullname" -}}
{{- if (index . "fullnameOverride") }}
{{- index . "fullnameOverride" | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name (index . "name") }}
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
{{- define "mozcloud-service-lib.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "mozcloud-service-lib.labels" -}}
{{- if (index . "labels") -}}
{{- index . "labels" | toYaml }}
{{- else -}}
helm.sh/chart: {{ include "mozcloud-service-lib.chart" . }}
{{ include "mozcloud-service-lib.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/component: service
{{- end }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "mozcloud-service-lib.selectorLabels" -}}
{{- if (index . "selectorLabels") -}}
{{- index . "selectorLabels" | toYaml }}
{{- else -}}
app.kubernetes.io/name: {{ include "mozcloud-service-lib.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
{{- end }}

{{/*
Defaults
*/}}
{{- define "mozcloud-service-lib.defaults.config" -}}
# Configurables for service
config:
  # See https://kubernetes.io/docs/concepts/services-networking/service/ for
  # information on how to configure a service
  ports:
    - port: 80
      targetPort: http
      protocol: TCP
      name: http
  type: ClusterIP
{{- end }}
