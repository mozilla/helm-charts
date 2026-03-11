{{/*
Preview template helpers
*/}}

{{- /*
Checks whether preview mode is fully active. All three of the following must
be true: .Values.preview.enabled is set, .Values.global.preview exists (the
chart-injected preview config block), and .Values.global.preview.pr is set
(the PR number). Returns an empty string when any condition is not met.

Params:
  . (dict): (required) The Helm root context.

Returns:
  (string) "true" if preview mode is active, empty string otherwise.
*/ -}}
{{- define "mozcloud.preview.enabled" -}}
{{- if and .Values.preview.enabled .Values.global.preview .Values.global.preview.pr -}}
true
{{- end -}}
{{- end -}}


{{- /*
Checks whether the preview endpoint check Job should be rendered. Only
relevant when preview mode is active (as determined by
mozcloud.preview.enabled). Defaults to true unless explicitly disabled via
.Values.preview.endpointCheck.enabled.

Params:
  . (dict): (required) The Helm root context.

Returns:
  (string) "true" if the endpoint check Job should be rendered, empty string
           otherwise.
*/ -}}
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


{{- /*
Extracts all unique preview-transformed hostnames from an HTTP routes structure.
For each route's hostname list, applies the same transformation logic as
mozcloud.preview.transformHttpRoutes:
  - Single route: the preview host is used directly as the hostname.
  - Multiple routes: the first DNS label of each original hostname is prepended
    to the preview host (e.g. "api.example.com" with preview host
    "pr123.preview.mozilla.cloud" → "api-pr123.preview.mozilla.cloud").

The resulting list is deduplicated before being returned.

Params:
  httpRoutes (dict):    (required) The inner httpRoutes dict as returned by
                        mozcloud.gateway.httpRoutes (the value under the
                        "httpRoutes" key, not the wrapper dict).
  previewHost (string): (required) The base preview hostname from
                        .Values.global.preview.host.

Returns:
  (string) YAML-encoded dict with a "hostnames" key containing a deduplicated
           list of preview hostnames.

Example:
  Input:
    httpRoutes:
      api-host:
        hostnames: ["api.example.com"]
      web-host:
        hostnames: ["web.example.com"]
    previewHost: pr123.preview.mozilla.cloud

  Output:
    hostnames:
      - api-pr123.preview.mozilla.cloud
      - web-pr123.preview.mozilla.cloud
*/ -}}
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


{{- /*
Returns the preview PR prefix string (e.g. "pr123-") when preview mode is
active, or an empty string otherwise. Used to prefix resource names in preview
environments so they do not conflict with production resources.

Params:
  . (dict): (required) The Helm root context.

Returns:
  (string) The preview prefix (e.g. "pr123-"), or empty string if not in
           preview mode.
*/ -}}
{{- define "mozcloud.preview.prefix" -}}
{{- if include "mozcloud.preview.enabled" . -}}
{{- printf "pr%v-" .Values.global.preview.pr -}}
{{- end -}}
{{- end -}}


{{- /*
Transforms ConfigMap data values for preview environments. For each key listed
in transformKeys, if the current value is empty, replaces it with the full
preview host URL (e.g. "https://pr123-app.preview.mozilla.cloud"). Keys not
in the transform list, or with non-empty values, are passed through unchanged.

No transformation occurs by default — keys must be explicitly listed in
transformKeys.

Params:
  data (dict):           (required) The ConfigMap data dict to transform.
  previewHost (string):  (required) The base preview hostname from
                         .Values.global.preview.host.
  transformKeys (list):  (optional) List of data key names whose empty values
                         should be replaced with the preview host URL.

Returns:
  (string) YAML-encoded dict of (potentially) transformed ConfigMap data.

Example:
  Input:
    data:
      APP_URL: ""
      DATABASE_URL: postgres://prod-db:5432/myapp
      STATIC_DOMAIN: ""
    previewHost: pr123-myapp.preview.mozilla.cloud
    transformKeys: [APP_URL, STATIC_DOMAIN]

  Output:
    APP_URL: "https://pr123-myapp.preview.mozilla.cloud"    # was empty, replaced
    DATABASE_URL: postgres://prod-db:5432/myapp             # non-empty, unchanged
    STATIC_DOMAIN: "https://pr123-myapp.preview.mozilla.cloud" # was empty, replaced
*/ -}}
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


{{- /*
Transforms all HTTPRoute hostnames in the provided routes structure for preview
mode. The full routes dict structure is preserved — only the "hostnames" list
within each route config is replaced.

Hostname transformation rules:
  - Single route: each hostname is replaced with the preview host directly.
  - Multiple routes: the first DNS label of each original hostname is prepended
    to the preview host (e.g. "api.example.com" with preview host
    "pr123.preview.mozilla.cloud" → "api-pr123.preview.mozilla.cloud").

Params:
  httpRoutes (dict):    (required) The inner httpRoutes dict as returned by
                        mozcloud.gateway.httpRoutes (the value under the
                        "httpRoutes" key, not the wrapper dict).
  previewHost (string): (required) The base preview hostname from
                        .Values.global.preview.host.

Returns:
  (string) YAML-encoded dict with an "httpRoutes" key containing the full
           routes structure with transformed hostnames.

Example:
  Input:
    httpRoutes:
      api-host:
        hostnames: ["api.example.com"]
      web-host:
        hostnames: ["web.example.com"]
    previewHost: pr456-test.preview.mozilla.cloud

  Output:
    httpRoutes:
      api-host:
        hostnames:
          - api-pr456-test.preview.mozilla.cloud
      web-host:
        hostnames:
          - web-pr456-test.preview.mozilla.cloud
*/ -}}
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


{{- /*
Checks whether the preview HTTPRoute (pointing to the shared preview gateway)
should be rendered instead of the standard HTTPRoute. Only relevant when
preview mode is active. Defaults to true unless explicitly disabled via
.Values.preview.httpRoute.enabled.

When this returns "true", preview/httpRoute.yaml renders a PR-prefixed
HTTPRoute pointing to the shared preview gateway, and the standard HTTPRoute
in gateway/httproute.yaml is skipped.

Params:
  . (dict): (required) The Helm root context.

Returns:
  (string) "true" if the preview HTTPRoute should be rendered, empty string
           otherwise.
*/ -}}
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
