{{/*
Deployment template helpers
*/}}
{{- define "mozcloud-deployment-lib.config.deployments" -}}
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
