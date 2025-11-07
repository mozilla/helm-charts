{{/*
Expand the name of the chart.
*/}}
{{- define "mozcloud-preview-lib.name" -}}
{{- if .nameOverride -}}
{{- .nameOverride }}
{{- else -}}
mozcloud-preview
{{- end -}}
{{- end -}}
{{- /*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "mozcloud-preview-lib.fullname" -}}
{{- if .fullnameOverride -}}
{{- .fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else -}}
{{- include "mozcloud-preview-lib.name" . }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "mozcloud-preview-lib.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "mozcloud-preview-lib.labels" -}}
{{- if .labels -}}
{{- .labels | toYaml }}
{{- else -}}
helm.sh/chart: {{ default "mozcloud-preview" (.Chart).Name }}
{{- if (.Chart).AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion }}
{{- end }}
app.kubernetes.io/component: {{ default "preview" .component }}
{{ include "mozcloud-preview-lib.selectorLabels" . }}
{{- end }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "mozcloud-preview-lib.selectorLabels" -}}
{{- if .selectorLabels -}}
{{- .selectorLabels | toYaml }}
{{- else -}}
app.kubernetes.io/name: {{ default "mozcloud-webservice" .nameOverride }}
app.kubernetes.io/instance: {{ default "mozcloud-deployment" (.Release).Name }}
{{- end }}
{{- end }}

{{/*
Template helpers
*/}}
{{- define "mozcloud-preview-lib.config.name" -}}
{{- $name := "" -}}
{{- if .name -}}
  {{- $name = .name -}}
{{- end -}}
{{- if and (.backendConfig).name (not $name) -}}
  {{- $name = .backendConfig.name -}}
{{- end -}}
{{- if and (.nameOverride) (not $name) -}}
  {{- $name = .nameOverride -}}
{{- end -}}
{{- if not $name -}}
  {{- $name = include "mozcloud-preview-lib.fullname" $ -}}
{{- end -}}
{{- if .prefix -}}
  {{- $name = printf "%s-%s" .prefix $name -}}
{{- end -}}
{{- if .suffixes -}}
  {{- $suffix := join "-" .suffixes -}}
  {{- $length := $suffix | len | add1 -}}
  {{- $name = printf "%s-%s" ($name | trunc (sub 63 $length | int)) $suffix -}}
{{- end -}}
{{ $name | trunc 63 | trimSuffix "-" }}
{{- end -}}

{{- define "mozcloud-preview-lib.config.backend.name" -}}
{{- if (.backendService).name -}}
{{- include "mozcloud-preview-lib.config.name" (dict "name" .backendService.name "prefix" "preview") }}
{{- else -}}
{{- include "mozcloud-preview-lib.config.name" (merge (dict "prefix" "preview") .) }}{{- end -}}
{{- end -}}

{{- define "mozcloud-preview-lib.config.labels" -}}
{{- $component_code := dict "component_code" "preview" -}}
{{- $labels := include "mozcloud-labels-lib.labels" (mergeOverwrite (. | deepCopy) $component_code) | fromYaml -}}
{{- if .labels -}}
  {{- $labels = mergeOverwrite $labels .labels -}}
{{- end }}
{{- $labels | toYaml }}
{{- end -}}

{{/*
EndpointCheck Render
*/}}
{{- define "mozcloud-preview-lib.defaults.endpointcheck" -}}
pr: {{ $.previewPr | quote }}
url: {{ $.previewHost | quote }}
checkPath: {{ .checkPath | default "__heartbeat__" }}
image: {{ .image | default "us-west1-docker.pkg.dev/moz-fx-platform-artifacts/platform-dockerhub-cache/curlimages/curl:8.14.1" | quote }}
maxAttempts: {{ .maxAttempts | default 60 }}
maxTimePerAttempt: {{ .maxTimePerAttempt | default 5 }}
sleepSeconds: {{ .sleepSeconds | default 15 }}
backoffLimit: {{ .backoffLimit | default 1 }}
activeDeadlineSeconds: {{ .activeDeadlineSeconds | default 900 }}
labels:
  {{- include "mozcloud-preview-lib.config.labels" . | nindent 2 }}
{{- end }}

{{/*
Debug helper
*/}}
{{- define "mozcloud-preview-lib.debug" -}}
{{- . | mustToPrettyJson | printf "\nThe JSON output of the dumped var is: \n%s" | fail }}
{{- end -}}
