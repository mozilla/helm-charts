{{/*
Formatting helpers
*/}}
{{- define "mozcloud.cronJob.formatter" -}}
{{- /*
This function will attempt to merge user-defined cron jobs with the default cron
job configuration found in .Values.tasks.cronJobs.mozcloud-cronjob.

If we just allow Helm to merge everything in .Values.tasks.cronJobs, it will try
to create a cron job literally called "mozcloud-cronjob" in addition to any
other cron jobs defined by the user. Because of this, we consider anything under
"mozcloud-cronjob" to be defaults and remove that key from the cron job list.

Params:
*/ -}}
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
    {{- $_ := set $cronJobs $name (mergeOverwrite ($defaults | deepCopy) $config) -}}
  {{- end -}}
{{- end -}}
{{ $cronJobs | toYaml }}
{{- end -}}

{{- define "mozcloud.job.formatter" -}}
{{- /*
This function will attempt to merge user-defined jobs with the default job
configuration found in .Values.tasks.jobs.mozcloud-job.

If we just allow Helm to merge everything in .Values.tasks.jobs, it will try
to create a job literally called "mozcloud-job" in addition to any other jobs
defined by the user. Because of this, we consider anything under "mozcloud-job"
to be defaults and remove that key from the job list.

Params:
*/ -}}
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
    {{- $_ := set $jobs $name (mergeOverwrite ($defaults | deepCopy) $config) -}}
  {{- end -}}
{{- end -}}
{{ $jobs | toYaml }}
{{- end -}}
