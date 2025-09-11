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
  {{- $selector_labels = mergeOverwrite $selector_labels .selectorLabels -}}
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
{{- if and (.chart) (not $name) -}}
  {{- $name = .chart -}}
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
BackendPolicy template helpers
*/}}
{{- define "mozcloud-gateway-lib.config.backendPolicies" -}}
{{- $defaults := include "mozcloud-gateway-lib.defaults.backendPolicy.config" . | fromYaml -}}
{{- $backend_policy := default (dict) .backendPolicyConfig -}}
{{- $backends := default (list) (.backendConfig).backends -}}
{{- $name_override := default "" .nameOverride -}}
{{- $output := list -}}
{{- range $backend := $backends -}}
  {{- $backend_policy_config := dict -}}
  {{- /* Merge service backend policy, default backend policy, and library defaults */ -}}
  {{- $default_policy := mergeOverwrite ($defaults | deepCopy) $backend_policy -}}
  {{- $service_policy := default (dict) $backend.backendPolicy -}}
  {{- $merged_policy := mergeOverwrite $default_policy $service_policy -}}
  {{- if and (($merged_policy).sessionAffinity).type (ne (($merged_policy).sessionAffinity).type "GENERATED_COOKIE") -}}
    {{- $_ := unset $merged_policy.sessionAffinity "cookieTtlSec" -}}
  {{- end -}}
  {{- $_ := set $backend_policy_config "config" $merged_policy -}}
  {{- /* Use name helper function to populate name and targetService using rules hierarchy */ -}}
  {{- $params := $ | deepCopy -}}
  {{- if $backend.name -}}
    {{- $_ := set $params "name" $backend.name -}}
  {{- end -}}
  {{- if $name_override -}}
    {{- $_ := set $params "nameOverride" $name_override -}}
  {{- end -}}
  {{- $name := include "mozcloud-gateway-lib.config.name" $params -}}
  {{- $_ = set $backend_policy_config "name" $name -}}
  {{- $_ = set $backend_policy_config "targetService" $name -}}
  {{- /* Generate labels */ -}}
  {{- $label_params := dict "labels" (default (dict) $backend.labels) -}}
  {{- $labels := include "mozcloud-gateway-lib.labels" (mergeOverwrite ($ | deepCopy) $label_params) | fromYaml -}}
  {{- $_ = set $backend_policy_config "labels" $labels -}}
  {{- $output = append $output $backend_policy_config -}}
{{- end -}}
{{- $all_policies := dict "backendPolicies" $output -}}
{{ $all_policies | toYaml }}
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
  {{- $gateway_config := mergeOverwrite $gateway_defaults $gateway -}}
  {{- /* Use name helper function to populate name using rules hierarchy */ -}}
  {{- $params := $ | deepCopy -}}
  {{- $_ := set $params "gatewayConfig" $gateway_config -}}
  {{- $name_override := default "" $.nameOverride -}}
  {{- if $name_override -}}
    {{- $_ := set $params "nameOverride" $name_override -}}
  {{- end -}}
  {{- $name := include "mozcloud-gateway-lib.config.name" $params -}}
  {{- $_ = set $gateway_config "name" $name -}}
  {{- /* Use helper function to determine className if not defined */ -}}
  {{- if not $gateway_config.className -}}
    {{- $class_name := include "mozcloud-gateway-lib.config.gateway.className" $gateway_config -}}
    {{- $_ = set $gateway_config "className" $class_name -}}
  {{- end -}}
  {{- /* Generate labels */ -}}
  {{- $label_params := dict "labels" (default (dict) $gateway_config.labels) -}}
  {{- $labels := include "mozcloud-gateway-lib.labels" (mergeOverwrite ($ | deepCopy) $label_params) | fromYaml -}}
  {{- $_ = set $gateway_config "labels" $labels -}}
  {{- $output = append $output $gateway_config -}}
{{- end -}}
{{- $gateways = dict "gateways" $output -}}
{{ $gateways | toYaml }}
{{- end -}}

{{/*
GatewayPolicy template helpers
*/}}
{{- define "mozcloud-gateway-lib.config.gatewayPolicies" -}}
{{- $defaults := include "mozcloud-gateway-lib.defaults.gateway.config" . | fromYaml -}}
{{- $gateway_policy := default (dict) .gatewayPolicyConfig -}}
{{- $gateways := default (list $defaults) (.gatewayConfig).gateways -}}
{{- $output := list -}}
{{- range $gateway := $gateways -}}
  {{- $gateway_defaults := include "mozcloud-gateway-lib.defaults.gateway.config" . | fromYaml -}}
  {{- $gateway_config := mergeOverwrite $gateway_defaults $gateway -}}
  {{- $policy_config := dict -}}
  {{- /* Check if any listeners use HTTPS protocol before proceeding */ -}}
  {{- $https_listener := false -}}
  {{- range $listener := $gateway_config.listeners -}}
    {{- if eq (upper $listener.protocol) "HTTPS" -}}
      {{- $https_listener = true -}}
    {{- end -}}
  {{- end -}}
  {{- $context := $ | deepCopy -}}
  {{- if $https_listener -}}
    {{- /* Use name helper function to populate name using rules hierarchy */ -}}
    {{- $params := mergeOverwrite $context (dict "gatewayConfig" $gateway_config) -}}
    {{- $name_override := default "" $.nameOverride -}}
    {{- if $name_override -}}
      {{- $_ := set $params "nameOverride" $name_override -}}
    {{- end -}}
    {{- $name := include "mozcloud-gateway-lib.config.name" $params -}}
    {{- $_ := set $policy_config "name" $name -}}
    {{- $_ = set $policy_config "gatewayName" $name -}}
    {{- /* Generate labels */ -}}
    {{- $label_params := dict "labels" (default (dict) $gateway_config.labels) -}}
    {{- $labels := include "mozcloud-gateway-lib.labels" (mergeOverwrite ($ | deepCopy) $label_params) | fromYaml -}}
    {{- $_ = set $policy_config "labels" $labels -}}
    {{- /* Merge config */ -}}
    {{- $policy_defaults := include "mozcloud-gateway-lib.defaults.gatewayPolicy.config" . | fromYaml -}}
    {{- $merged_policy := mergeOverwrite $policy_defaults $gateway_policy -}}
    {{- $_ = set $policy_config "config" $merged_policy -}}
    {{- $output = append $output $policy_config -}}
  {{- end -}}
{{- end -}}
{{- $gateway_policies := dict "gatewayPolicies" $output -}}
{{ $gateway_policies | toYaml }}
{{- end -}}

{{/*
HealthCheckPolicy template helpers
*/}}
{{- define "mozcloud-gateway-lib.config.healthCheckPolicies" -}}
{{- $defaults := include "mozcloud-gateway-lib.defaults.healthCheckPolicy.config" . | fromYaml -}}
{{- $backends := default (list) (.backendConfig).backends -}}
{{- $name_override := default "" .nameOverride -}}
{{- $output := list -}}
{{- range $backend := $backends -}}
  {{- $health_check_policy_config := dict -}}
  {{- /* Configure health check spec */ -}}
  {{- $backend_health_check_policy := default (dict) $backend.healthCheck -}}
  {{- $config := mergeOverwrite ($defaults | deepCopy) $backend_health_check_policy -}}
  {{- $_ := set $config "protocol" (upper $config.protocol) -}}
  {{- $protocol_property := include "mozcloud-gateway-lib.defaults.healthCheckPolicy.protocolProperty" . | fromYaml -}}
  {{- $_ = set $config "protocolProperty" (index $protocol_property $config.protocol) -}}
  {{- $_ = set $health_check_policy_config "config" $config -}}
  {{- /* Use name helper function to populate name and targetService using rules hierarchy */ -}}
  {{- $params := $ | deepCopy -}}
  {{- if $backend.name -}}
    {{- $_ := set $params "name" $backend.name -}}
  {{- end -}}
  {{- if $name_override -}}
    {{- $_ := set $params "nameOverride" $name_override -}}
  {{- end -}}
  {{- $name := include "mozcloud-gateway-lib.config.name" $params -}}
  {{- $_ = set $health_check_policy_config "name" $name -}}
  {{- $_ = set $health_check_policy_config "targetService" $name -}}
  {{- /* Generate labels */ -}}
  {{- $label_params := dict "labels" (default (dict) $backend.labels) -}}
  {{- $labels := include "mozcloud-gateway-lib.labels" (mergeOverwrite ($ | deepCopy) $label_params) | fromYaml -}}
  {{- $_ = set $health_check_policy_config "labels" $labels -}}
  {{- $output = append $output $health_check_policy_config -}}
{{- end -}}
{{- $all_policies := dict "healthCheckPolicies" $output -}}
{{ $all_policies | toYaml }}
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
  {{- $params := $ | deepCopy -}}
  {{- $_ := set $params "httpRouteConfig" $http_route_config -}}
  {{- $name_override := default "" $.nameOverride -}}
  {{- if $name_override -}}
    {{- $_ := set $params "nameOverride" $name_override -}}
  {{- end -}}
  {{- $name := include "mozcloud-gateway-lib.config.name" $params -}}
  {{- $_ = set $http_route_config "name" $name -}}
  {{- /* Generate labels */ -}}
  {{- $label_params := dict "labels" (default (dict) $http_route_config.labels) -}}
  {{- $labels := include "mozcloud-gateway-lib.labels" (mergeOverwrite ($ | deepCopy) $label_params) | fromYaml -}}
  {{- $_ = set $http_route_config "labels" $labels -}}
  {{- /*
  Set defaults for matches, redirects and rewrites, if defined.
  We will need to recreate the rule list as some items in child lists have
  optional values and defaults.
  */ -}}
  {{- $rules := list -}}
  {{- range $rule := $http_route_config.rules -}}
    {{- $rule_defaults := include "mozcloud-gateway-lib.defaults.httpRoute.config" . | fromYaml -}}
    {{- $rule_config := mergeOverwrite ($rule_defaults.rules | first) ($rule | deepCopy) -}}
    {{- /* Matches */ -}}
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
    {{- /* Redirects */ -}}
    {{- if $rule_config.redirect -}}
      {{- $redirect_config := mergeOverwrite $rule_defaults.redirect $rule_config.redirect -}}
      {{- $_ := set $rule_config "redirect" $redirect_config -}}
    {{- end -}}
    {{- /* Rewrites */ -}}
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
Service template helpers
*/}}
{{- define "mozcloud-gateway-lib.config.service" -}}
{{- $name_override := default "" .nameOverride -}}
{{- $backends := default (list) (.backendConfig).backends -}}
{{- $output := list -}}
{{- range $backend := $backends -}}
  {{- $defaults := include "mozcloud-gateway-lib.defaults.service.config" . | fromYaml -}}
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
  {{- $name := include "mozcloud-gateway-lib.config.name" $params -}}
  {{- $_ = set $service_config "fullnameOverride" $name -}}
  {{- /* Include annotations, if specified */ -}}
  {{- if $backend_service.annotations -}}
    {{- $_ := set $service_config "annotations" $backend_service.annotations -}}
  {{- end -}}
  {{- /* Generate labels */ -}}
  {{- $backend_labels := dict "labels" (default (dict) $backend.labels) -}}
  {{- $backend_service_labels := dict "labels" (default (dict) $backend_service.labels) -}}
  {{- $label_params := dict "labels" (mergeOverwrite $backend_labels.labels $backend_service_labels.labels) -}}
  {{- $labels := include "mozcloud-gateway-lib.labels" (mergeOverwrite ($ | deepCopy) $label_params) | fromYaml -}}
  {{- $_ = set $service_config "labels" $labels -}}
  {{- /* Generate selectorLabels */ -}}
  {{- $selector_label_params := dict "selectorLabels" (default (dict) $backend_service.selectorLabels) -}}
  {{- $selector_labels := include "mozcloud-gateway-lib.selectorLabels" (mergeOverwrite ($ | deepCopy) $selector_label_params) | fromYaml -}}
  {{- $_ = set $service_config "selectorLabels" $selector_labels -}}
  {{- /* Service config */ -}}
  {{- $config := include "mozcloud-gateway-lib.config.service.config" $backend_service | fromYaml -}}
  {{- $_ = set $service_config "config" $config -}}
  {{- $output = append $output $service_config -}}
{{- end -}}
{{- $services := dict "services" $output -}}
{{ $services | toYaml }}
{{- end -}}


{{- define "mozcloud-gateway-lib.config.service.config" -}}
{{- $defaults := (include "mozcloud-gateway-lib.defaults.service.config" . | fromYaml) -}}
ports:
  - port: {{ default $defaults.port .port }}
    targetPort: {{ default $defaults.targetPort .targetPort }}
    protocol: {{ default $defaults.protocol .protocol }}
    name: {{ default $defaults.portName .portName }}
type: {{ $defaults.type }}
{{- end -}}

{{/*
Defaults
*/}}
{{- define "mozcloud-gateway-lib.defaults.backendPolicy.config" -}}
logging:
  enabled: true
  sampleRate: 100000
{{- end -}}

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

{{- define "mozcloud-gateway-lib.defaults.gatewayPolicy.config" -}}
sslPolicy: mozilla-intermediate
{{- end -}}

{{- define "mozcloud-gateway-lib.defaults.healthCheckPolicy.config" -}}
path: /__lbheartbeat__
protocol: http
{{- end -}}

{{- define "mozcloud-gateway-lib.defaults.healthCheckPolicy.protocolProperty" -}}
HTTP: httpHealthCheck
TCP: tcpHealthCheck
{{- end -}}

{{- define "mozcloud-gateway-lib.defaults.httpRoute.config" -}}
gatewayRefs:
  - name: {{ include "mozcloud-gateway-lib.config.name" . }}
    section: https
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

{{- define "mozcloud-gateway-lib.defaults.service.config" -}}
create: true
port: 8080
portName: http
protocol: TCP
targetPort: http
{{- end -}}

{{/*
Debug helper
*/}}
{{- define "mozcloud-gateway-lib.debug" -}}
{{- . | mustToPrettyJson | printf "\nThe JSON output of the dumped var is: \n%s" | fail }}
{{- end -}}
