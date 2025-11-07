{{/*
Expand the name of the chart.
*/}}
{{- define "mozcloud-ingress-lib.name" -}}
{{- if .nameOverride -}}
{{- .nameOverride }}
{{- else -}}
mozcloud-ingress
{{- end -}}
{{- end -}}

{{- /*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "mozcloud-ingress-lib.fullname" -}}
{{- if .fullnameOverride -}}
{{- .fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else -}}
{{- include "mozcloud-ingress-lib.name" . }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "mozcloud-ingress-lib.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "mozcloud-ingress-lib.labels" -}}
{{- $component_code := dict "component_code" (default "ingress" .component_code) -}}
{{- $labels := include "mozcloud-labels-lib.labels" (mergeOverwrite (. | deepCopy) $component_code) | fromYaml -}}
{{- if .labels -}}
  {{- $labels = mergeOverwrite $labels .labels -}}
{{- end }}
{{- $labels | toYaml }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "mozcloud-ingress-lib.selectorLabels" -}}
{{- $component_code := dict "component_code" (default "ingress" .component_code) -}}
{{- $selector_labels := include "mozcloud-labels-lib.selectorLabels" (mergeOverwrite (. | deepCopy) $component_code) | fromYaml -}}
{{- if .selectorLabels -}}
  {{- $selector_labels = mergeOverwrite $selector_labels .selector_labels -}}
{{- end }}
{{- $selector_labels | toYaml }}
{{- end }}

{{/*
Template helpers
*/}}
{{- define "mozcloud-ingress-lib.config.name" -}}
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
{{- if and (.chart) (not $name) -}}
  {{- $name = .chart -}}
{{- end -}}
{{- if not $name -}}
  {{- $name = include "mozcloud-ingress-lib.fullname" $ -}}
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

{{/*
BackendConfig template helpers
*/}}
{{- define "mozcloud-ingress-lib.config.backends" -}}
{{- $name_override := default "" .nameOverride -}}
{{- $defaults := include "mozcloud-ingress-lib.defaults.backendConfig" . | fromYaml -}}
{{- $ingresses := include "mozcloud-ingress-lib.config.ingresses" . | fromYaml -}}
{{- $backends := list -}}
{{- $context := omit (. | deepCopy) "ingressConfig" -}}
{{- range $ingress := $ingresses.ingresses -}}
  {{- range $host := $ingress.hosts -}}
    {{- range $path := $host.paths -}}
      {{- $backend := mergeOverwrite $defaults (default (dict) $path.backend.config) -}}
      {{/* If a backend name is not specified, use the service name for the backend */}}
      {{- $params := mergeOverwrite $context (dict "backendConfig" $backend "ingressConfig" $ingress "backendService" $path.backend.service) -}}
      {{- if $name_override -}}
        {{- $_ := set $params "nameOverride" $name_override -}}
      {{- end -}}
      {{- $backend_name := include "mozcloud-ingress-lib.config.backend.name" $params -}}
      {{- $_ := set $backend "name" $backend_name -}}
      {{- $_ = set $backend "ingressConfig" (omit $ingress "hosts") -}}
      {{- $backends = append $backends $backend -}}
    {{- end -}}
  {{- end -}}
{{- end -}}
backends:
  {{ $backends | toYaml | nindent 2 }}
{{- end -}}

{{- define "mozcloud-ingress-lib.config.backend.name" -}}
{{- if (.backendService).name -}}
{{- include "mozcloud-ingress-lib.config.name" (dict "name" .backendService.name) }}
{{- else -}}
{{- include "mozcloud-ingress-lib.config.name" . }}
{{- end -}}
{{- end -}}

{{/*
FrontendConfig template helpers
*/}}
{{- define "mozcloud-ingress-lib.config.frontend" -}}
{{- $defaults := include "mozcloud-ingress-lib.defaults.frontendConfig" . | fromYaml -}}
{{- $name_override := default "" .nameOverride -}}
{{- $ingresses := default (dict) .ingressConfig -}}
{{- range $ingress_name, $ingress_config := $ingresses -}}
  {{- $_ := set $ingress_config "name" $ingress_name -}}
  {{- $params := dict "ingressConfig" $ingress_config "frontendConfig" $.frontendConfig -}}
  {{- if $name_override -}}
    {{- $_ = set $params "nameOverride" $name_override -}}
  {{- end -}}
  {{- $frontend_name := include "mozcloud-ingress-lib.config.name" $params }}
{{ $frontend_name }}:
  redirectToHttps:
    enabled: {{ default $defaults.redirectToHttps.enabled ((.frontendConfig).redirectToHttps).enabled }}
  sslPolicy: {{ default $defaults.sslPolicy (.frontendConfig).sslPolicy }}
{{- end }}
{{- end -}}

{{/*
Ingress template helpers
*/}}
{{- define "mozcloud-ingress-lib.config.ingress.preSharedCerts" -}}
{{- $name_override := default "" .nameOverride -}}
{{- $pre_shared_certs := dict "preSharedCerts" (dict) -}}
{{- $tls_defaults := (include "mozcloud-ingress-lib.defaults.ingress" . | fromYaml).tls -}}
{{- range $ingress := .ingresses -}}
  {{- range $host := $ingress.hosts -}}
    {{- $tls := mergeOverwrite (mergeOverwrite $tls_defaults (default (dict) $ingress.tls)) (default (dict) ($host.tls)) -}}
    {{- if and (eq $tls.type "pre-shared") (gt (len (default "" $tls.preSharedCerts)) 0) -}}
      {{- $params := (dict "ingressConfig" $ingress) -}}
      {{- if $name_override -}}
        {{- $_ := set $params "nameOverride" $name_override -}}
      {{- end -}}
      {{- $ingress_name := include "mozcloud-ingress-lib.config.name" $params -}}
      {{- if and (not (index $pre_shared_certs "preSharedCerts" $ingress_name)) $tls.createCertificates -}}
        {{- $cert_list := $tls.preSharedCerts | toString -}}
        {{- $_ := set $pre_shared_certs.preSharedCerts $ingress_name $cert_list -}}
      {{- end -}}
    {{- end -}}
  {{- end -}}
{{- end -}}
{{ $pre_shared_certs | toYaml }}
{{- end -}}

{{- define "mozcloud-ingress-lib.config.ingresses" -}}
{{- $defaults := include "mozcloud-ingress-lib.defaults.ingress" . | fromYaml -}}
{{- $ingresses := dict "ingresses" .ingressConfig -}}
{{- $name_override := default "" .nameOverride -}}
{{- $output := list -}}
{{- range $name, $ingress := $ingresses.ingresses -}}
  {{- $ingress_config := mergeOverwrite $defaults $ingress -}}
  {{- if $name_override -}}
    {{- $name = $name_override -}}
  {{- end -}}
  {{- $_ := set $ingress_config "name" $name -}}
  {{- $output = append $output $ingress_config -}}
{{- end -}}
{{- $ingresses = dict "ingresses" $output -}}
{{- $params := (dict "ingresses" $ingresses.ingresses) -}}
{{- $pre_shared_certs := include "mozcloud-ingress-lib.config.ingress.preSharedCerts" $params | fromYaml -}}
{{- $_ := set $ingresses "preSharedCerts" $pre_shared_certs.preSharedCerts -}}
{{ $ingresses | toYaml }}
{{- end -}}

{{/*
ManagedCertificate template helpers
*/}}
{{- define "mozcloud-ingress-lib.config.managedCertificates" -}}
{{- $name_override := default "" .nameOverride -}}
{{- $ingresses := include "mozcloud-ingress-lib.config.ingresses" . | fromYaml -}}
{{- $managed_certs := list -}}
{{- $tls_defaults := (include "mozcloud-ingress-lib.defaults.ingress" . | fromYaml).tls -}}
{{- range $iindex, $ingress := $ingresses.ingresses -}}
  {{- range $hindex, $host := $ingress.hosts -}}
    {{- $create_cert := false -}}
    {{- $tls := mergeOverwrite (mergeOverwrite $tls_defaults (default (dict) $ingress.tls)) (default (dict) ($host.tls)) -}}
    {{- if and (eq $tls.type "ManagedCertificate") $tls.createCertificates -}}
      {{- $create_cert = true -}}
    {{- end -}}
    {{- $params := dict "ingressConfig" $ingress -}}
    {{- if $name_override -}}
      {{- $_ := set $params "nameOverride" $name_override -}}
    {{- end -}}
    {{- $ingress_name := include "mozcloud-ingress-lib.config.name" $params -}}
    {{- $managed_cert := dict -}}
    {{- $name := "" -}}
    {{- $prefix := default "mcrt" $tls.prefix -}}
    {{- $suffixes := list -}}
    {{- if $tls.multipleHosts -}}
      {{- if gt (len $ingresses.ingresses) 1 -}}
        {{- $suffixes = append $suffixes ($iindex | toString) -}}
      {{- end -}}
      {{- $suffixes = append $suffixes $hindex -}}
      {{- $params = dict "ingressConfig" $ingress "prefix" $prefix "suffixes" $suffixes -}}
      {{- if $name_override -}}
        {{- $_ := set $params "nameOverride" $name_override -}}
      {{- end -}}
      {{- $name = include "mozcloud-ingress-lib.config.name" $params | replace "." "-" | trunc 63 -}}
      {{- $managed_cert = dict "name" $name "domains" $host.domains "createCertificate" $create_cert -}}
    {{- else -}}
      {{- range $domain := $host.domains -}}
        {{- if $prefix -}}
          {{- $name = printf "%s-%s" $prefix $domain | replace "." "-" | trunc 63 -}}
        {{- else -}}
          {{- $name = $domain | replace "." "-" | trunc 63 -}}
        {{- end -}}
        {{- $managed_cert = dict "name" $name "domains" (list $domain) "createCertificate" $create_cert -}}
      {{- end -}}
    {{- end -}}
    {{- $_ := set $managed_cert "ingressName" $ingress_name -}}
    {{- $managed_certs = append $managed_certs $managed_cert -}}
  {{- end -}}
{{- end -}}
{{ $managed_certs | toYaml }}
{{- end -}}

{{/*
Service template helpers
*/}}
{{- define "mozcloud-ingress-lib.config.services" -}}
{{- $name_override := default "" .nameOverride -}}
{{- $backend_defaults := include "mozcloud-ingress-lib.defaults.backendConfig" . | fromYaml -}}
{{- $ingresses := include "mozcloud-ingress-lib.config.ingresses" . | fromYaml -}}
{{- $services := list -}}
{{- $context := omit (. | deepCopy) "ingressConfig" -}}
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
      {{- $service_name := include "mozcloud-ingress-lib.config.backend.name" $params -}}
      {{- /* Check if service was already included. If so, skip to avoid duplicates. */}}
      {{- /* Configure args for library chart */}}
      {{- /* Service annotations */}}
      {{- /* This allows users to explicitly specify "false" without overriding with "true" from defaults */}}
      {{- $create_neg := (include "mozcloud-ingress-lib.defaults.service.config" . | fromYaml).createNeg -}}
      {{- if hasKey $backend_service "createNeg" -}}
        {{- $create_neg = $backend_service.createNeg -}}
      {{- end -}}
      {{- $annotation_params := dict "backendName" $service_name "createNeg" $create_neg -}}
      {{- if $ingress.annotations -}}
        {{- $_ := set $annotation_params "annotations" $ingress.annotations -}}
      {{- end -}}
      {{- $annotations := include "mozcloud-ingress-lib.config.service.annotations" $annotation_params | fromYaml -}}
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
        {{- $_ = set $port_config "targetPort" $backend_service.targetPort -}}
      {{- end -}}
      {{- $config := include "mozcloud-ingress-lib.config.service.config" $port_config | fromYaml -}}
      {{- $_ = set $service "config" $config -}}
      {{- /* Service fullnameOverride */}}
      {{- $_ = set $service "fullnameOverride" $service_name -}}
      {{- /* Service labels */}}
      {{- $label_params := mergeOverwrite ($context | deepCopy) (dict "labels" (default (dict) $backend_service.labels)) -}}
      {{- $labels := include "mozcloud-ingress-lib.labels" $label_params | fromYaml -}}
      {{- $_ = set $service "labels" $labels -}}
      {{- /* Service selectorLabels */}}
      {{- $selector_label_params := mergeOverwrite ($context | deepCopy) (dict "selectorLabels" (default (dict) $backend_service.selectorLabels)) -}}
      {{- $selector_labels := include "mozcloud-ingress-lib.selectorLabels" $selector_label_params | fromYaml -}}
      {{- $_ = set $service "selectorLabels" $selector_labels -}}
      {{- /* Append to services list */}}
      {{- $services = append $services $service -}}
    {{- end -}}
  {{- end -}}
{{- end -}}
{{ $services | toYaml }}
{{- end -}}

{{- define "mozcloud-ingress-lib.config.service.annotations" -}}
{{- if .annotations -}}
{{ .annotations | toYaml }}
{{- end }}
{{- if .createNeg -}}
cloud.google.com/neg: '{"ingress": true}'
{{- end }}
cloud.google.com/backend-config: '{"default": "{{ .backendName }}"}'
{{- end -}}

{{- define "mozcloud-ingress-lib.config.service.config" -}}
{{- $defaults := (include "mozcloud-ingress-lib.defaults.service.config" . | fromYaml) -}}
ports:
  - port: {{ default $defaults.port .port }}
    targetPort: {{ default $defaults.targetPort .targetPort }}
    protocol: {{ default $defaults.protocol .protocol }}
    name: {{ $defaults.name }}
type: {{ $defaults.type }}
{{- end -}}

{{/*
Defaults
*/}}
{{- define "mozcloud-ingress-lib.defaults.backendConfig" -}}
{{- if .defaults -}}
{{ .defaults | toYaml }}
{{- else -}}
logging:
  enable: true
  sampleRate: 0.1
{{- end -}}
{{- end -}}

{{- define "mozcloud-ingress-lib.defaults.frontendConfig" -}}
redirectToHttps:
  enabled: true
  responseCodeName: MOVED_PERMANENTLY_DEFAULT
sslPolicy: mozilla-intermediate
{{- end -}}

{{- define "mozcloud-ingress-lib.defaults.ingress" -}}
hosts:
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

{{- define "mozcloud-ingress-lib.defaults.service.config" -}}
# Default configurables for service
# See https://kubernetes.io/docs/concepts/services-networking/service/ for
# information on how to configure a service
createNeg: true
port: 8080
targetPort: http
protocol: TCP
name: http
type: ClusterIP
{{- end }}

{{/*
Debug helper
*/}}
{{- define "mozcloud-ingress-lib.debug" -}}
{{- . | mustToPrettyJson | printf "\nThe JSON output of the dumped var is: \n%s" | fail }}
{{- end -}}
