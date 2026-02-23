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
{{- $http_routes := .httpRoutes -}}
{{- $preview_host := .previewHost -}}
{{- $route_count := len $http_routes -}}
{{- $transformed_routes := dict -}}
{{- range $route_name, $route_config := $http_routes -}}
  {{- $transformed_config := $route_config | deepCopy -}}
  {{- $preview_hostnames := list -}}
  {{- range $hostname := $route_config.hostnames -}}
    {{- if gt $route_count 1 -}}
      {{- $prefix := first (splitList "." (print $hostname)) -}}
      {{- $preview_hostnames = append $preview_hostnames (printf "%s-%s" $prefix $preview_host) -}}
    {{- else -}}
      {{- $preview_hostnames = append $preview_hostnames $preview_host -}}
    {{- end -}}
  {{- end -}}
  {{- $_ := set $transformed_config "hostnames" $preview_hostnames -}}
  {{- $_ := set $transformed_routes $route_name $transformed_config -}}
{{- end -}}
{{- dict "httpRoutes" $transformed_routes | toYaml -}}
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
{{- $http_routes := .httpRoutes -}}
{{- $preview_host := .previewHost -}}
{{- $route_count := len $http_routes -}}
{{- $all_hostnames := list -}}
{{- range $route_name, $route_config := $http_routes -}}
  {{- range $hostname := $route_config.hostnames -}}
    {{- if gt $route_count 1 -}}
      {{- $prefix := first (splitList "." (print $hostname)) -}}
      {{- $all_hostnames = append $all_hostnames (printf "%s-%s" $prefix $preview_host) -}}
    {{- else -}}
      {{- $all_hostnames = append $all_hostnames $preview_host -}}
    {{- end -}}
  {{- end -}}
{{- end -}}
{{- dict "hostnames" (uniq $all_hostnames) | toYaml -}}
{{- end -}}
