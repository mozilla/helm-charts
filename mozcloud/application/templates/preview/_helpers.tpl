{{/*
Preview template helpers
*/}}

{{/*
Check if preview mode is enabled and has required configuration
*/}}
{{- define "mozcloud.preview.enabled" -}}
{{- if and .Values.preview.enabled .Values.global.preview .Values.global.preview.pr -}}
true
{{- end -}}
{{- end -}}


{{/*
Check if preview endpoint check should be enabled
Defaults to true if not explicitly set
*/}}
{{- define "mozcloud.preview.endpointCheckEnabled" -}}
{{- if include "mozcloud.preview.enabled" . -}}
  {{- $endpointCheckEnabled := true -}}
  {{- if .Values.preview.endpointCheck -}}
    {{- if hasKey .Values.preview.endpointCheck "enabled" -}}
      {{- $endpointCheckEnabled = .Values.preview.endpointCheck.enabled -}}
    {{- end -}}
  {{- end -}}
  {{- if $endpointCheckEnabled -}}
true
  {{- end -}}
{{- end -}}
{{- end -}}


{{/*
Get all preview hostnames from HTTP routes

This helper transforms HTTP routes for preview mode and extracts all unique hostnames.
Combines transformation and extraction in a single step for convenience.

Params:
  httpRoutes: The original httpRoutes structure from mozcloud.gateway.httpRoutes
  previewHost: The base preview host from .Values.preview.host

Returns:
  A dict with a "hostnames" key containing a list of unique preview hostnames in YAML format

Example:
  Input:
    httpRoutes with original hostnames
    previewHost: "pr456-test.preview.mozilla.cloud"
  Output:
    hostnames:
      - api-pr456-test.preview.mozilla.cloud
      - web-pr456-test.preview.mozilla.cloud
*/}}
{{- define "mozcloud.preview.getAllHostnames" -}}
{{- $httpRoutes := .httpRoutes -}}
{{- $previewHost := .previewHost -}}
{{- $routeCount := len $httpRoutes -}}
{{- $allHostnames := list -}}
{{- range $routeName, $routeConfig := $httpRoutes -}}
  {{- range $hostname := $routeConfig.hostnames -}}
    {{- if gt $routeCount 1 -}}
      {{- $prefix := first (splitList "." (print $hostname)) -}}
      {{- $allHostnames = append $allHostnames (printf "%s-%s" $prefix $previewHost) -}}
    {{- else -}}
      {{- $allHostnames = append $allHostnames $previewHost -}}
    {{- end -}}
  {{- end -}}
{{- end -}}
{{- dict "hostnames" (uniq $allHostnames) | toYaml -}}
{{- end -}}


{{/*
Generate preview prefix if preview mode is enabled
*/}}
{{- define "mozcloud.preview.prefix" -}}
{{- if include "mozcloud.preview.enabled" . -}}
{{- printf "pr%v-" .Values.global.preview.pr -}}
{{- end -}}
{{- end -}}


{{/*
Transform ConfigMap data for preview mode
Populates empty URL variables with preview host for keys specified in preview.urlTransformKeys
No transformation occurs by default - keys must be explicitly listed
*/}}
{{- define "mozcloud.preview.transformConfigMapData" -}}
{{- $data := .data -}}
{{- $previewHost := .previewHost -}}
{{- $transformKeys := .transformKeys | default list -}}
{{- $transformedData := dict -}}
{{- range $key, $value := $data -}}
  {{- $shouldTransform := false -}}
  {{- /* Check if key is in the explicit transform list */ -}}
  {{- range $transformKeys -}}
    {{- if eq $key . -}}
      {{- $shouldTransform = true -}}
    {{- end -}}
  {{- end -}}
  {{- /* Transform if key is listed and value is empty */ -}}
  {{- if and $shouldTransform (or (not $value) (eq $value "")) -}}
    {{- $_ := set $transformedData $key (printf "https://%s" $previewHost) -}}
  {{- else -}}
    {{- $_ := set $transformedData $key $value -}}
  {{- end -}}
{{- end -}}
{{ $transformedData | toYaml }}
{{- end -}}


{{/*
Transform HTTP routes for preview mode

This helper takes the full HTTP routes structure and transforms all hostnames
for preview mode. For multiple routes, it prefixes each hostname with the first
part of the original hostname.

Params:
  httpRoutes: The httpRoutes structure from mozcloud.gateway.httpRoutes
  previewHost: The base preview host from .Values.preview.host

Returns:
  The HTTP routes structure with transformed hostnames in YAML format

Example input:
  httpRoutes:
    api-host:
      hostnames: ["api.example.com"]
    web-host:
      hostnames: ["web.example.com"]
  previewHost: "pr456-test.preview.mozilla.cloud"

Example output:
  httpRoutes:
    api-host:
      hostnames: ["api-pr456-test.preview.mozilla.cloud"]
    web-host:
      hostnames: ["web-pr456-test.preview.mozilla.cloud"]
*/}}
{{- define "mozcloud.preview.transformHttpRoutes" -}}
{{- $httpRoutes := .httpRoutes -}}
{{- $previewHost := .previewHost -}}
{{- $routeCount := len $httpRoutes -}}
{{- $transformedRoutes := dict -}}
{{- range $routeName, $routeConfig := $httpRoutes -}}
  {{- $transformedConfig := $routeConfig | deepCopy -}}
  {{- $previewHostnames := list -}}
  {{- range $hostname := $routeConfig.hostnames -}}
    {{- if gt $routeCount 1 -}}
      {{- $prefix := first (splitList "." (print $hostname)) -}}
      {{- $previewHostnames = append $previewHostnames (printf "%s-%s" $prefix $previewHost) -}}
    {{- else -}}
      {{- $previewHostnames = append $previewHostnames $previewHost -}}
    {{- end -}}
  {{- end -}}
  {{- $_ := set $transformedConfig "hostnames" $previewHostnames -}}
  {{- $_ := set $transformedRoutes $routeName $transformedConfig -}}
{{- end -}}
{{- dict "httpRoutes" $transformedRoutes | toYaml -}}
{{- end -}}


{{/*
Check if preview HTTPRoute should be used instead of standard
Defaults to true if not explicitly set
*/}}
{{- define "mozcloud.preview.usePreviewHttpRoute" -}}
{{- if include "mozcloud.preview.enabled" . -}}
  {{- $httpRouteEnabled := true -}}
  {{- if .Values.preview.httpRoute -}}
    {{- if hasKey .Values.preview.httpRoute "enabled" -}}
      {{- $httpRouteEnabled = .Values.preview.httpRoute.enabled -}}
    {{- end -}}
  {{- end -}}
  {{- if $httpRouteEnabled -}}
true
  {{- end -}}
{{- end -}}
{{- end -}}
