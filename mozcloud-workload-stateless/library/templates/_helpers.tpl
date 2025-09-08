{{/*
PodMonitoring template helpers
*/}}
{{- define "mozcloud-workload-stateless-lib.config.podMonitorings" -}}
{{- $pod_monitorings := .podMonitorings -}}
{{- $labels := default (dict) .labels -}}
{{- $name_override := default "" .nameOverride -}}
{{- $output := list -}}
{{- range $pod_monitoring := $pod_monitorings -}}
  {{- $pod_monitoring_config := $pod_monitoring | deepCopy -}}
  {{- /* Configure name and labels */ -}}
  {{- $params := dict "config" $pod_monitoring_config "context" ($ | deepCopy) "labels" $labels -}}
  {{- $common := include "mozcloud-workload-core-lib.config.common" $params | fromYaml -}}
  {{- $pod_monitoring_config = mergeOverwrite $pod_monitoring_config $common -}}
  {{- $output = append $output $pod_monitoring_config -}}
{{- end -}}
{{- $pod_monitorings = dict "podMonitorings" $output -}}
{{ $pod_monitorings | toYaml }}
{{- end -}}

{{/*
HPA template helpers
*/}}
{{- define "mozcloud-workload-stateless-lib.config.hpas" -}}
{{- $hpas := .hpas -}}
{{- $labels := default (dict) .labels -}}
{{- $name_override := default "" .nameOverride -}}
{{- $output := list -}}
{{- range $hpa := $hpas -}}
  {{- $hpa_config := $hpa | deepCopy -}}
  {{- /* Configure name and labels */ -}}
  {{- $params := dict "config" $hpa_config "context" ($ | deepCopy) "labels" $labels -}}
  {{- $common := include "mozcloud-workload-core-lib.config.common" $params | fromYaml -}}
  {{- $hpa_config = mergeOverwrite $hpa_config $common -}}
  {{- $output = append $output $hpa_config -}}
{{- end -}}
{{- $hpas = dict "hpas" $output -}}
{{ $hpas | toYaml }}
{{- end -}}

{{/*
Deployment template helpers
*/}}
{{- define "mozcloud-workload-stateless-lib.config.deployments" -}}
{{- $deployments := .deployments -}}
{{- $labels := default (dict) .labels -}}
{{- $name_override := default "" .nameOverride -}}
{{- $output := list -}}
{{- range $deployment := $deployments -}}
  {{- $deployment_config := $deployment | deepCopy -}}
  {{- /* Configure name and labels */ -}}
  {{- $params := dict "config" $deployment_config "context" ($ | deepCopy) "labels" $labels -}}
  {{- $common := include "mozcloud-workload-core-lib.config.common" $params | fromYaml -}}
  {{- $deployment_config = mergeOverwrite $deployment_config $common -}}
  {{- $output = append $output $deployment_config -}}
{{- end -}}
{{- $deployments = dict "deployments" $output -}}
{{ $deployments | toYaml }}
{{- end -}}
