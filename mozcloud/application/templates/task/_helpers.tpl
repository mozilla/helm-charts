{{/*
Formatting helpers
*/}}
{{- /*
This function will attempt to merge user-defined cron jobs with the default cron
job configuration found in .Values.tasks.cronJobs.mozcloud-cronjob.

If we just allow Helm to merge everything in .Values.tasks.cronJobs, it will try
to create a cron job literally called "mozcloud-cronjob" in addition to any
other cron jobs defined by the user. Because of this, we consider anything under
"mozcloud-cronjob" to be defaults and remove that key from the cron job list.

Params:

common (dict): (optional) The common task configurations in .Values.common.
cronJobs (dict): (required) The cron job configuration in .Values.tasks.cronJobs.
*/ -}}
{{- define "mozcloud.cronJob.formatter" -}}
{{- $common := default (dict) .common.cronJob -}}
{{- $cronJobValues := .cronJobs -}}
{{- $cronJobs := .cronJobs -}}
{{- $defaultKey := "mozcloud-cronjob" -}}
{{- /* Remove default job key and merge with user-defined keys, if defined */ -}}
{{- if or
  (and
    (eq (keys $cronJobValues | len) 1)
    (eq (keys $cronJobValues | first) $defaultKey)
  )
  (gt (keys $cronJobValues | len) 1)
}}
  {{- $cronJobs = omit $cronJobs $defaultKey -}}
  {{- range $name, $config := $cronJobs -}}
    {{- $defaults := index $cronJobValues $defaultKey -}}
    {{- $config = mergeOverwrite (deepCopy $common) $config -}}
    {{- $_ := set $cronJobs $name (mergeOverwrite ($defaults | deepCopy) $config) -}}
  {{- end -}}
{{- end -}}
{{- /* Apply preview prefix to cronjob names if in preview mode */ -}}
{{- if include "mozcloud.preview.enabled" $ -}}
  {{- $prefix := include "mozcloud.preview.prefix" $ -}}
  {{- $prefixed_cronJobs := dict -}}
  {{- range $name, $config := $cronJobs -}}
    {{- $prefixed_name := printf "%s%s" $prefix $name -}}
    {{- $_ := set $prefixed_cronJobs $prefixed_name $config -}}
  {{- end -}}
  {{- $cronJobs = $prefixed_cronJobs -}}
{{- end -}}
{{ $cronJobs | toYaml }}
{{- end -}}

{{- /*
This function will attempt to merge user-defined jobs with the default job
configuration found in .Values.tasks.jobs.mozcloud-job.

If we just allow Helm to merge everything in .Values.tasks.jobs, it will try
to create a job literally called "mozcloud-job" in addition to any other jobs
defined by the user. Because of this, we consider anything under "mozcloud-job"
to be defaults and remove that key from the job list.

Params:

common (dict): (optional) The common task configurations in .Values.common.
jobs (dict): (required) The job configuration in .Values.tasks.jobs.
*/ -}}
{{- define "mozcloud.job.formatter" -}}
{{- $common := default (dict) .common.job -}}
{{- $jobValues := .jobs -}}
{{- $jobs := .jobs -}}
{{- $defaultKey := "mozcloud-job" -}}
{{- /* Remove default job key and merge with user-defined keys, if defined */ -}}
{{- if or
  (and
    (eq (keys $jobValues | len) 1)
    (eq (keys $jobValues | first) $defaultKey)
  )
  (gt (keys $jobValues | len) 1)
}}
  {{- $jobs = omit $jobs $defaultKey -}}
  {{- range $name, $config := $jobs -}}
    {{- $defaults := index $jobValues $defaultKey -}}
    {{- $config = mergeOverwrite (deepCopy $common) $config -}}
    {{- $_ := set $jobs $name (mergeOverwrite ($defaults | deepCopy) $config) -}}
  {{- end -}}
{{- end -}}
{{- /* Apply preview prefix to job names if in preview mode */ -}}
{{- if include "mozcloud.preview.enabled" $ -}}
  {{- $prefix := include "mozcloud.preview.prefix" $ -}}
  {{- $prefixedJobs := dict -}}
  {{- range $name, $config := $jobs -}}
    {{- $prefixedName := printf "%s%s" $prefix $name -}}
    {{- $_ := set $prefixedJobs $prefixedName $config -}}
  {{- end -}}
  {{- $jobs = $prefixedJobs -}}
{{- end -}}
{{ $jobs | toYaml }}
{{- end -}}
