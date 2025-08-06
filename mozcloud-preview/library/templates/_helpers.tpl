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

{{/*
Service template helpers
*/}}
{{- define "mozcloud-preview-lib.config.service" -}}
{{- $name_override := default "" .nameOverride -}}
{{- $backends := default (list) (.backendConfig).backends -}}
{{- $output := list -}}
{{- range $backend := $backends -}}
  {{- $defaults := include "mozcloud-preview-lib.defaults.service.config" . | fromYaml -}}
  {{- $service_config := dict -}}
  {{- $backend_service := $backend.service | deepCopy -}}
  {{- /* Only create the service if "create" is not "false" */ -}}
  {{- $create_service := (include "mozcloud-gateway-lib.defaults.service.config" . | fromYaml).create -}}
  {{- if hasKey $backend_service "create" -}}
    {{- $create_service = $backend_service.create -}}
  {{- end -}}
  {{- $_ := set $service_config "create" $create_service -}}
  {{- /* Use name helper function to populate name using rules hierarchy */ -}}
  {{- $params := dict -}}
  {{- if $backend.name -}}
    {{- $_ := set $params "name" $backend.name -}}
  {{- end -}}
  {{- if $name_override -}}
    {{- $_ := set $params "nameOverride" $name_override -}}
  {{- end -}}
  {{- $name := include "mozcloud-preview-lib.config.name" $params -}}
  {{- $_ = set $service_config "fullnameOverride" $name -}}
  {{- /* Include annotations, if specified */ -}}
  {{- if $backend_service.annotations -}}
    {{- $_ := set $service_config "annotations" $backend_service.annotations -}}
  {{- end -}}
  {{- /* Generate labels */ -}}
  {{- $backend_labels := dict "labels" (default (dict) $backend.labels) -}}
  {{- $backend_service_labels := dict "labels" (default (dict) $backend_service.labels) -}}
  {{- $label_params := dict "labels" (mergeOverwrite $backend_labels.labels $backend_service_labels.labels) -}}
  {{- $labels := include "mozcloud-preview-lib.labels" (mergeOverwrite ($ | deepCopy) $label_params) | fromYaml -}}
  {{- $_ = set $service_config "labels" $labels -}}
  {{- /* Generate selectorLabels */ -}}
  {{- $selector_label_params := dict "selectorLabels" (default (dict) $backend_service.selectorLabels) -}}
  {{- $selector_labels := include "mozcloud-preview-lib.selectorLabels" (mergeOverwrite ($ | deepCopy) $selector_label_params) | fromYaml -}}
  {{- $_ = set $service_config "selectorLabels" $selector_labels -}}
  {{- /* Service config */ -}}
  {{- $config := include "mozcloud-preview-lib.config.service.config" $backend_service | fromYaml -}}
  {{- $_ = set $service_config "config" $config -}}
  {{- $output = append $output $service_config -}}
{{- end -}}
{{- $services := dict "services" $output -}}
{{ $services | toYaml }}
{{- end -}}

{{- define "mozcloud-preview-lib.config.service.annotations" -}}
{{- if .annotations -}}
{{ .annotations | toYaml }}
{{- end }}
{{- end -}}

{{- define "mozcloud-preview-lib.config.service.config" -}}
{{- $defaults := (include "mozcloud-preview-lib.defaults.service.config" . | fromYaml) -}}
ports:
  - port: {{ default $defaults.port .port }}
    targetPort: {{ default $defaults.targetPort .targetPort }}
    protocol: {{ default $defaults.protocol .protocol }}
    name: {{ $defaults.name }}
type: {{ $defaults.type }}
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
labels:
  app.kubernetes.io/component: endpoint-check
  {{- .labels | toYaml | nindent 4 }}
{{- end }}

{{/*
Defaults
*/}}
{{- define "mozcloud-preview-lib.defaults.backendConfig" -}}
{{- if .defaults -}}
{{ .defaults | toYaml }}
{{- else -}}
logging:
  enable: true
  sampleRate: 1.0
{{- end -}}
{{- end -}}

{{- define "mozcloud-preview-lib.defaults.httpRoute.config" -}}
gatewayRefs:
  - name: {{ "sandbox-high-preview-gateway" }}
    namespace: {{ "preview-shared-infrastructure" }}
    section: https
hostnames:
  - chart.example.local
httpToHttpsRedirect: true
match:
  path:
    type: PathPrefix
redirect:
  statusCode: 302
  type: ReplaceFullPath
rewrite:
  path:
    type: ReplaceFullPath
rules:
  - backendRefs:
      - name: {{ include "mozcloud-preview-lib.config.name" . }}
        port: 8080
{{- end -}}


{{- define "mozcloud-preview-lib.defaults.service.config" -}}
# Default configurables for service
# See https://kubernetes.io/docs/concepts/services-networking/service/ for
# information on how to configure a service
createNeg: false
port: 8080
targetPort: http
protocol: TCP
name: http
dev-pr17-cicd-demos.preview.mozilla.cloudtype: ClusterIP
{{- end }}

{{/*
Debug helper
*/}}
{{- define "mozcloud-preview-lib.debug" -}}
{{- . | mustToPrettyJson | printf "\nThe JSON output of the dumped var is: \n%s" | fail }}
{{- end -}}
