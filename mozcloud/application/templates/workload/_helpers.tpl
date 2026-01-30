{{/*
PodMonitoring template helpers
*/}}
{{- define "workload.config.podMonitorings" -}}
{{- $pod_monitorings := .podMonitorings -}}
{{- $labels := default (dict) .labels -}}
{{- $name_override := default "" .nameOverride -}}
{{- $output := list -}}
{{- range $name, $pod_monitoring := $pod_monitorings -}}
  {{- $pod_monitoring_config := $pod_monitoring | deepCopy -}}
  {{- /* Configure name and labels */ -}}
  {{- $params := dict "config" $pod_monitoring_config "context" ($ | deepCopy) "labels" $labels -}}
  {{- $common := include "common.config.common" $params | fromYaml -}}
  {{- $pod_monitoring_config = mergeOverwrite $pod_monitoring_config $common -}}
  {{- if $name_override }}
    {{- $name = $name_override }}
  {{- end }}
  {{- $_ := set $pod_monitoring_config "name" $name -}}
  {{- $output = append $output $pod_monitoring_config -}}
{{- end -}}
{{- $pod_monitorings = dict "podMonitorings" $output -}}
{{ $pod_monitorings | toYaml }}
{{- end -}}

{{/*
HPA template helpers
*/}}
{{- define "workload.config.hpas" -}}
{{- $hpas := .hpas -}}
{{- $labels := default (dict) .labels -}}
{{- $name_override := default "" .nameOverride -}}
{{- $output := list -}}
{{- range $name, $hpa := $hpas -}}
  {{- $hpa_config := $hpa | deepCopy -}}
  {{- /* Configure name and labels */ -}}
  {{- $params := dict "config" $hpa_config "context" ($ | deepCopy) "labels" $labels -}}
  {{- $common := include "common.config.common" $params | fromYaml -}}
  {{- $hpa_config = mergeOverwrite $hpa_config $common -}}
  {{- if $name_override }}
    {{- $name = $name_override }}
  {{- end }}
  {{- $_ := set $hpa_config "name" $name -}}
  {{- $output = append $output $hpa_config -}}
{{- end -}}
{{- $hpas = dict "hpas" $output -}}
{{ $hpas | toYaml }}
{{- end -}}

{{/*
Deployment template helpers
*/}}
{{- define "workload.config.deployments" -}}
{{- $deployments := .deployments -}}
{{- $name_override := default "" .nameOverride -}}
{{- $output := list -}}
{{- range $name, $deployment := $deployments -}}
  {{- $deployment_config := $deployment | deepCopy -}}
  {{- /* Configure name and labels */ -}}
  {{- $params := dict "config" $deployment_config "context" ($ | deepCopy) "labels" (default (dict) ($deployment).labels) -}}
  {{- $common := include "common.config.common" $params | fromYaml -}}
  {{- $deployment_config = mergeOverwrite $deployment_config $common -}}
  {{- if $name_override }}
    {{- $name = $name_override }}
  {{- end }}
  {{- $_ := set $deployment_config "name" $name -}}
  {{- /* Configure Argo CD annotations, if applicable */}}
  {{- if gt (keys (default (dict) $deployment_config.argo) | len) 0 }}
    {{- $annotation_params := dict "config" $deployment_config "type" "deployment" }}
    {{- $annotations := include "workload.config.argo.annotations" $annotation_params | fromYaml }}
    {{- $_ = set $deployment_config "annotations" $annotations }}
  {{- end }}
  {{- $output = append $output $deployment_config -}}
{{- end -}}
{{- dict "deployments" $output | toYaml -}}
{{- end -}}

{{/*
Argo CD annotation helper
*/}}
{{- define "workload.config.argo.annotations" -}}
{{- $config := .config -}}
{{- $argo := ($config.argo) -}}
{{- if $argo.hooks }}
argocd.argoproj.io/hook: {{ $argo.hooks }}
{{- else if and $argo.hookDeletionPolicy $argo.syncWave }}
argocd.argoproj.io/hook: Sync
{{- end -}}
{{- if $argo.hookDeletionPolicy }}
argocd.argoproj.io/hook-delete-policy: {{ $argo.hookDeletionPolicy }}
{{- end -}}
{{- $sync_wave_defaults := include "workload.defaults.argo.syncWaves" . | fromYaml -}}
{{- if or $argo.syncWave (index $sync_wave_defaults .type) -}}
argocd.argoproj.io/sync-wave: {{ default (index $sync_wave_defaults .type) $argo.syncWave | quote }}
{{- end -}}
{{- end -}}

{{- define "workload.defaults.argo.syncWaves" -}}
configMap: -2
externalSecret: -2
serviceAccount: -2
{{- end -}}

{{/*
Debug helper
*/}}
{{- define "workload.debug" -}}
{{- . | mustToPrettyJson | printf "\nThe JSON output of the dumped var is: \n%s" | fail }}
{{- end -}}
