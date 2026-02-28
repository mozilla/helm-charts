{{- /*
This function reworks config map data structures for preview environments.
Specifically, a PR number will be prefixed to the config map name and, if
desired, certain values will be transformed based on user configurations in
.Values.preview.urlTransformKeys.

Params:

configMaps (dict): (required) The full config map configuration defined in
                   .Values.configMaps.
context (dict): (required) The context of the template calling this function.
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
    {{- $transformedData := include "common.formatter.renderEmbeddedTpl" $params | fromYaml -}}
    {{- $config = mergeOverwrite $config (dict "data" $transformedData) -}}
    {{ $_ := set $output $name $config}}
    {{- end -}}
  {{- end -}}
{{ $output | toYaml }}
{{- end -}}
