{{/*
Template helpers
*/}}
{{- define "common.config.name" -}}
{{- $name := "" -}}
{{- if .name -}}
  {{- $name = .name -}}
{{- end -}}
{{- if and (.nameOverride) (not $name) -}}
  {{- $name = .nameOverride -}}
{{- end -}}
{{- if not $name -}}
  {{- $name = include "mozcloud.fullname" $ -}}
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
{{- define "common.config.configMaps" -}}
{{- $config_maps := .configMaps -}}
{{- $name_override := default "" .nameOverride -}}
{{- $output := list -}}
{{- range $name, $config := $config_maps -}}
  {{- $config_map_config := $config | deepCopy -}}
  {{- /* Configure name and labels */ -}}
  {{- $_ := set $config_map_config "name" $name }}
  {{- $labels := default (dict) $config_map_config.labels -}}
  {{- $params := dict "config" $config_map_config "context" ($ | deepCopy) "labels" $labels -}}
  {{- $labels = include "common.labels" $params | fromYaml -}}
  {{- $config_map_config = mergeOverwrite $config_map_config $labels -}}
  {{- /* Create configMaps[].data if it does not exist */ -}}
  {{- $config_map_data := default (dict) $config_map_config.data -}}
  {{- $_ = set $config_map_config "data" $config_map_data -}}
  {{- $output = append $output $config_map_config -}}
{{- end -}}
{{- $config_maps = dict "configMaps" $output -}}
{{ $config_maps | toYaml }}
{{- end -}}

{{/*
PersistentVolumeClaim template helpers
*/}}
{{- define "common.config.persistentVolumes" -}}
{{- $persistent_volume_claims := .persistentVolumes -}}
{{- $name_override := default "" .nameOverride -}}
{{- $output := list -}}
{{- range $name, $pvc := $persistent_volume_claims -}}
  {{- $pvc_config := $pvc | deepCopy -}}
  {{- /* Configure name and labels */ -}}
  {{- $labels := default (dict) $pvc_config.labels -}}
  {{- $params := dict "config" $pvc_config "context" ($ | deepCopy) "labels" $labels -}}
  {{- $labels = include "common.labels" $params | fromYaml -}}
  {{- $pvc_config = mergeOverwrite $pvc_config $labels -}}
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
{{- define "common.config.externalSecrets" -}}
{{- $app_code := default "" .app_code -}}
{{- $environment := default "" .env_code -}}
{{- $external_secrets := .externalSecrets -}}
{{- $name_override := default "" .nameOverride -}}
{{- $output := list -}}
{{- range $external_secret := $external_secrets -}}
  {{- $defaults := include "common.defaults.externalSecret.config" $ | fromYaml -}}
  {{- $external_secret_config := mergeOverwrite $defaults $external_secret -}}
  {{- /* Configure name and labels */ -}}
  {{- $labels := default (dict) $external_secret_config.labels -}}
  {{- $params := dict "config" $external_secret_config "context" ($ | deepCopy) "labels" $labels -}}
  {{- $labels = include "common.labels" $params | fromYaml -}}
  {{- $external_secret_config = mergeOverwrite $external_secret_config $labels -}}
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
{{- define "common.config.serviceAccount.gcpServiceAccount" -}}
{{- $output := "" -}}
{{- if .fullName -}}
  {{- $output = .fullName -}}
{{- else if and .name .projectId -}}
  {{- $output = printf "%s@%s.iam.gserviceaccount.com" .name .projectId -}}
{{- end -}}
{{ $output }}
{{- end -}}

{{- define "common.config.serviceAccounts" -}}
{{- $name_override := default "" .nameOverride -}}
{{- $service_accounts := .serviceAccounts -}}
{{- $output := list -}}
{{- range $name, $config := $service_accounts -}}
  {{- $defaults := include "common.defaults.serviceAccount.config" $ | fromYaml -}}
  {{- $service_account_config := mergeOverwrite (deepCopy $defaults) $config -}}
  {{- $_ := set $service_account_config "name" $name -}}
  {{- /* Configure name and labels */ -}}
  {{- $labels := default (dict) $service_account_config.labels -}}
  {{- $params := dict "config" $service_account_config "context" (deepCopy $) "labels" $labels -}}
  {{- $labels = include "common.labels" $params | fromYaml -}}
  {{- $service_account_config = mergeOverwrite $service_account_config $labels -}}
  {{- /* Generate gcpServiceAccount, if applicable */ -}}
  {{- if $service_account_config.gcpServiceAccount -}}
    {{- if and (not $service_account_config.gcpServiceAccount.projectId) $.project_id -}}
      {{- $_ := set $service_account_config.gcpServiceAccount "projectId" $.project_id -}}
    {{- end -}}
    {{- $gcp_service_account := include "common.config.serviceAccount.gcpServiceAccount" $service_account_config.gcpServiceAccount -}}
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
{{- define "common.defaults.externalSecret.config" -}}
name: {{ include "common.config.name" . }}
refreshInterval: 5m
target: {{ include "common.config.name" . }}-secrets
gsm:
  secret: dev-gke-app-secrets
  version: latest
{{- end -}}

{{- define "common.defaults.serviceAccount.config" -}}
name: {{ include "common.config.name" . }}
{{- end -}}

{{- /*
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
EVERYTHING BELOW WAS ADDED DURING THE REFACTOR
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
*/ -}}

{{- /*
Populates Argo CD and OTEL Collector annotations as applicable by calling
downstream helper functions.

Params:

annotations (dict): (optional) User-provided annotations.
context (dict): (required) The root context from the template calling this function.
otel (dict): (optional) OTEL config, if applicable.
type (string): (required) The type of resource in question. Options are: deployment, job.
*/ -}}
{{- define "common.annotations" -}}
{{- $annotations := default (dict) .annotations -}}
{{- $context := .context -}}
{{- $otel := default (dict) .otel -}}
{{- $type := .type -}}
{{- $params := dict "annotations" $annotations "type" $type "otel" $otel -}}
{{- if $otel -}}
  {{- $params = dict "config" $otel "context" $context "type" $type -}}
  {{- $otelAnnotations := include "common.annotations.otel" $params | fromYaml -}}
  {{- $annotations = mergeOverwrite $annotations $otelAnnotations -}}
{{- end -}}
{{- $annotations | toYaml }}
{{- end -}}


{{- /*
Provides Argo CD annotations. Defaults are pulled from a downstream helper
function.

Params:

syncWave (string): (optional) User-provided sync wave value, if applicable.
type (string): (required) The type of resource being handled -- used for defaults.
*/ -}}
{{- define "common.annotations.argo" -}}
{{- $type := .type -}}
{{- $syncWaveDefault := index (include "common.annotations.argo.syncWaveDefaults" . | fromYaml) $type -}}
{{- if has $type (list "jobPostDeployment" "jobPreDeployment") }}
argocd.argoproj.io/hook: Sync
argocd.argoproj.io/hook-delete-policy: BeforeHookCreation,HookSucceeded
{{- end }}
{{- /* Deployments do not have sync wave values */}}
{{- if ne $type "deployment" }}
argocd.argoproj.io/sync-wave: {{ default $syncWaveDefault .syncWave | quote }}
{{- end }}
{{- end -}}


{{- /*
Default sync wave values.
*/ -}}
{{- define "common.annotations.argo.syncWaveDefaults" -}}
configMap: -11
externalSecret: -11
jobPostDeployment: 1
jobPreDeployment: -1
serviceAccount: -11
{{- end -}}


{{- /*
Checks OTEL config to see if it is enabled and, if so, calls a downstream
helper function to populate resource annotations. Additionally, checks if auto
instrumentation is enabled and, if so, calls a downstream helper function to
populate auto injection annotations.

Params:

config (dict): (required) The OTEL config from values.yaml.
context (dict): (required) The root context from the template calling this function.
type (string): (required) The type of resource for auto instrumentation. Options are: deployment, job.
*/ -}}
{{- define "common.annotations.otel" -}}
{{- $config := .config -}}
{{- $context := deepCopy .context -}}
{{- /* These are used for deployments and jobs */ -}}
{{- $type := .type -}}
{{- /* This checks if OTEL is enabled, relying on defaults (deployment: true, job: false) if not specified */ -}}
{{- $enabled := dig "enabled" (ternary true false (eq $type "deployment")) $config -}}
{{- if $enabled -}}
  {{- $labels := include "mozcloud-labels-lib.labels" $context | fromYaml -}}
  {{- /* Resource annotations use values from labels */ -}}
{{- /* The next line will include actual YAML */ -}}
{{ include "common.annotations.otel.resources" (dict "labels" $labels) }}
  {{- /* Auto instrumentation */}}
  {{- $autoInstrumentationAnnotations := dict }}
  {{- $containers := default (list) $config.containers }}
  {{- $autoInstrumentationEnabled := and $containers (dig "autoInstrumentation" "enabled" false $config) ($config.autoInstrumentation).language }}
  {{- if $autoInstrumentationEnabled }}
    {{- $params := dict "containers" $containers "language" $config.autoInstrumentation.language }}
{{- /* The next line will include actual YAML */}}
{{ include "common.annotations.otel.autoInstrumentation" $params }}
  {{- end -}}
{{- end -}}
{{- end -}}


{{- /*
Returns OTEL-specific auto injection annotations.

Params:

containers (list): (required) A list of containers to annotate.
language (string): (required) The language to use for auto injection annotations.
*/ -}}
{{- define "common.annotations.otel.autoInstrumentation" -}}
instrumentation.opentelemetry.io/inject-{{ .language }}: "mozcloud-opentelemetry/mozcloud-opentelemetry-instrumentation"
instrumentation.opentelemetry.io/{{ .language }}-container-names: {{ join "," .containers | quote }}
{{- end -}}


{{- /*
Returns OTEL-specific resource annotations.

Params:

labels (dict): (required) The labels we need.
*/ -}}
{{- define "common.annotations.otel.resources" -}}
{{- $labels := .labels }}
resource.opentelemetry.io/app_code: {{ $labels.app_code }}
resource.opentelemetry.io/component_code: {{ $labels.component_code }}
resource.opentelemetry.io/env_code: {{ $labels.env_code }}
resource.opentelemetry.io/realm: {{ $labels.realm }}
{{- end -}}


{{- /*
This function will attempt to merge user-defined containers with the default
container configuration found in either of the following locations:

  - .Values.tasks.jobs.mozcloud-job.containers.mozcloud-container
  - .Values.workloads.mozcloud-workload.containers.mozcloud-container

Params:

containers (dict): (required) Configurations for all containers in question.
type (string): (required) Either "containers" or "init-containers", depending on the type of container.
*/ -}}
{{- define "common.formatter.containers" -}}
{{- $container_values := .containers -}}
{{- $containers := .containers -}}
{{- $default_key := ternary "mozcloud-init-container" "mozcloud-container" (eq .type "init-containers") -}}
{{- /* Remove default containers key and merge with user-defined keys, if defined */ -}}
{{- if or
  (and (eq (keys $container_values | len) 1) (eq (keys $container_values | first) $default_key))
  (gt (keys $container_values | len) 1)
}}
  {{- $containers = omit $containers $default_key -}}
  {{- range $name, $config := $containers -}}
    {{- $defaults := index $container_values $default_key -}}
    {{- $_ := set $containers $name (mergeOverwrite ($defaults | deepCopy) $config) -}}
  {{- end -}}
{{- end -}}
{{ $containers | toYaml }}
{{- end -}}


{{- /*
Pulls labels from mozcloud-labels-lib library chart and supplies them to
downstream templates.

Params:

context (dict): (required) The root context from the template calling this function.
labels (dict): (optional) User-provided labels. These will always be overridden by MozCloud labels.
*/ -}}
{{- define "common.labels" -}}
{{- $output := dict -}}
{{- /* Generate labels */ -}}
{{- $params := mergeOverwrite .context (dict "labels" .labels) -}}
{{- $labels := include "mozcloud-labels-lib.labels" $params | fromYaml -}}
{{- $labels = mergeOverwrite (default (dict) .labels) $labels -}}
{{- $_ := set $output "labels" $labels -}}
{{- /* Generate selector labels */ -}}
{{- $selectorLabels := include "mozcloud-labels-lib.selectorLabels" $params | fromYaml -}}
{{- $_ = set $output "selectorLabels" $selectorLabels -}}
{{- /* Return output */ -}}
{{ $output | toYaml }}
{{- end -}}
