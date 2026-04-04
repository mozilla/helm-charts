{{- /*
Preview-mode formatter for ConfigMap configurations. When preview mode is
active, prefixes each ConfigMap name with the preview PR prefix (e.g.
"pr123-"). Additionally, for any data keys listed in
.Values.preview.urlTransformKeys, replaces empty string values with the full
preview host URL (e.g. "https://pr123-app.preview.mozilla.cloud").

This allows preview environments to automatically populate URL-type environment
variables that would otherwise reference production hostnames.

Params:
  configMaps (dict): (required) The full ConfigMap configuration from
                     .Values.configMaps.
  context (dict):    (required) The Helm root context from the calling
                     template.

Returns:
  (string) YAML-encoded dict of ConfigMap configurations with preview-adjusted
           names and data values, keyed by (prefixed) ConfigMap name.

Example:
  Input:
    configMaps:
      app-config:
        data:
          APP_URL: ""
          LOG_LEVEL: info
    # preview active: pr=123, host="pr123.preview.mozilla.cloud"
    # .Values.preview.urlTransformKeys: [APP_URL]

  Output:
    pr123-app-config:
      data:
        APP_URL: "https://pr123.preview.mozilla.cloud"  # was empty, replaced
        LOG_LEVEL: info                                 # non-empty, unchanged
*/ -}}
{{- define "mozcloud.configMap.formatter.preview" -}}
{{- $configMaps := .configMaps -}}
{{- $context := .context -}}
{{- $output := .configMaps -}}
{{- if include "mozcloud.preview.enabled" $context -}}
  {{- $prefix := include "mozcloud.preview.prefix" $context -}}
  {{- $transformKeys := default list ($context.Values.preview).urlTransformKeys -}}
  {{- $output = dict -}}
  {{- range $name, $config := $configMaps -}}
    {{- /* Apply preview prefix to config map names if in preview mode */ -}}
    {{- $name = printf "%s%s" $prefix $name -}}
    {{- /*
    Transform specific config map keys for preview environments.

    Many services have environment variables that reference static hostnames or
    URLs. These need to be transformed to use the generated preview hostname
    instead.
    */ -}}
    {{- $params := dict "data" $config.data "previewHost" $context.Values.global.preview.host "transformKeys" $transformKeys -}}
    {{- $transformedData := include "mozcloud.preview.transformConfigMapData" $params | fromYaml -}}
    {{- $config = mergeOverwrite $config (dict "data" $transformedData) -}}
    {{- $_ := set $output $name $config -}}
  {{- end -}}
{{- end -}}
{{ $output | toYaml }}
{{- end -}}

{{- define "mozcloud.configMap.formatter.tpl" -}}
  {{- $configMaps := .configMaps -}}
  {{- $context := .context -}}
  {{- $output := deepCopy .configMaps -}}
  {{- range $name, $config := $configMaps -}}
    {{- if $config.tplEnabled }}
      {{- $params := dict "data" $config.data "context" $context }}
      {{- $transformedData := include "mozcloud.configMap.formatter.renderTpl" $params | fromYaml -}}
      {{- $_ := set $config "data" $transformedData -}}
    {{- $_ := set $output $name $config}}
    {{- end -}}
  {{- end -}}
{{ $output | toYaml }}
{{- end -}}

{{- /*
  Ranges over a dictionary and renders template expressions in values using `tpl`.
  Blocks dangerous functions (lookup, env) via a blocklist. If a rendered value
  is empty, the key is omitted from the output.
*/ -}}
{{- define "mozcloud.configMap.formatter.renderTpl" }}
{{- $ctx := .context }}
{{- $output := deepCopy .data }}
{{- $tplRegexp := `{{-?\s*[^}]+}}` }}
{{- $blockRegexp := `\b(lookup|env|expandenv|getHostByName)\b` }}
{{- range $key, $value := .data }}
  {{- $matches := regexFindAll $tplRegexp (toString $value) -1 }}
  {{- if $matches }}
    {{- range $_, $match := $matches }}
      {{- if regexMatch $blockRegexp $match }}
        {{- fail (printf "configMap tplEnabled: expression %q in key %q uses a blocked function" $match $key) }}
      {{- end }}
    {{- end }}
    {{- $newVal := tpl $value $ctx }}
    {{- if and (ne $newVal "") (ne $newVal "<nil>") (ne $newVal "<no value>") }}
      {{- $_ := set $output $key $newVal }}
    {{- else }}
      {{- $_ := unset $output $key }}
    {{- end }}
  {{- end }}
{{- end }}
{{ $output | toYaml }}
{{- end }}
