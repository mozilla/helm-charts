{{/*
Expand the name of the chart.
*/}}
{{- define "mozcloud-workload-core-lib.name" -}}
{{- if .nameOverride -}}
{{- .nameOverride }}
{{- else -}}
mozcloud-workload-core
{{- end -}}
{{- end -}}

{{- /*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "mozcloud-workload-core-lib.fullname" -}}
{{- if .fullnameOverride }}
{{- .fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else -}}
{{- include "mozcloud-workload-core-lib.name" . }}
{{- end -}}
{{- end -}}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "mozcloud-workload-core-lib.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "mozcloud-workload-core-lib.labels" -}}
{{- $labels := include "mozcloud-labels-lib.labels" . | fromYaml -}}
{{- if .labels -}}
  {{- $labels = mergeOverwrite $labels .labels -}}
{{- end }}
{{- $labels | toYaml }}
{{- end }}

{{- define "mozcloud-workload-core-lib.selectorLabels" -}}
{{- $selector_labels := include "mozcloud-labels-lib.selectorLabels" . | fromYaml -}}
{{- if .labels -}}
  {{- $selector_labels = mergeOverwrite $selector_labels .labels -}}
{{- end }}
{{- $selector_labels | toYaml }}
{{- end }}

{{/*
Template helpers
*/}}
{{- define "mozcloud-workload-core-lib.config.annotations" -}}
{{- $params := dict "annotations" .annotations "type" .type -}}
{{- $annotations := include "mozcloud-labels-lib.annotations" (mergeOverwrite .context $params) }}
{{- $annotations }}
{{- end -}}

{{- define "mozcloud-workload-core-lib.config.annotations.otel.autoInjection" -}}
instrumentation.opentelemetry.io/inject-{{ .language }}: "true"
instrumentation.opentelemetry.io/container-names: {{ join "," .containers | quote }}
{{- end -}}

{{- define "mozcloud-workload-core-lib.config.common" -}}
{{- $output := dict -}}
{{- /* Generate labels */ -}}
{{- $label_params := mergeOverwrite .context (dict "labels" .labels) -}}
{{- $labels := include "mozcloud-workload-core-lib.labels" $label_params | fromYaml -}}
{{- $_ := set $output "labels" $labels -}}
{{- /* Generate selector labels */ -}}
{{- $selector_labels := include "mozcloud-workload-core-lib.selectorLabels" $label_params | fromYaml -}}
{{- $_ = set $output "selectorLabels" $selector_labels -}}
{{- /* Return output */ -}}
{{ $output | toYaml }}
{{- end -}}

{{- define "mozcloud-workload-core-lib.config.name" -}}
{{- $name := "" -}}
{{- if .name -}}
  {{- $name = .name -}}
{{- end -}}
{{- if and (.nameOverride) (not $name) -}}
  {{- $name = .nameOverride -}}
{{- end -}}
{{- if not $name -}}
  {{- $name = include "mozcloud-workload-core-lib.fullname" $ -}}
{{- end -}}
{{- if .prefix -}}
  {{- $name = printf "%s-%s" .prefix $name -}}
{{- end -}}
{{- if .suffixes -}}
  {{- $suffix := join "-" .suffixes -}}
  {{- $length := $suffix | len | add1 -}}
  {{- $name = printf "%s-%s" ($name | trunc (sub 63 $length | int)) $suffix -}}
{{- end -}}
{{ $name | trunc 63 | trimSuffix "-" }}
{{- end -}}

{{/*
ConfigMap template helpers
*/}}
{{- define "mozcloud-workload-core-lib.config.configMaps" -}}
{{- $config_maps := .configMaps -}}
{{- $name_override := default "" .nameOverride -}}
{{- $output := list -}}
{{- range $config_map := $config_maps -}}
  {{- $config_map_config := $config_map | deepCopy -}}
  {{- /* Configure name and labels */ -}}
  {{- $labels := default (dict) $config_map_config.labels -}}
  {{- $params := dict "config" $config_map_config "context" ($ | deepCopy) "labels" $labels -}}
  {{- $common := include "mozcloud-workload-core-lib.config.common" $params | fromYaml -}}
  {{- $config_map_config = mergeOverwrite $config_map_config $common -}}
  {{- /* Create configMaps[].data if it does not exist */ -}}
  {{- $config_map_data := default (dict) $config_map_config.data -}}
  {{- $_ := set $config_map_config "data" $config_map_data -}}
  {{- $output = append $output $config_map_config -}}
{{- end -}}
{{- $config_maps = dict "configMaps" $output -}}
{{ $config_maps | toYaml }}
{{- end -}}

{{/*
PersistentVolumeClaim template helpers
*/}}
{{- define "mozcloud-workload-core-lib.config.persistentVolumes" -}}
{{- $persistent_volume_claims := .persistentVolumes -}}
{{- $name_override := default "" .nameOverride -}}
{{- $output := list -}}
{{- range $name, $pvc := $persistent_volume_claims -}}
  {{- $pvc_config := $pvc | deepCopy -}}
  {{- /* Configure name and labels */ -}}
  {{- $labels := default (dict) $pvc_config.labels -}}
  {{- $params := dict "config" $pvc_config "context" ($ | deepCopy) "labels" $labels -}}
  {{- $common := include "mozcloud-workload-core-lib.config.common" $params | fromYaml -}}
  {{- $pvc_config = mergeOverwrite $pvc_config $common -}}
  {{- if $name_override }}
    {{- $name = $name_override }}
  {{- end }}
  {{- $_ := set $pvc_config "name" $name }}
  {{- $output = append $output $pvc_config -}}
{{- end -}}
{{- $persistent_volume_claims = dict "persistentVolumes" $output -}}
{{ $persistent_volume_claims | toYaml }}
{{- end -}}


{{/*
ExternalSecret template helpers
*/}}
{{- define "mozcloud-workload-core-lib.config.externalSecrets" -}}
{{- $app_code := default "" .app_code -}}
{{- $environment := default "" .env_code -}}
{{- $external_secrets := .externalSecrets -}}
{{- $name_override := default "" .nameOverride -}}
{{- $output := list -}}
{{- range $external_secret := $external_secrets -}}
  {{- $defaults := include "mozcloud-workload-core-lib.defaults.externalSecret.config" $ | fromYaml -}}
  {{- $external_secret_config := mergeOverwrite $defaults $external_secret -}}
  {{- /* Configure name and labels */ -}}
  {{- $labels := default (dict) $external_secret_config.labels -}}
  {{- $params := dict "config" $external_secret_config "context" ($ | deepCopy) "labels" $labels -}}
  {{- $common := include "mozcloud-workload-core-lib.config.common" $params | fromYaml -}}
  {{- $external_secret_config = mergeOverwrite $external_secret_config $common -}}
  {{- /* Populate ExternalSecret-specific fields, if not specified */ -}}
  {{- if and (not $external_secret.target) $app_code -}}
    {{- /* Prefer to construct the target name using .app_code if specified, otherwise use default */ -}}
    {{- $target_name := printf "%s-secrets" $app_code -}}
    {{- $_ := set $external_secret_config "target" $target_name -}}
  {{- end -}}
  {{- if and (not ($external_secret.gsm).secret) $environment -}}
    {{- /* Prefer to construct the GSM secret name using .environment if specified, otherwise use default */ -}}
    {{- $gsm_secret := printf "%s-gke-app-secrets" $environment -}}
    {{- $_ := set $external_secret_config.gsm "secret" $gsm_secret -}}
  {{- end -}}
  {{- $output = append $output $external_secret_config -}}
{{- end -}}
{{- $external_secrets = dict "externalSecrets" $output -}}
{{ $external_secrets | toYaml }}
{{- end -}}

{{/*
ServiceAccount template helpers
*/}}
{{- define "mozcloud-workload-core-lib.config.serviceAccount.gcpServiceAccount" -}}
{{- $output := "" -}}
{{- if .fullName -}}
  {{- $output = .fullName -}}
{{- else if and .name .projectId -}}
  {{- $output = printf "%s@%s.iam.gserviceaccount.com" .name .projectId -}}
{{- end -}}
{{ $output }}
{{- end -}}

{{- define "mozcloud-workload-core-lib.config.serviceAccounts" -}}
{{- $name_override := default "" .nameOverride -}}
{{- $service_accounts := .serviceAccounts -}}
{{- $output := list -}}
{{- range $service_account := $service_accounts -}}
  {{- $defaults := include "mozcloud-workload-core-lib.defaults.serviceAccount.config" $ | fromYaml -}}
  {{- $service_account_config := mergeOverwrite $defaults $service_account -}}
  {{- /* Configure name and labels */ -}}
  {{- $labels := default (dict) $service_account_config.labels -}}
  {{- $params := dict "config" $service_account_config "context" ($ | deepCopy) "labels" $labels -}}
  {{- $common := include "mozcloud-workload-core-lib.config.common" $params | fromYaml -}}
  {{- $service_account_config = mergeOverwrite $service_account_config $common -}}
  {{- /* Generate gcpServiceAccount, if applicable */ -}}
  {{- if $service_account_config.gcpServiceAccount -}}
    {{- if and (not $service_account_config.gcpServiceAccount.projectId) $.project_id -}}
      {{- $_ := set $service_account_config.gcpServiceAccount "projectId" $.project_id -}}
    {{- end -}}
    {{- $gcp_service_account := include "mozcloud-workload-core-lib.config.serviceAccount.gcpServiceAccount" $service_account_config.gcpServiceAccount -}}
    {{- /* Only set if either .fullName is specified or .name and .projectId are both specified */ -}}
    {{- if $gcp_service_account -}}
      {{- $_ := set $service_account_config "gcpServiceAccount" $gcp_service_account -}}
    {{- end -}}
  {{- end -}}
  {{- $output = append $output $service_account_config -}}
{{- end -}}
{{- $service_accounts = dict "serviceAccounts" $output -}}
{{ $service_accounts | toYaml }}
{{- end -}}

{{/*
Defaults
*/}}
{{- define "mozcloud-workload-core-lib.defaults.externalSecret.config" -}}
name: {{ include "mozcloud-workload-core-lib.config.name" . }}
refreshInterval: 5m
target: {{ include "mozcloud-workload-core-lib.config.name" . }}-secrets
gsm:
  secret: dev-gke-app-secrets
  version: latest
{{- end -}}

{{- define "mozcloud-workload-core-lib.defaults.serviceAccount.config" -}}
name: {{ include "mozcloud-workload-core-lib.config.name" . }}
{{- end -}}

{{/*
Debug helper
*/}}
{{- define "mozcloud-workload-core-lib.debug" -}}
{{- . | mustToPrettyJson | printf "\nThe JSON output of the dumped var is: \n%s" | fail }}
{{- end -}}
