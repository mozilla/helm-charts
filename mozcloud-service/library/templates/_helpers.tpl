{{/*
Expand the name of the chart.
*/}}
{{- define "mozcloud-service-lib.name" -}}
{{- default "mozcloud-service-lib" (index . "name") | trunc 63 | trimSuffix "-" }}
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
{{- include "mozcloud-service-lib.name" . }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "mozcloud-service-lib.chart" -}}
{{- $name := default (include "mozcloud-service-lib.name" .) (.Chart).Name }}
{{- $version := default "0.0.1" (.Chart).Version }}
{{- printf "%s-%s" $name $version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "mozcloud-service-lib.labels" -}}
{{- $labels := include "mozcloud-labels-lib.labels" . | fromYaml -}}
{{- if .labels -}}
  {{- $labels = mergeOverwrite $labels .labels -}}
{{- end -}}
{{- $labels | toYaml }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "mozcloud-service-lib.selectorLabels" -}}
{{- $selector_labels := include "mozcloud-labels-lib.selectorLabels" . | fromYaml -}}
{{- if .selectorLabels -}}
  {{- $selector_labels = mergeOverwrite $selector_labels .selectorLabels -}}
{{- end }}
{{- $selector_labels | toYaml }}
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
