{{/*
_helpers.tpl for mozcloud-shared-data-lib

This file contains logic to read and expose data from common-data.yaml.
*/}}

{{/*
Load common data from files in the shared library.
This function should be called from within the shared library context.
*/}}
{{- define "mozcloud-shared-data-lib.loadCommonData" -}}
{{- .Files.Get "files/common-data.yaml" -}}
{{- end -}}

{{/*
mozcloud-shared-data-lib.getDynamicData
Retrieves a specific set of data from common-data.yaml based on app_code and data key.
If app_code matches a key in common-data.yaml and the specified data key exists,
it will return all key-value pairs from that matched dictionary as YAML.
Usage:
  {{- include "mozcloud-shared-data-lib.getDynamicData" (dict "context" . "appCode" "jameslabel" "dataKey" "labels") | nindent 4 }}
*/}}
{{- define "mozcloud-shared-data-lib.getDynamicData" -}}
{{- $app_code := .appCode -}}
{{- $data_key := .dataKey -}}
{{- $common_data_yaml := include "mozcloud-shared-data-lib.commonData" .context -}}
  {{- if $common_data_yaml -}}
    {{- $common_data := $common_data_yaml | fromYaml -}}
    {{- if $common_data -}}
      {{- $app_data := dict -}}
      {{- if hasKey $common_data $app_code -}}
        {{- $app_data = index $common_data $app_code -}}
      {{- end -}}
      {{- if $app_data -}}
        {{- $data_set := index $app_data $data_key -}}
        {{- if $data_set -}}
          {{- range $key, $value := $data_set }}
{{ $key }}: {{ $value | toString | quote }}
          {{- end }}
        {{- end -}}
      {{- end -}}
    {{- end -}}
  {{- end -}}
{{- end -}}



{{/*
mozcloud-shared-data-lib.smartMergeData
A convenience function that automatically merges the two standard data sources:
1. Dynamic data from mozcloud-shared-data-lib
2. Custom data from values

The precedence parameter controls which data takes priority:
- "local": Local/custom data takes precedence (default)  - uses data from the values.yaml files
- "shared": Shared/global data takes precedence  - uses data from the chart itself or from the data helm library - ignores local variable values

Parameters:
- . (context): The template context
- appCode: The application code to look up in common-data.yaml
- dataKey: The key within the app_code section to retrieve (e.g., "labels", "notifications")
- customData: Custom data to merge (typically .Values.podLabels or similar)
- precedence: "shared" or "local" (default) - determines which data takes priority

Usage:
  {{- include "mozcloud-shared-data-lib.smartMergeData" (dict "context" . "appCode" "jameslabel" "dataKey" "labels" "customData" .Values.labels) | nindent 8 }}
  {{- include "mozcloud-shared-data-lib.smartMergeData" (dict "context" . "appCode" "jameslabel" "dataKey" "labels" "customData" .Values.labels "precedence" "shared") | nindent 8 }}
*/}}
{{- define "mozcloud-shared-data-lib.smartMergeData" -}}
{{- $dynamic_data := default (dict) (include "mozcloud-shared-data-lib.getDynamicData" (dict "context" .context "appCode" .appCode "dataKey" .dataKey) | fromYaml) -}}
{{- $custom_data := .customData | default dict -}}
{{- $precedence := .precedence | default "local" -}}
{{- $merged_yaml := "" -}}
{{- if eq $precedence "local" -}}
  {{- $merged_yaml = include "mozcloud-shared-data-lib.mergeDataPreferLocal" (dict "globalData" $dynamic_data "localData" $custom_data) -}}
{{- else -}}
  {{- $merged_yaml = include "mozcloud-shared-data-lib.mergeDataPreferShared" (dict "globalData" $dynamic_data "localData" $custom_data) -}}
{{- end -}}
{{- $merged := $merged_yaml | fromYaml -}}
{{- range $key, $value := $merged }}
{{ $key }}: {{ $value | toString | quote }}
{{- end -}}
{{- end -}}

{{/*
mozcloud-shared-data-lib.mergeDataPreferLocal
Merges global and local data with local data taking precedence.
Local values will override global/shared values for duplicate keys.

Parameters:
- globalData: The global/shared data (dict)
- localData: The local/custom data (dict)

Usage:
  {{- $merged := include "mozcloud-shared-data-lib.mergeDataPreferLocal" (dict "globalData" $globalData "localData" $localData) | fromYaml -}}
*/}}
{{- define "mozcloud-shared-data-lib.mergeDataPreferLocal" -}}
{{- $merged := .globalData | default dict -}}
{{- if .localData -}}
  {{- $merged = mergeOverwrite $merged .localData -}}
{{- end -}}
{{- $merged | toYaml -}}
{{- end -}}

{{/*
mozcloud-shared-data-lib.mergeDataPreferShared
Merges global and local data with shared/global data taking precedence.
Global/shared values will override local values for duplicate keys.

Parameters:
- globalData: The global/shared data (dict)
- localData: The local/custom data (dict)

Usage:
  {{- $merged := include "mozcloud-shared-data-lib.mergeDataPreferShared" (dict "globalData" $globalData "localData" $localData) | fromYaml -}}
*/}}
{{- define "mozcloud-shared-data-lib.mergeDataPreferShared" -}}
{{- $merged := .localData | default dict -}}
{{- if .globalData -}}
  {{- $merged = mergeOverwrite $merged .globalData -}}
{{- end -}}
{{- $merged | toYaml -}}
{{- end -}}

{{/*
mozcloud-shared-data-lib.mergeDataOnly
Legacy function for backward compatibility - calls mergeDataPreferLocal.
A simpler function that just merges global and local data with local precedence.
Useful when you don't need the chart-specific data.

Parameters:
- globalData: The global/shared data (dict)
- localData: The local/custom data (dict)

Usage:
  {{- $merged := include "mozcloud-shared-data-lib.mergeDataOnly" (dict "globalData" $globalData "localData" $localData) | fromYaml -}}
*/}}
{{- define "mozcloud-shared-data-lib.mergeDataOnly" -}}
{{- include "mozcloud-shared-data-lib.mergeDataPreferLocal" . -}}
{{- end -}}

{{/*
Debug helper
*/}}
{{- define "mozcloud-shared-data-lib.debug" -}}
{{- . | mustToPrettyJson | printf "\nThe JSON output of the dumped var is: \n%s" | fail }}
{{- end -}}
