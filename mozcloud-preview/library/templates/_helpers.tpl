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
{{- if and (.frontendConfig).name (not $name) -}}
  {{- $name = .frontendConfig.name -}}
{{- end -}}
{{- if and (.ingressConfig).name (not $name) -}}
  {{- $name = .ingressConfig.name -}}
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
Ingress template helpers
*/}}
{{- define "mozcloud-preview-lib.config.ingress.preSharedCerts" -}}
{{- $name_override := default "" .nameOverride -}}
{{- $pre_shared_certs := dict "preSharedCerts" (dict) -}}
{{- $tls_defaults := (index (include "mozcloud-preview-lib.defaults.ingresses" . | fromYaml) "ingresses" 0).tls -}}
{{- range $ingress := .ingresses -}}
  {{- range $host := $ingress.hosts -}}
    {{- $tls := mergeOverwrite (mergeOverwrite $tls_defaults (default (dict) $ingress.tls)) (default (dict) ($host.tls)) -}}
    {{- if and (eq $tls.type "pre-shared") (gt (len (default "" $tls.preSharedCerts)) 0) -}}
      {{- $params := (dict "ingressConfig" $ingress) -}}
      {{- if $name_override -}}
        {{- $_ := set $params "nameOverride" $name_override -}}
      {{- end -}}
      {{- $ingress_name := include "mozcloud-preview-lib.config.name" $params -}}
      {{- if and (not (index $pre_shared_certs "preSharedCerts" $ingress_name)) $tls.createCertificates -}}
        {{- $cert_list := $tls.preSharedCerts | toString -}}
        {{- $_ := set $pre_shared_certs.preSharedCerts $ingress_name $cert_list -}}
      {{- end -}}
    {{- end -}}
  {{- end -}}
{{- end -}}
{{ $pre_shared_certs | toYaml }}
{{- end -}}


{{- define "mozcloud-preview-lib.config.ingresses" -}}
{{- $defaults := include "mozcloud-preview-lib.defaults.ingresses" . | fromYaml -}}
{{- $ingresses := $defaults -}}
{{- if .ingressConfig -}}
  {{- $ingresses = mergeOverwrite $defaults (dict "ingresses" .ingressConfig) -}}
{{- end -}}
{{- $params := (dict "ingresses" $ingresses.ingresses) }}
{{- $name_override := default "" .nameOverride }}
{{- if $name_override }}
  {{- $_ := set $params "nameOverride" $name_override }}
{{- end -}}
{{- $pre_shared_certs := include "mozcloud-preview-lib.config.ingress.preSharedCerts" $params | fromYaml -}}
{{- $_ := set $ingresses "preSharedCerts" $pre_shared_certs.preSharedCerts -}}
{{ $ingresses | toYaml }}
{{- end -}}

{{/*
Service template helpers
*/}}
{{- define "mozcloud-preview-lib.config.services" -}}
{{- $name_override := default "" .nameOverride -}}
{{- $backend_defaults := include "mozcloud-preview-lib.defaults.backendConfig" . | fromYaml -}}
{{- $ingresses := include "mozcloud-preview-lib.config.ingresses" . | fromYaml -}}
{{- $services := list -}}
{{- range $ingress := $ingresses.ingresses -}}
  {{- range $host := $ingress.hosts -}}
    {{- range $path := $host.paths -}}
      {{- $service := dict -}}
      {{- $backend := mergeOverwrite $backend_defaults (default (dict) $path.backend.config) -}}
      {{- $backend_service := $path.backend.service -}}
      {{- $params := dict "backendConfig" $backend "backendService" $backend_service "ingressConfig" $ingress -}}
      {{- if $name_override -}}
        {{- $_ := set $params "nameOverride" $name_override -}}
      {{- end -}}
      {{- $service_name := include "mozcloud-preview-lib.config.backend.name" $params -}}
      {{- /* Check if service was already included. If so, skip to avoid duplicates. */}}
      {{- /* Configure args for library chart */}}
      {{- /* Service annotations */}}
      {{- /* This allows users to explicitly specify "false" without overriding with "true" from defaults */}}
      {{- $create_neg := false -}}
      {{- $annotation_params := dict "backendName" $service_name "createNeg" $create_neg -}}
      {{- if $ingress.annotations -}}
        {{- $_ := set $annotation_params "annotations" $ingress.annotations -}}
      {{- end -}}
      {{- $annotations := include "mozcloud-preview-lib.config.service.annotations" $annotation_params | fromYaml -}}
      {{- $_ := set $service "annotations" $annotations -}}
      {{- /* Service config */}}
      {{- $port_config := dict -}}
      {{- if $backend_service.port -}}
        {{- $_ = set $port_config "port" $backend_service.port -}}
      {{- end -}}
      {{- if $backend_service.protocol -}}
        {{- $_ = set $port_config "protocol" $backend_service.protocol -}}
      {{- end -}}
      {{- if $backend_service.targetPort -}}
        {{- $_ = set $port_config "target_port" $backend_service.targetPort -}}
      {{- end -}}
      {{- $config := include "mozcloud-preview-lib.config.service.config" $port_config | fromYaml -}}
      {{- $_ = set $service "config" $config -}}
      {{- /* Service fullnameOverride */}}
      {{- $_ = set $service "fullnameOverride" $service_name -}}
      {{- /* Service labels */}}
      {{- $labels := default (include "mozcloud-preview-lib.labels" $ | fromYaml) $backend_service.labels -}}
      {{- $_ = set $service "labels" $labels -}}
      {{- /* Service selectorLabels */}}
      {{- $selector_labels := default (include "mozcloud-preview-lib.selectorLabels" $ | fromYaml) $backend_service.selectorLabels -}}
      {{- $_ = set $service "selectorLabels" $selector_labels -}}
      {{- /* Append to services list */}}
      {{- $services = append $services $service -}}
    {{- end -}}
  {{- end -}}
{{- end -}}
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
HTTPRoute Render
*/}}
{{- define "mozcloud-preview-lib.config.httproutes" -}}
{{- $name_override := default "" .nameOverride -}}
{{- $ingresses := include "mozcloud-preview-lib.config.ingresses" . | fromYaml -}}
{{- $routes := list -}}

{{- range $ingress := $ingresses.ingresses -}}
  {{- range $host := $ingress.hosts -}}
    {{- range $path := $host.paths -}}
      {{- $svc := $path.backend.service -}}
      {{- $route := dict -}}

      {{- /* Name construction */ -}}
      {{- $service_suffix := $svc.name | replace "." "-" | replace "_" "-" }}
      {{- $name_params := dict
          "ingressConfig" $ingress
          "nameOverride" $name_override
          "prefix" $.previewPr
          "suffixes" (list "httproute" $service_suffix)
      }}
      {{- $route_name := include "mozcloud-preview-lib.config.name" $name_params }}

      {{- /* Assign fields */ -}}
      {{- $_ := set $route "fullnameOverride" $route_name }}
      {{- $_ := set $route "labels" (include "mozcloud-preview-lib.labels" . | fromYaml) }}
      {{- $_ := set $route "hostnames" $host.domains }}
      {{- $_ := set $route "gateway" (default dict $.gateway) }}
      {{- $_ := set $route "backend" (dict "name" $svc.name "port" $svc.port) }}

      {{- $routes = append $routes $route }}
    {{- end }}
  {{- end }}
{{- end }}

{{ $routes | toYaml }}
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

{{- define "mozcloud-preview-lib.defaults.frontendConfig" -}}
redirectToHttps:
  enabled: true
  responseCodeName: MOVED_PERMANENTLY_DEFAULT
sslPolicy: mozilla-intermediate
{{- end -}}

{{- define "mozcloud-preview-lib.defaults.ingresses" -}}
ingresses:
  - hosts:
      - domains: ["chart.example.local"]
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                port: 8080
    tls:
      createCertificates: true
      type: ManagedCertificate
      multipleHosts: true
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
type: ClusterIP
{{- end }}

{{/*
Debug helper
*/}}
{{- define "mozcloud-preview-lib.debug" -}}
{{- . | mustToPrettyJson | printf "\nThe JSON output of the dumped var is: \n%s" | fail }}
{{- end -}}
