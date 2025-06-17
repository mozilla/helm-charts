{{/*
Expand the name of the chart.
*/}}
{{- define "mozcloud-ingress-lib.name" -}}
mozcloud-ingress-lib
{{- end -}}
{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "mozcloud-ingress-lib.fullname" -}}
{{- if (index . "fullnameOverride") }}
{{- index . "fullnameOverride" | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- include "mozcloud-ingress-lib.name" . -}}
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
{{- if (index . "labels") -}}
{{- index . "labels" | toYaml }}
{{- else -}}
helm.sh/chart: {{ default "mozcloud-ingress" (.Chart).Name }}
{{ include "mozcloud-ingress-lib.selectorLabels" . }}
{{- if (.Chart).AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/component: ingress
{{- end }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "mozcloud-ingress-lib.selectorLabels" -}}
{{- if (index . "selectorLabels") -}}
{{- index . "selectorLabels" | toYaml }}
{{- else -}}
app.kubernetes.io/name: mozcloud-webservice
app.kubernetes.io/instance: {{ default "mozcloud-deployment" (.Release).Name }}
{{- end }}
{{- end }}

{{/*
Ingress defaults
*/}}
{{- define "mozcloud-ingress-lib.defaults.backendConfig" -}}
{{- if $.Values.app_code -}}
securityPolicy: {{ $.Values.app_code }}-policy
{{- end }}
logging:
  enable: true
  sampleRate: 1.0
{{- end -}}

{{- define "mozcloud-ingress-lib.defaults.frontendConfig" -}}
redirectToHttps:
  enabled: true
  responseCodeName: MOVED_PERMANENTLY_DEFAULT
sslPolicy: mozilla-intermediate
{{- end -}}

{{- define "mozcloud-ingress-lib.defaults.ingresses" -}}
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

{{- define "mozcloud-ingress-lib.defaults.service.config" -}}
# Default configurables for service
# See https://kubernetes.io/docs/concepts/services-networking/service/ for
# information on how to configure a service
port: 8080
targetPort: http
protocol: TCP
name: http
type: ClusterIP
{{- end }}

{{/*
Ingress template helpers
*/}}
{{- define "mozcloud-ingress-lib.config.frontend" -}}
{{- $defaults := include "mozcloud-ingress-lib.defaults.frontendConfig" . | fromYaml -}}
name: {{ default (include "mozcloud-ingress-lib.fullname" $) (index . "frontendConfig" "name") }}
{{- if (index . "frontendConfig" "labels") -}}
labels: {{ index . "frontendConfig" "labels" | toYaml }}
{{- end }}
redirectToHttps:
  enabled: {{ default $defaults.redirectToHttps.enabled (index . "frontendConfig" "redirectToHttps" "enabled") }}
sslPolicy: {{ default $defaults.sslPolicy (index . "frontendConfig" "sslPolicy") }}
{{- end -}}

{{- define "mozcloud-ingress-lib.config.name" -}}
{{- $name := "" -}}
{{- $context := (index .) -}}
{{- if $context.name -}}
  {{- $name = $context.name -}}
{{- else if ($context.backendConfig).name -}}
  {{- $name = $context.backendConfig.name -}}
{{- else if ($context.ingressConfig).name -}}
  {{- $name = $context.ingressConfig.name -}}
{{- else -}}
  {{- $name = include "mozcloud-ingress-lib.fullname" $ -}}
{{- end -}}
{{- if  $context.index -}}
  {{- $length = $context.index | len | add1 -}}
  {{- $name = printf "%s-%d" ($name | sub 63 $length) $context.index -}}
{{- end -}}
{{ $name | trunc 63 | trimSuffix "-" }}
{{- end -}}

{{- define "mozcloud-ingress-lib.config.ingresses" -}}
{{- $defaults := include "mozcloud-ingress-lib.defaults.ingresses" . | fromYaml -}}
{{- $ingresses := $defaults -}}
{{/*
{{- if (index . "ingresses") -}}
  {{- $ingresses = merge (dict "ingresses" (index . "ingresses")) $defaults -}}
{{- end -}}
*/}}
{{ $ingresses | toYaml }}
{{- end -}}

{{- define "mozcloud-ingress-lib.config.managedCertificates" -}}
{{- $managed_certs := list -}}
{{- range $index, $ingress := (include "mozcloud-ingress-lib.config.ingresses" . ) -}}
  {{- range $host := $ingress.hosts -}}
    {{- $create_cert := false -}}
    {{- if and (eq $ingress.tls.type "ManagedCertificate") (or ($host.createCertificate) (and ($ingress.tls.createCertificate) (not index $host "createCertificate"))) -}}
      {{- $create_cert = true -}}
    {{- end -}}
    {{- $managed_cert := dict -}}
    {{- $name := "" -}}
    {{- if (default true $host.tls.multipleHosts) -}}
      {{- $name = printf "mcrt-%s-%d" (include "mozcloud-ingress-lib.config.name" (dict "ingressConfig" $ingress "index" $index)) $index | replace "." "-" | trunc 63 -}}
      {{- $_ := set $managed_cert "name" $name "domains" $host.domains "createCertificate" $create_cert -}}
      {{- $managed_certs = append $managed_certs $managed_cert -}}
    {{- else -}}
      {{- range $domain := $host.domains -}}
        {{- $name = $domain | replace "." "-" | trunc 63 -}}
        {{- $_ := set $managed_cert "name" $name "domains" (list $domain) "createCertificate" $create_cert -}}
        {{- $managed_certs = append $managed_certs $managed_cert -}}
      {{- end -}}
    {{- end -}}
  {{- end -}}
{{- end -}}
{{ $managed_certs | toYaml }}
{{- end -}}

{{- define "mozcloud-ingress-lib.config.services" -}}
{{- $ingresses := include "mozcloud-ingress-lib.config.ingresses" . | fromYaml -}}
{{- $services := list -}}
{{- $service_names := list -}}
{{- range $ingress := $ingresses.ingresses -}}
  {{- range $host := $ingress.hosts -}}
    {{- range $path := $host.paths -}}
      {{- $service := dict -}}
      {{- $backend_service := $path.backend.service -}}
      {{- $backend_name := default (include "mozcloud-ingress-lib.fullname" (dict "ingressConfig" $ingress "backendConfig" $backend_service)) ($backend_service.name) -}}
      {{/* Check if service was already included. If so, skip to avoid duplicates. */}}
      {{- if not (has $backend_name $service_names) -}}
        {{/* Configure args for library chart */}}
        {{/* Service annotations */}}
        {{- $annotations := include "mozcloud-ingress-lib.config.service.annotations" (dict "backendName" $backend_name) -}}
        {{- $_ := set $service "annotations" $annotations -}}
        {{/* Service config */}}
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
        {{- $config := (include "mozcloud-ingress-lib.config.service.config" $port_config | fromYaml) -}}
        {{- $_ = set $service "config" $config -}}
        {{/* Service fullnameOverride */}}
        {{- $fullname_override := $backend_name -}}
        {{/* Service labels */}}
        {{- $labels := default (include "mozcloud-ingress-lib.labels" $ | fromYaml) $backend_service.labels -}}
        {{- $_ = set $service "labels" $labels -}}
        {{/* Service selectorLabels */}}
        {{- $selector_labels := default (include "mozcloud-ingress-lib.selectorLabels" $ | fromYaml) $backend_service.selectorLabels -}}
        {{- $_ = set $service "selectorLabels" $selector_labels -}}
        {{/* Append to services list */}}
        {{- $services = append $services $service -}}
        {{- $service_names = append $service_names $backend_name -}}
      {{- end -}}
    {{- end -}}
  {{- end -}}
{{- end -}}
{{ $services | toYaml }}
{{- end -}}

{{/*
Service template helpers
*/}}
{{- define "mozcloud-ingress-lib.config.service.annotations" -}}
{{- if (index . "annotations") -}}
{{ index . "annotations" | toYaml }}
{{- end }}
cloud.google.com/neg: '{"ingress": true}'
cloud.google.com/backend-config: '{"default": "{{ index . "backendName" }}"}'
{{- end }}

{{- define "mozcloud-ingress-lib.config.service.config" -}}
{{- $defaults := (include "mozcloud-ingress-lib.defaults.service.config" . | fromYaml) -}}
ports:
  - port: {{ default $defaults.port (index . "port") }}
    targetPort: {{ default $defaults.targetPort (index . "targetPort") }}
    protocol: {{ default $defaults.protocol (index . "protocol") }}
    name: {{ $defaults.name }}
type: {{ $defaults.type }}
{{- end -}}
