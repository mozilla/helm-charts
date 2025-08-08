{{/*
_helpers.tpl for mozcloud-shared-data-lib

This file contains logic to read and expose data from common-data.yaml.
*/}}

{{- define "mozcloud-shared-data-lib.loadCommonData" -}}
{{/*
    Load common data from files in the shared library.
    This function should be called from within the shared library context.
    */}}
{{-   .Files.Get "files/common-data.yaml" -}}
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
{{-   $commonDataYaml := include "mozcloud-shared-data-lib.commonData" .context -}}
{{-   if $commonDataYaml -}}
{{-     $commonData := $commonDataYaml | fromYaml -}}
{{-     if $commonData -}}
{{-       $appCode := .appCode -}}
{{-       $dataKey := .dataKey -}}
{{-       $appData := index $commonData $appCode -}}
{{-       if $appData -}}
{{-         $dataSet := index $appData $dataKey -}}
{{-         if $dataSet -}}
{{-           range $key, $value := $dataSet }}
{{ $key }}: {{ $value | toString | quote }}
{{-           end }}
{{-         end -}}
{{-       end -}}
{{-     end -}}
{{-   end -}}
{{- end -}}



{{/*
mozcloud-shared-data-lib.smartMergeData
A convenience function that automatically merges the three standard data sources:
1. Dynamic data from mozcloud-shared-data-lib
2. Chart-specific data  
3. Custom data from values

The precedence parameter controls which data takes priority:
- "shared": Shared/global data takes precedence (default)
- "local": Local/custom data takes precedence

Parameters:
- . (context): The template context
- appCode: The application code to look up in common-data.yaml
- dataKey: The key within the app_code section to retrieve (e.g., "labels", "notifications")
- chartDataTemplate: The name of the chart's data template (e.g., "jameslabel.labels")
- customData: Custom data to merge (typically .Values.podLabels or similar)
- precedence: "shared" (default) or "local" - determines which data takes priority

Usage:
  {{- include "mozcloud-shared-data-lib.smartMergeData" (dict "context" . "appCode" "jameslabel" "dataKey" "labels" "chartDataTemplate" "jameslabel.labels" "customData" .Values.labels) | nindent 8 }}
  {{- include "mozcloud-shared-data-lib.smartMergeData" (dict "context" . "appCode" "jameslabel" "dataKey" "labels" "chartDataTemplate" "jameslabel.labels" "customData" .Values.labels "precedence" "local") | nindent 8 }}
*/}}
{{- define "mozcloud-shared-data-lib.smartMergeData" -}}
{{-   $dynamicDataYaml := include "mozcloud-shared-data-lib.getDynamicData" (dict "context" .context "appCode" .appCode "dataKey" .dataKey) -}}
{{-   $chartDataYaml := "" -}}
{{-   if .chartDataTemplate -}}
{{-     $chartDataYaml = include .chartDataTemplate .context -}}
{{-   end -}}
{{-   $dynamicData := dict -}}
{{-   if $dynamicDataYaml -}}
{{-     $dynamicData = $dynamicDataYaml | fromYaml -}}
{{-   end -}}
{{-   $chartData := dict -}}
{{-   if $chartDataYaml -}}
{{-     $chartData = $chartDataYaml | fromYaml -}}
{{-   end -}}
{{-   $customData := .customData | default dict -}}
{{-   $precedence := .precedence | default "shared" -}}
{{-   $sharedData := mergeOverwrite $dynamicData $chartData -}}
{{-   $mergedYaml := "" -}}
{{-   if eq $precedence "local" -}}
{{-     $mergedYaml = include "mozcloud-shared-data-lib.mergeDataPreferLocal" (dict "globalData" $sharedData "localData" $customData) -}}
{{-   else -}}
{{-     $mergedYaml = include "mozcloud-shared-data-lib.mergeDataPreferShared" (dict "globalData" $sharedData "localData" $customData) -}}
{{-   end -}}
{{-   $merged := $mergedYaml | fromYaml -}}
{{-   range $key, $value := $merged }}
{{ $key }}: {{ $value | toString | quote }}
{{-   end -}}
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
{{-   $merged := .globalData | default dict -}}
{{-   if .localData -}}
{{-     $merged = mergeOverwrite $merged .localData -}}
{{-   end -}}
{{-   $merged | toYaml -}}
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
{{-   $merged := .localData | default dict -}}
{{-   if .globalData -}}
{{-     $merged = mergeOverwrite $merged .globalData -}}
{{-   end -}}
{{-   $merged | toYaml -}}
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
{{-   include "mozcloud-shared-data-lib.mergeDataPreferLocal" . -}}
{{- end -}}