{{/*
Formatting helpers
*/}}
{{- /*
Formatter for CronJob configurations. Merges each user-defined CronJob entry
with defaults from the protected "mozcloud-cronjob" key, then merges in common
task settings from .Values.tasks.common.cronJob, and returns the consolidated
CronJobs dict.

The protected key acts as a defaults template: it is stripped from the output
and its values are deep-merged as a base under each named CronJob before
applying common config. If only the protected key is present (no user-defined
CronJobs), it is passed through as-is so that the single default CronJob still
renders.

In preview mode, CronJob names are prefixed with "pr<PR number>-".

See the formatter background notes in _formatter.yaml for the full rationale.

Params:
  common (dict):   (optional) Common task configuration from
                   .Values.tasks.common. The "cronJob" sub-key is merged
                   into each CronJob before default values are applied.
  cronJobs (dict): (required) The CronJobs dict from values (e.g.
                   .Values.tasks.cronJobs).

Returns:
  (string) YAML-encoded dict of consolidated CronJob configurations, keyed
           by CronJob name (with preview prefix applied if applicable).

Example:
  Input:
    common:
      cronJob:
        ttlSecondsAfterFinished: 300
    cronJobs:
      mozcloud-cronjob:         # protected default key
        schedule: "0 * * * *"
        containers:
          mozcloud-container:
            resources:
              cpu: 250m
              memory: 256Mi
      cleanup-job:              # user-defined CronJob
        schedule: "0 2 * * *"
        containers:
          mozcloud-container:
            resources:
              cpu: 500m

  Output:
    cleanup-job:
      schedule: "0 2 * * *"    # user value
      ttlSecondsAfterFinished: 300  # from common.cronJob
      containers:
        mozcloud-container:
          resources:
            cpu: 500m           # user value wins (mergeOverwrite)
            memory: 256Mi       # inherited from default
*/ -}}
{{- define "mozcloud.task.formatter.cronJob" -}}
{{- $common := default dict .common.cronJob -}}
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
  {{- $prefixedCronJobs := dict -}}
  {{- range $name, $config := $cronJobs -}}
    {{- $prefixedName := printf "%s%s" $prefix $name -}}
    {{- $_ := set $prefixedCronJobs $prefixedName $config -}}
  {{- end -}}
  {{- $cronJobs = $prefixedCronJobs -}}
{{- end -}}
{{ $cronJobs | toYaml }}
{{- end -}}

{{- /*
Formatter for Job configurations. Merges each user-defined Job entry with
defaults from the protected "mozcloud-job" key, then merges in common task
settings from .Values.tasks.common.job, and returns the consolidated Jobs dict.

The protected key acts as a defaults template: it is stripped from the output
and its values are deep-merged as a base under each named Job before applying
common config. If only the protected key is present (no user-defined Jobs), it
is passed through as-is so that the single default Job still renders.

In preview mode, Job names are prefixed with "pr<PR number>-".

See the formatter background notes in _formatter.yaml for the full rationale.

Params:
  common (dict): (optional) Common task configuration from
                 .Values.tasks.common. The "job" sub-key is merged into
                 each Job before default values are applied.
  jobs (dict):   (required) The Jobs dict from values (e.g.
                 .Values.tasks.jobs).

Returns:
  (string) YAML-encoded dict of consolidated Job configurations, keyed by Job
           name (with preview prefix applied if applicable).

Example:
  Input:
    common:
      job:
        restartPolicy: Never
        ttlSecondsAfterFinished: 300
    jobs:
      mozcloud-job:             # protected default key
        containers:
          mozcloud-container:
            resources:
              cpu: 250m
              memory: 256Mi
      db-migrate:               # user-defined Job
        containers:
          mozcloud-container:
            resources:
              cpu: 500m

  Output:
    db-migrate:
      restartPolicy: Never          # from common.job
      ttlSecondsAfterFinished: 300  # from common.job
      containers:
        mozcloud-container:
          resources:
            cpu: 500m           # user value wins (mergeOverwrite)
            memory: 256Mi       # inherited from default
*/ -}}
{{- define "mozcloud.task.formatter.job" -}}
{{- $common := default dict .common.job -}}
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
