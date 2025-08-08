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
{{- $requests := .requests -}}
{{- $limits := default (dict) .limits -}}
{{- $resources := dict "requests" .requests "limits" $limits -}}
{{- /* Validate CPU requests and limits */ -}}
{{- $request_suffix := "" -}}
{{- $request := $requests.cpu | toString -}}
{{- /*
CPU resources can only be integers/floats for an entire CPU or millicpu (m)
*/ -}}
{{- if hasSuffix "m" $request -}}
  {{- $request_suffix = "m" }}
  {{- $request = trimSuffix "m" $request -}}
{{- end -}}
{{- if and (not $request_suffix) (or (regexFind "[a-zA-Z]$" $request) (le (float64 $request) 0.0)) -}}
  {{- fail (printf "CPU requests must be positive and use one of the following formats: int, float, or millicpu notation (eg. 100m)") -}}
{{- end -}}
{{- if $limits.cpu -}}
  {{- $limit_suffix := "" -}}
  {{- $limit := $limits.cpu | toString -}}
  {{- /*
  CPU resources can only be integers/floats for an entire CPU or millicpu (m)
  */ -}}
  {{- if hasSuffix "m" $limit -}}
    {{- $limit_suffix = "m" }}
    {{- $limit = trimSuffix "m" $limit -}}
  {{- end -}}
  {{- if and (not $limit_suffix) (or (regexFind "[a-zA-Z]$" $limit) (le (float64 $limit) 0.0)) -}}
    {{- fail (printf "CPU limits must be positive and use one of the following formats: int, float, or millicpu notation (eg. 100m)") -}}
  {{- end -}}
  {{- if or $limit_suffix (eq (float64 $limit) (floor (float64 $limit))) -}}
    {{- /*
    Using "ceil" function here to round up any limits using millicpu
    notations with decimals. For example, "1.5m" becomes "2m".
    */ -}}
    {{- $limit = ceil (float64 $limit) -}}
    {{- $_ := set $resources.limits "cpu" (printf "%d%s" (int $limit) $limit_suffix) -}}
  {{- end -}}
{{- end -}}
{{- /* Configure CPU limits, if not set */}}
{{- if not $limits.cpu -}}
  {{- $limit := "" -}}
  {{- /* Keep ints as ints to create cleaner output */ -}}
  {{- if or $request_suffix (eq (float64 $request) (floor (float64 $request))) -}}
    {{- /*
    Using "ceil" function here to round up any requests using millicpu
    notations with decimals. For example, "1.5m" becomes "2m".
    */ -}}
    {{- $request = ceil (float64 $request) -}}
    {{- $_ := set $resources.requests "cpu" (printf "%d%s" (int $request) $request_suffix) -}}
    {{- $limit = printf "%d%s" (mul 2 (int $request)) $request_suffix -}}
  {{- else -}}
    {{- $limit = printf "%.3f" (mulf 2 (float64 $request)) -}}
  {{- end -}}
  {{- $_ := set $resources.limits "cpu" $limit -}}
{{- end -}}
{{- /* Validate memory requests and limits */ -}}
{{- $request_suffix = "" -}}
{{- /* Only allow the following unit types: K, Ki, M, Mi, G, Gi */ -}}
{{- $memory_suffixes := list "K" "Ki" "M" "Mi" "G" "Gi" -}}
{{- $request = $requests.memory | toString -}}
{{- range $memory_suffix := $memory_suffixes -}}
  {{- if hasSuffix $memory_suffix $request -}}
    {{- $request_suffix = $memory_suffix }}
    {{- $request = trimSuffix $request_suffix $request -}}
  {{- end -}}
{{- end -}}
{{- if or (not $request_suffix) (le (float64 $request) 0.0) -}}
  {{- fail (printf "Memory requests must be positive and use one of the following unit types: %s" (join ", " $memory_suffixes)) -}}
{{- end -}}
{{- if $limits.memory -}}
  {{- $limit_suffix := "" -}}
  {{- $limit := $limits.memory | toString -}}
  {{- range $memory_suffix := $memory_suffixes -}}
    {{- if hasSuffix $memory_suffix $limit -}}
      {{- $limit_suffix = $memory_suffix }}
      {{- $limit = trimSuffix $limit_suffix $limit -}}
    {{- end -}}
  {{- end -}}
  {{- if or (not $limit_suffix) (le (float64 $limit) 0.0) -}}
    {{- fail (printf "Memory limits must be positive and use one of the following unit types: %s" (join ", " $memory_suffixes)) -}}
  {{- end -}}
{{- end -}}
{{- /* Configure memory limits, if not set */ -}}
{{- if not $limits.memory -}}
  {{- $limit := "" -}}
  {{- /* Keep ints as ints to create cleaner output */ -}}
  {{- if eq (float64 $request) (floor (float64 $request)) -}}
    {{- $limit = printf "%d%s" (mul 2 (int $request)) $request_suffix -}}
  {{- else -}}
    {{- $limit = printf "%.3f%s" (mulf 2 (float64 $request)) $request_suffix -}}
  {{- end -}}
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
