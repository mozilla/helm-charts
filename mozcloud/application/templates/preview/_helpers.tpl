{{/*
Preview template helpers
*/}}

{{/*
Transform HTTP routes for preview mode

This helper takes the full HTTP routes structure and transforms all hostnames
for preview mode. For multiple routes, it prefixes each hostname with the first
part of the original hostname.

Params:
  httpRoutes: The httpRoutes structure from mozcloud.config.httpRoutes
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
{{- define "preview.transformHttpRoutes" -}}
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
Get all preview hostnames from HTTP routes

This helper transforms HTTP routes for preview mode and extracts all unique hostnames.
Combines transformation and extraction in a single step for convenience.

Params:
  httpRoutes: The original httpRoutes structure from mozcloud.config.httpRoutes
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
{{- define "preview.getAllHostnames" -}}
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
