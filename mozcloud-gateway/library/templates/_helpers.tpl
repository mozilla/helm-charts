{{/*
Expand the name of the chart.
*/}}
{{- define "mozcloud-gateway-lib.name" -}}
{{- if .nameOverride -}}
{{- .nameOverride }}
{{- else -}}
mozcloud-gateway
{{- end -}}
{{- end -}}

{{- /*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "mozcloud-gateway-lib.fullname" -}}
{{- if .fullnameOverride }}
{{- .fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else -}}
{{- include "mozcloud-gateway-lib.name" . }}
{{- end -}}
{{- end -}}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "mozcloud-gateway-lib.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "mozcloud-gateway-lib.labels" -}}
{{- $labels := include "mozcloud-labels-lib.labels" . | fromYaml -}}
{{- if .labels -}}
  {{- $labels = mergeOverwrite $labels .labels -}}
{{- end }}
{{- $labels | toYaml }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "mozcloud-gateway-lib.selectorLabels" -}}
{{- $selector_labels := include "mozcloud-labels-lib.selectorLabels" . | fromYaml -}}
{{- if .selectorLabels -}}
  {{- $selector_labels = mergeOverwrite $selector_labels .selector_labels -}}
{{- end }}
{{- $selector_labels | toYaml }}
{{- end }}

{{/*
Template helpers
*/}}
{{- define "mozcloud-gateway-lib.config.name" -}}
{{- $name := "" -}}
{{- if .name -}}
  {{- $name = .name -}}
{{- end -}}
{{- if and (.httpRouteConfig).name (not $name) -}}
  {{- $name = .httpRouteConfig.name -}}
{{- end -}}
{{- if and (.gatewayConfig).name (not $name) -}}
  {{- $name = .gatewayConfig.name -}}
{{- end -}}
{{- if and (.nameOverride) (not $name) -}}
  {{- $name = .nameOverride -}}
{{- end -}}
{{- if not $name -}}
  {{- $name = include "mozcloud-gateway-lib.fullname" $ -}}
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
Gateway template helpers
*/}}
{{- define "mozcloud-gateway-lib.config.gateway.className" -}}
{{- $type := .type -}}
{{- $scope := default "global" .scope -}}
{{- if eq .type "internal" -}}
  {{- $scope = "regional" -}}
{{- end -}}
{{- index (include "mozcloud-gateway-lib.defaults.gateway.classes" . | fromYaml) $type $scope }}
{{- end -}}

{{- define "mozcloud-gateway-lib.config.gateways" -}}
{{- $defaults := include "mozcloud-gateway-lib.defaults.gateway.config" . | fromYaml -}}
{{- $gateways := default (list $defaults) (.gatewayConfig).gateways -}}
{{- $output := list -}}
{{- range $gateway := $gateways -}}
  {{- $gateway_defaults := include "mozcloud-gateway-lib.defaults.gateway.config" . | fromYaml -}}
  {{- $gateway_config := mergeOverwrite $gateway_defaults ($gateway | deepCopy) -}}
  {{- /* Use name helper function to populate name using rules hierarchy */ -}}
  {{- $params := dict "gatewayConfig" $gateway_config -}}
  {{- $name_override := default "" $.nameOverride -}}
  {{- if $name_override -}}
    {{- $_ := set $params "nameOverride" $name_override -}}
  {{- end -}}
  {{- $name := include "mozcloud-gateway-lib.config.name" $params -}}
  {{- $_ := set $gateway_config "name" $name -}}
  {{- /* Use helper function to determine className if not defined */ -}}
  {{- if not $gateway_config.className -}}
    {{- $class_name := include "mozcloud-gateway-lib.config.gateway.className" $gateway_config -}}
    {{- $_ = set $gateway_config "className" $class_name -}}
  {{- end -}}
  {{- /* Generate labels */ -}}
  {{- $label_params := dict "labels" (default (dict) $gateway_config.labels) -}}
  {{- $labels := (include "mozcloud-gateway-lib.labels" (mergeOverwrite ($ | deepCopy) $label_params) | fromYaml) -}}
  {{- $_ = set $gateway_config "labels" $labels -}}
  {{- $output = append $output $gateway_config -}}
{{- end -}}
{{- $gateways = dict "gateways" $output -}}
{{ $gateways | toYaml }}
{{- end -}}

{{/*
HTTPRoute template helpers
*/}}
{{- define "mozcloud-gateway-lib.config.httpRoutes" -}}
{{- $defaults := include "mozcloud-gateway-lib.defaults.httpRoute.config" . | fromYaml -}}
{{- $http_routes := default (list $defaults) (.httpRouteConfig).httpRoutes }}
{{- $output := list -}}
{{- range $http_route := $http_routes -}}
  {{- $http_route_defaults := include "mozcloud-gateway-lib.defaults.httpRoute.config" . | fromYaml -}}
  {{- $http_route_config := mergeOverwrite $http_route_defaults ($http_route | deepCopy) -}}
  {{- /* Use name helper function to populate name using rules hierarchy */ -}}
  {{- $params := dict "httpRouteConfig" $http_route_config -}}
  {{- $name_override := default "" $.nameOverride -}}
  {{- if $name_override -}}
    {{- $_ := set $params "nameOverride" $name_override -}}
  {{- end -}}
  {{- $name := include "mozcloud-gateway-lib.config.name" $params -}}
  {{- $_ := set $http_route_config "name" $name -}}
  {{- /* Generate labels */ -}}
  {{- $label_params := dict "labels" (default (dict) $http_route_config.labels) -}}
  {{- $labels := (include "mozcloud-gateway-lib.labels" (mergeOverwrite ($ | deepCopy) $label_params) | fromYaml) -}}
  {{- $_ = set $http_route_config "labels" $labels -}}
  {{- /* Set defaults for matches, redirects and rewrites, if defined */ -}}
  {{- $rules := list -}}
  {{- range $rule := $http_route_config.rules -}}
    {{- $rule_defaults := include "mozcloud-gateway-lib.defaults.httpRoute.config" . | fromYaml -}}
    {{- $rule_config := mergeOverwrite ($rule_defaults.rules | first) ($rule | deepCopy) -}}
    {{- if $rule_config.matches -}}
      {{- $matches := list -}}
      {{- range $match := $rule_config.matches -}}
        {{- $match_config := $match | deepCopy -}}
        {{- if $match.path -}}
          {{- $type := default ($rule_defaults.match.path.type | deepCopy) $match_config.path.type -}}
          {{- $_ := set $match_config.path "type" $type -}}
        {{- end -}}
        {{- $matches = append $matches $match_config -}}
      {{- end -}}
      {{- $_ := set $rule_config "matches" $matches -}}
    {{- end -}}
    {{- if $rule_config.redirect -}}
      {{- $redirect_config := mergeOverwrite $rule_defaults.redirect $rule_config.redirect -}}
      {{- $_ := set $rule_config "redirect" $redirect_config -}}
    {{- end -}}
    {{- if $rule_config.rewrite -}}
      {{- $rewrite_config := $rule_config.rewrite | deepCopy -}}
      {{- if $rule_config.rewrite.path -}}
        {{- $rewrite_path_type := default $rule_defaults.rewrite.path.type $rule_config.rewrite.path.type -}}
        {{- $_ := set $rewrite_config.path "type" $rewrite_path_type -}}
      {{- end -}}
      {{- $_ := set $rule_config "rewrite" $rewrite_config -}}
    {{- end -}}
    {{- $rules = append $rules $rule_config -}}
  {{- end -}}
  {{- $_ = set $http_route_config "rules" $rules -}}
  {{- $output = append $output $http_route_config -}}
{{- end -}}
{{- $http_routes = dict "httpRoutes" $output -}}
{{ $http_routes | toYaml }}
{{- end -}}

{{/*
Defaults
*/}}
{{- define "mozcloud-gateway-lib.defaults.gateway.config" -}}
type: external
scope: global
addresses:
  - mozcloud-gateway-dev-ip-v4
listeners:
  - name: http
    protocol: HTTP
    port: 80
  - name: https
    protocol: HTTPS
    port: 443
tls:
  certs:
    - mozcloud-gateway-certmap
  type: certmap
{{- end -}}

{{- define "mozcloud-gateway-lib.defaults.gateway.classes" -}}
external:
  global: gke-l7-global-external-managed
  regional: gke-l7-regional-external-managed
internal:
  regional: gke-l7-rilb
{{- end -}}

{{- define "mozcloud-gateway-lib.defaults.httpRoute.config" -}}
gatewayRefs:
  - name: mozcloud-gateway
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
      - name: {{ include "mozcloud-gateway-lib.config.name" . }}
        port: 8080
{{- end -}}

{{/*
Debug helper
*/}}
{{- define "mozcloud-gateway-lib.debug" -}}
{{- . | mustToPrettyJson | printf "\nThe JSON output of the dumped var is: \n%s" | fail }}
{{- end -}}
