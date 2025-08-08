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
Selector labels
*/}}
{{- define "mozcloud-job-lib.selectorLabels" -}}
{{- $selector_labels := include "mozcloud-labels-lib.selectorLabels" . | fromYaml -}}
{{- if .selectorLabels -}}
  {{- $selector_labels = mergeOverwrite $selector_labels .selectorLabels -}}
{{- end }}
{{- $selector_labels | toYaml }}
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
  {{- $_ := set $cron_job_config "jobConfig" $job_config -}}
  {{- /*
  Configure default tag and resource limits, if not specified.
  */ -}}
  {{- $containers := default (list) $cron_job_config.containers -}}
  {{- $container_output := list -}}
  {{- range $container := $containers -}}
    {{- $container_defaults := include "mozcloud-job-lib.defaults.job.container.config" . | fromYaml -}}
    {{- $container_config := mergeOverwrite $container_defaults $container -}}
    {{- $resource_params := $container_config.resources -}}
    {{- $resources := include "mozcloud-job-lib.defaults.job.container.resources" $resource_params | fromYaml -}}
    {{- $_ := set $container_config "resources" $resources -}}
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
  {{- /*
  Configure default tag and resource limits, if not specified.
  */ -}}
  {{- $containers := default (list) $job_config.containers -}}
  {{- $container_output := list -}}
  {{- range $container := $containers -}}
    {{- $container_defaults := include "mozcloud-job-lib.defaults.job.container.config" . | fromYaml -}}
    {{- $container_config := mergeOverwrite $container_defaults $container -}}
    {{- $resource_params := $container_config.resources -}}
    {{- $resources := include "mozcloud-job-lib.defaults.job.container.resources" $resource_params | fromYaml -}}
    {{- $_ := set $container_config "resources" $resources -}}
    {{- $container_output = append $container_output $container_config -}}
  {{- end -}}
  {{- $_ := set $job_config "containers" $container_output -}}
  {{- $output = append $output $job_config -}}
{{- end -}}
{{- $jobs = dict "jobs" $output -}}
{{ $jobs | toYaml }}
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
generateName: false
{{- end -}}

{{- define "mozcloud-job-lib.defaults.job.container.config" -}}
resources:
  requests:
    cpu: 10m
    memory: 64Mi
tag: latest
{{- end -}}

{{- define "mozcloud-job-lib.defaults.job.container.resources" -}}
{{- $limits := default (dict) .limits -}}
{{- $resources := dict "requests" .requests "limits" $limits -}}
{{- /* Configure CPU limits, if not set */}}
{{- if not $limits.cpu -}}
  {{- $suffix := "" -}}
  {{- $request := $resources.requests.cpu | toString -}}
  {{- if hasSuffix "m" $request -}}
    {{- $suffix = "m" }}
    {{- $request = trimSuffix "m" $request -}}
  {{- end -}}
  {{- $limit := printf "%f%s" (mulf 2 (float64 $request)) $suffix -}}
  {{- $_ := set $resources.limits "cpu" $limit -}}
{{- end -}}
{{- /* Configure memory limits, if not set */}}
{{- if not $limits.memory -}}
  {{- $suffix := "" -}}
  {{- $request := $resources.requests.memory | toString -}}
  {{- if hasSuffix "Mi" $request -}}
    {{- $suffix = "Mi" }}
    {{- $request = trimSuffix $suffix $request -}}
  {{- else if hasSuffix "Gi" $request -}}
    {{- $suffix = "Gi" }}
    {{- $request = trimSuffix $suffix $request -}}
  {{- end -}}
  {{- $limit := printf "%f%s" (mulf 2 (float64 $request)) $suffix -}}
  {{- $_ := set $resources.limits "memory" $limit -}}
{{- end -}}
{{- /* Return resources */}}
{{ $resources | toYaml }}
{{- end -}}

{{/*
Debug helper
*/}}
{{- define "mozcloud-job-lib.debug" -}}
{{- . | mustToPrettyJson | printf "\nThe JSON output of the dumped var is: \n%s" | fail }}
{{- end -}}
