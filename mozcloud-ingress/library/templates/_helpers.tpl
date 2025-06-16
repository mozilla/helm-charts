{{/*
Expand the name of the chart.
*/}}
{{- define "mozcloud-ingress.name" -}}
{{- default .Chart.Name (index . "name") | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "mozcloud-ingress.fullname" -}}
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
{{- define "mozcloud-ingress.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "mozcloud-ingress.labels" -}}
{{- if (index . "labels") -}}
{{- index . "labels" | toYaml }}
{{- else -}}
helm.sh/chart: {{ include "mozcloud-ingress.chart" . }}
{{ include "mozcloud-ingress.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/component: ingress
{{- end }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "mozcloud-ingress.selectorLabels" -}}
{{- if (index . "selectorLabels") -}}
{{- index . "selectorLabels" | toYaml }}
{{- else -}}
app.kubernetes.io/name: {{ include "mozcloud-ingress.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
{{- end }}

{{/*
Ingress defaults
*/}}
{{- define "mozcloud-ingress.defaults.backendConfig" -}}
{{- if $.Values.app_code -}}
securityPolicy: {{ $.Values.app_code }}-policy
{{- end }}
logging:
  enable: true
  sampleRate: 1.0
{{- end -}}

{{- define "mozcloud-ingress.defaults.frontendConfig" -}}
redirectToHttps:
  enabled: true
  responseCodeName: MOVED_PERMANENTLY_DEFAULT
sslPolicy: mozilla-intermediate
{{- end -}}

{{- define "mozcloud-ingress.defaults.ingresses" -}}
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

{{- define "mozcloud-ingress.defaults.service.config" -}}
# Default configurables for service
config:
  # See https://kubernetes.io/docs/concepts/services-networking/service/ for
  # information on how to configure a service
  ports:
    - port: 8080
      targetPort: http
      protocol: TCP
      name: http
  type: ClusterIP
{{- end }}

{{/*
Ingress template helpers
*/}}
{{- define "mozcloud-ingress.config.frontend" -}}
{{- $defaults := include "mozcloud-ingress.defaults.frontendConfig" . | fromYaml -}}
name: {{ default (include "mozcloud-ingress.fullname" $) (index . "frontendConfig" "name") }}
{{- if (index . "frontendConfig" "labels") -}}
labels: {{ index . "frontendConfig" "labels" | toYaml }}
{{- end }}
redirectToHttps:
  enabled: {{ default $defaults.redirectToHttps.enabled (index . "frontendConfig" "redirectToHttps" "enabled") }}
sslPolicy: {{ default $defaults.sslPolicy (index . "frontendConfig" "sslPolicy") }}
{{- end -}}

{{- define "mozcloud-ingress.config.name" -}}
{{- if (index . "ingressConfig" "name") -}}
  {{- $name := (index . "ingressConfig" "name") -}}
{{- else -}}
  {{- $name := include "mozcloud-ingress.fullname" $ -}}
{{- end -}}
{{- if (index . "index") -}}
  {{- $name = printf "%s-%d" $name (index . "index") -}}
{{- end -}}
{{ $name }}
{{- end -}}

{{- define "mozcloud-ingress.config.ingresses" -}}
{{ merge (default list (index . "ingresses")) (include "mozcloud-ingress.defaults.ingresses" . | fromYaml) | toYaml }}
{{- end -}}

{{- define "mozcloud-ingress.config.managedCertificates" -}}
{{- $managed_certs := list -}}
{{- range $index, $ingress := (include "mozcloud-ingress.config.ingresses" . ) -}}
  {{- range $host := $ingress.hosts -}}
    {{- if and (eq $ingress.tls.type "ManagedCertificate") (or ($host.createCertificate) (and ($ingress.tls.createCertificate) (not index $host "createCertificate"))) -}}
      {{- $create_cert := true -}}
    {{- else -}}
      {{- $create_cert := false -}}
    {{- end -}}
    {{- $managed_cert := dict -}}
    {{- if (default true $host.tls.multipleHosts) -}}
      {{- $name := printf "mcrt-%s-%d" (include "mozcloud-ingress.config.name" (dict "ingressConfig" $ingress "index" $index)) $index | replace "." "-" | trunc 63 -}}
      {{- $_ := set $managed_cert "name" $name "domains" $host.domains "createCertificate" $create_cert -}}
      {{- $managed_certs = append $managed_certs $managed_cert -}}
    {{- else -}}
      {{- range $domain := $domains -}}
        {{- $name := $domain | replace "." "-" | trunc 63 -}}
        {{- $_ := set $managed_cert "name" $name "domains" (list $domain) "createCertificate" $create_cert -}}
        {{- $managed_certs = append $managed_certs $managed_cert -}}
      {{- end -}}
    {{- end -}}
  {{- end -}}
{{- end -}}
{{ $managed_certs | toYaml }}
{{- end -}}

{{- define "mozcloud-ingress.config.services" -}}
{{- $ingresses := include "mozcloud-ingress.config.ingresses" . -}}
{{- $services := list -}}
{{- $service_names := list -}}
{{- range $ingress := $ingresses -}}
  {{- range $path := $ingress.paths -}}
    {{- $service := dict -}}
    {{- $backend_service := $path.backend.service -}}
    {{- $backend_name := default (include "application.fullname" $) ($backend_service.name) -}}
    {{/* Check if service was already included. If so, skip to avoid duplicates. */}}
    {{- if not (has $backend_name $service_names) -}}
      {{/* Configure args for library chart */}}
      {{/* Service annotations */}}
      {{- $annotations := include "mozcloud-ingress.config.service.annotations" (dict "backendName" $backend_name) -}}
      {{- $_ := set $service "annotations" $annotations -}}
      {{/* Service config */}}
      {{- $config_helper := dict "port" $backend_service.port -}}
      {{- if $backend_service.protocol -}}
        {{- $_ = set $service_config "protocol" $backend_service.protocol -}}
      {{- end -}}
      {{- if $backend_service.targetPort -}}
        {{- $_ = set $service_config "targetPort" $backend_service.targetPort -}}
      {{- end -}}
      {{- $config := include "mozcloud-ingress.config.service.config" $config_helper -}}
      {{- $_ = set $service "config" $config -}}
      {{/* Service fullnameOverride */}}
      {{- $_ = set $service "fullnameOverride" $backend_name -}}
      {{/* Service labels */}}
      {{- $labels := default (include "application.labels" $ | fromYaml) $backend_service.labels -}}
      {{- $_ = set $service "labels" $labels -}}
      {{/* Service selectorLabels */}}
      {{- $selector_labels := default (include "application.selectorLabels" $ | fromYaml) $backend_service.selectorLabels -}}
      {{- $_ = set $service "selectorLabels" $selector_labels -}}
      {{/* Append to services list */}}
      {{- $services = append $services $service -}}
      {{- $service_names = append $service_names $backend_name -}}
    {{- end -}}
  {{- end -}}
{{- end -}}
{{ $services | toYaml }}
{{- end -}}

{{/*
Service template helpers
*/}}
{{- define "mozcloud-ingress.config.service.annotations" -}}
{{- if (index . "annotations") -}}
{{ index . "annotations" | toYaml }}
{{- end }}
cloud.google.com/neg: '{"ingress": true}'
cloud.google.com/backend-config: '{"default": "{{ index . "backendName" }}"}'
{{- end }}

{{- define "mozcloud-ingress.config.service.config" -}}
ports:
  - port: {{ index . "port" }}
    targetPort: {{ default "http" (index . "targetPort") }}
    protocol: {{ default "TCP" (index . "protocol") }}
    name: http
type: ClusterIP
{{- end -}}
