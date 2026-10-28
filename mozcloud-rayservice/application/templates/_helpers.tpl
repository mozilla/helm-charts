{{/*
Expand the name of the chart.
*/}}
{{- define "mozcloud-rayservice.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- /*
Builds the label parameter dict to pass to the mozcloud-labels-lib library
chart. Mirrors mozcloud.labelParams in the mozcloud chart, so that the labels
this chart renders are indistinguishable from mozcloud's own -- except for
preview.pr, which mozcloud-rayservice does not support (no RayService tenant
runs preview environments yet).

Params:
  . (dict): (required) The Helm root context.

Returns:
  (string) YAML-encoded dict of label parameters for use with
           mozcloud-labels-lib.
*/ -}}
{{- define "mozcloud-rayservice.labelParams" -}}
{{- $params := dict "chart" (include "mozcloud-rayservice.name" .) -}}
{{- $labelParams := list "app_code" "artifact_id" "chart" "env_code" "project_id" -}}
{{- range $labelParam := $labelParams -}}
  {{- if index $.Values.global.mozcloud $labelParam -}}
    {{- $_ := set $params $labelParam (index $.Values.global.mozcloud $labelParam) -}}
  {{- end }}
{{- end }}
{{- $chartLabels := dict "mozcloud_chart" .Chart.Name "mozcloud_chart_version" .Chart.Version -}}
{{- $params = mergeOverwrite $params $chartLabels -}}
{{- $params | toYaml }}
{{- end }}

{{- /*
Calls mozcloud-labels-lib to generate the standard MozCloud labels for a
single workload. Mirrors mozcloud.labels in the mozcloud chart.

Params:
  context (dict): (required) label params (see labelParams above) merged
                   with a "component_code" key for this workload.
  labels (dict):  (optional) User-provided labels to merge in as a base.

Returns:
  (string) YAML-encoded dict with a "labels" key.
*/ -}}
{{- define "mozcloud-rayservice.labels" -}}
{{- $params := mergeOverwrite .context (dict "labels" .labels) -}}
{{- $labels := include "mozcloud-labels-lib.labels" $params | fromYaml -}}
{{- $labels = mergeOverwrite (default dict .labels) $labels -}}
{{ dict "labels" $labels | toYaml }}
{{- end -}}
