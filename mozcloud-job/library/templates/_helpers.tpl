{{/*
Expand the name of the chart.
*/}}
{{- define "mozcloud-job-lib.name" -}}
{{- if .nameOverride -}}
{{- .nameOverride }}
{{- else -}}
mozcloud-job
{{- end -}}
{{- end -}}

{{- /*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "mozcloud-job-lib.fullname" -}}
{{- if .fullnameOverride }}
{{- .fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else -}}
{{- include "mozcloud-job-lib.name" . }}
{{- end -}}
{{- end -}}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "mozcloud-job-lib.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "mozcloud-job-lib.labels" -}}
{{- $labels := include "mozcloud-labels-lib.labels" . | fromYaml -}}
{{- if .labels -}}
  {{- $labels = mergeOverwrite $labels .labels -}}
{{- end }}
{{- $labels | toYaml }}
{{- end }}

{{/*
Template helpers
*/}}
{{- define "mozcloud-job-lib.config.common" -}}
{{- $name_override := default "" .nameOverride -}}
{{- $output := dict -}}
{{- /* Use name helper function to populate name using rules hierarchy */ -}}
{{- $config := .config -}}
{{- if $name_override -}}
  {{- $_ := set $config "nameOverride" $name_override -}}
{{- end -}}
{{- $name := include "mozcloud-job-lib.config.name" $config -}}
{{- $_ := set $output "name" $name -}}
{{- /* Generate labels */ -}}
{{- $label_params := mergeOverwrite .context (dict "labels" .labels) -}}
{{- $labels := include "mozcloud-job-lib.labels" $label_params | fromYaml -}}
{{- $_ = set $output "labels" $labels -}}
{{- /* Return output */ -}}
{{ $output | toYaml }}
{{- end -}}

{{- define "mozcloud-job-lib.config.name" -}}
{{- $name := "" -}}
{{- if .name -}}
  {{- $name = .name -}}
{{- end -}}
{{- if and (.nameOverride) (not $name) -}}
  {{- $name = .nameOverride -}}
{{- end -}}
{{- if not $name -}}
  {{- $name = include "mozcloud-job-lib.fullname" $ -}}
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
CronJob template helpers
*/}}
{{- define "mozcloud-job-lib.config.cronJobs" -}}
{{- $cron_jobs := .cronJobConfig.cronJobs -}}
{{- $name_override := default "" .nameOverride -}}
{{- $output := list -}}
{{- range $cron_job := $cron_jobs -}}
  {{- $cron_job_defaults := include "mozcloud-job-lib.defaults.cronJob.config" . | fromYaml -}}
  {{- $cron_job_config := mergeOverwrite $cron_job_defaults $cron_job -}}
  {{- /* Configure name and labels */ -}}
  {{- $labels := default (dict) $cron_job_config.labels -}}
  {{- $params := dict "config" $cron_job_config "context" ($ | deepCopy) "labels" $labels -}}
  {{- $common := include "mozcloud-job-lib.config.common" $params | fromYaml -}}
  {{- $cron_job_config = mergeOverwrite $cron_job_config $common -}}
  {{- /* Configure job defaults */ -}}
  {{- $job_defaults := include "mozcloud-job-lib.defaults.job.config" . | fromYaml -}}
  {{- $job_config := mergeOverwrite $job_defaults.config (default (dict) $cron_job.jobConfig) -}}
  {{- /* Configure pod securityContext */ -}}
  {{- $pod_security_context_params := dict -}}
  {{- if ($job_config.securityContext).user -}}
    {{- $_ := set $pod_security_context_params "user" $job_config.securityContext.user -}}
  {{- end -}}
  {{- if ($job_config.securityContext).group -}}
    {{- $_ := set $pod_security_context_params "group" $job_config.securityContext.group -}}
  {{- end -}}
  {{- $_ := set $job_config "securityContext" (include "mozcloud-workload-core-lib.pod.securityContext" $pod_security_context_params | fromYaml) -}}
  {{- $_ = set $cron_job_config "jobConfig" $job_config -}}
  {{- /*
  Configure default tag and container settings.
  */ -}}
  {{- $containers := default (list) $cron_job_config.containers -}}
  {{- $container_output := list -}}
  {{- range $container := $containers -}}
    {{- $container_defaults := include "mozcloud-job-lib.defaults.job.container.config" . | fromYaml -}}
    {{- $container_config := mergeOverwrite $container_defaults $container -}}
    {{- $resource_params := $container_config.resources -}}
    {{- $resources := include "mozcloud-workload-core-lib.pod.container.resources" $resource_params | fromYaml -}}
    {{- $_ := set $container_config "resources" $resources -}}
    {{/* Configure container securityContext */ -}}
    {{- $container_security_context_params := dict -}}
    {{- if ($container_config.securityContext).user -}}
      {{- $_ := set $container_security_context_params "user" $container_config.securityContext.user -}}
    {{- end -}}
    {{- if ($container_config.securityContext).group -}}
      {{- $_ := set $container_security_context_params "group" $container_config.securityContext.group -}}
    {{- end -}}
    {{- $_ = set $container_config "securityContext" (include "mozcloud-workload-core-lib.pod.container.securityContext" $container_security_context_params | fromYaml) -}}
    {{- $container_output = append $container_output $container_config -}}
  {{- end -}}
  {{- $_ := set $cron_job_config "containers" $container_output -}}
  {{- $output = append $output $cron_job_config -}}
{{- end -}}
{{- $cron_jobs = dict "cronJobs" $output -}}
{{ $cron_jobs | toYaml }}
{{- end -}}

{{/*
Job template helpers
*/}}
{{- define "mozcloud-job-lib.config.jobs" -}}
{{- $jobs := .jobConfig.jobs -}}
{{- $name_override := default "" .nameOverride -}}
{{- $output := list -}}
{{- range $job := $jobs -}}
  {{- $defaults := include "mozcloud-job-lib.defaults.job.config" . | fromYaml -}}
  {{- $job_config := mergeOverwrite $defaults $job -}}
  {{- /* Configure name and labels */ -}}
  {{- $labels := default (dict) $job_config.labels -}}
  {{- $params := dict "config" $job_config "context" ($ | deepCopy) "labels" $labels -}}
  {{- $common := include "mozcloud-job-lib.config.common" $params | fromYaml -}}
  {{- $job_config = mergeOverwrite $job_config $common -}}
  {{- /* Configure pod securityContext */ -}}
  {{- $pod_security_context_params := dict -}}
  {{- if ($job_config.config.securityContext).user -}}
    {{- $_ := set $pod_security_context_params "user" $job_config.config.securityContext.user -}}
  {{- end -}}
  {{- if ($job_config.config.securityContext).group -}}
    {{- $_ := set $pod_security_context_params "group" $job_config.config.securityContext.group -}}
  {{- end -}}
  {{- $_ := set $job_config.config "securityContext" (include "mozcloud-workload-core-lib.pod.securityContext" $pod_security_context_params | fromYaml) -}}
  {{- /*
  Configure default tag and container settings.
  */ -}}
  {{- $containers := default (list) $job_config.containers -}}
  {{- $container_output := list -}}
  {{- range $container := $containers -}}
    {{- $container_defaults := include "mozcloud-job-lib.defaults.job.container.config" . | fromYaml -}}
    {{- $container_config := mergeOverwrite $container_defaults $container -}}
    {{- $resource_params := $container_config.resources -}}
    {{- $resources := include "mozcloud-workload-core-lib.pod.container.resources" $resource_params | fromYaml -}}
    {{- $_ := set $container_config "resources" $resources -}}
    {{/* Configure container securityContext */ -}}
    {{- $container_security_context_params := dict -}}
    {{- if ($container_config.securityContext).user -}}
      {{- $_ := set $container_security_context_params "user" $container_config.securityContext.user -}}
    {{- end -}}
    {{- if ($container_config.securityContext).group -}}
      {{- $_ := set $container_security_context_params "group" $container_config.securityContext.group -}}
    {{- end -}}
    {{- $_ = set $container_config "securityContext" (include "mozcloud-workload-core-lib.pod.container.securityContext" $container_security_context_params | fromYaml) -}}
    {{- $container_output = append $container_output $container_config -}}
  {{- end -}}
  {{- $_ := set $job_config "containers" $container_output -}}
  {{- /*
  Configure Argo CD annotations for the job and serviceAccount, if applicable.
  Job annotations should always be determined before service account annotations
  as the service account annotations will potentially reference a job
  annotation.
  */ -}}
  {{- $annotations := dict -}}
  {{- $argo := ($job_config.argo) -}}
  {{- /* Start with job annotations */ -}}
  {{- if or $argo.hookDeletionPolicy $argo.hooks $argo.syncWave -}}
    {{- $annotations = (include "mozcloud-job-lib.config.jobs.annotations" (dict "type" "job" "jobConfig" $job_config) | fromYaml) -}}
    {{- if gt (len $annotations) 0 -}}
      {{- $_ := set $job_config "annotations" $annotations -}}
    {{- end -}}
  {{- end -}}
  {{- /* Then do service account annotations */ -}}
  {{- $annotations = (include "mozcloud-job-lib.config.jobs.annotations" (dict "type" "serviceAccount" "jobConfig" $job_config) | fromYaml) -}}
  {{- $_ = set $job_config.config.serviceAccount "annotations" $annotations -}}
  {{- $output = append $output $job_config -}}
{{- end -}}
{{- $jobs = dict "jobs" $output -}}
{{ $jobs | toYaml }}
{{- end -}}

{{- define "mozcloud-job-lib.config.jobs.annotations" -}}
{{- $job_config := .jobConfig -}}
{{- $argo := ($job_config.argo) -}}
{{- if eq .type "job" -}}
  {{- if $argo.hooks }}
argocd.argoproj.io/hook: {{ $argo.hooks }}
  {{- else if and $argo.hookDeletionPolicy $argo.syncWave }}
argocd.argoproj.io/hook: Sync
  {{- end -}}
  {{- if $argo.hookDeletionPolicy }}
argocd.argoproj.io/hook-delete-policy: {{ $argo.hookDeletionPolicy }}
  {{- end -}}
  {{- if $argo.syncWave }}
argocd.argoproj.io/sync-wave: {{ $argo.syncWave | quote }}
  {{- end -}}
{{- else if eq .type "serviceAccount" -}}
  {{- if $argo.hooks }}
argocd.argoproj.io/hook: {{ $argo.hooks }}
  {{- else if (index $job_config.annotations "argocd.argoproj.io/hook") }}
argocd.argoproj.io/hook: {{ index $job_config.annotations "argocd.argoproj.io/hook" }}
  {{- end -}}
  {{- /*
  The service account should always be created before the job so the job does
  not fail. We will assign the service account sync wave a value of
  (job_sync_wave_value - 1) with a default value of -1.
  */ -}}
  {{- $sync_wave := -1 -}}
  {{- if $argo.syncWave -}}
    {{- $sync_wave = sub (int $argo.syncWave) 1 -}}
  {{- end }}
argocd.argoproj.io/sync-wave: {{ $sync_wave | quote }}
{{- end -}}
{{- end -}}

{{/*
Defaults
*/}}
{{- define "mozcloud-job-lib.defaults.cronJob.config" -}}
config:
  jobHistory:
    successful: 1
    failed: 1
{{- end -}}

{{- define "mozcloud-job-lib.defaults.job.config" -}}
argo:
  hookDeletionPolicy: BeforeHookCreation,HookSucceeded
config:
  backoffLimit: 6
  parallelism: 1
  restartPolicy: Never
  serviceAccount:
    create: false
generateName: false
{{- end -}}

{{- define "mozcloud-job-lib.defaults.job.container.config" -}}
resources:
  requests:
    cpu: 10m
    memory: 64Mi
tag: latest
{{- end -}}

{{/*
Debug helper
*/}}
{{- define "mozcloud-job-lib.debug" -}}
{{- . | mustToPrettyJson | printf "\nThe JSON output of the dumped var is: \n%s" | fail }}
{{- end -}}
