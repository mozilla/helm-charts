{{- define "mozcloud-job-lib.cronJob" -}}
{{- if gt (len ((.cronJobConfig).cronJobs)) 0 }}
{{- $cron_jobs := include "mozcloud-job-lib.config.cronJobs" . | fromYaml }}
{{- range $cron_job := $cron_jobs.cronJobs }}
---
apiVersion: batch/v1
kind: CronJob
metadata:
  name: {{ $cron_job.name }}
  labels:
    {{- $cron_job.labels | toYaml | nindent 4 }}
spec:
  schedule: {{ $cron_job.schedule }}
  jobTemplate:
    spec:
      {{- $config := ($cron_job.config) }}
      {{- if $config.activeDeadlineSeconds }}
      activeDeadlineSeconds: {{ $config.activeDeadlineSeconds }}
      {{- end }}
      {{- if $config.backoffLimit }}
      backoffLimit: {{ $config.backoffLimit }}
      {{- end }}
      {{- if $config.parallelism }}
      parallelism: {{ $config.parallelism }}
      {{- end }}
      {{- if $config.ttlSecondsAfterFinished }}
      ttlSecondsAfterFinished: {{ $config.ttlSecondsAfterFinished }}
      {{- end }}
      template:
        spec:
          containers:
            {{- range $container := $cron_job.containers }}
            - name: {{ required "A container name is required!" $container.name }}
              image: {{ required "A container image is required!" $container.image }}
              {{- if $container.command }}
              command:
                {{- $container.command | toYaml | nindent 12 }}
              {{- end }}
              {{- if $container.args }}
              args:
                {{- $container.args | toYaml | nindent 12 }}
              {{- end }}
            {{- end }}
          {{- if $config.restartPolicy }}
          restartPolicy: {{ $config.restartPolicy }}
          {{- end }}
{{- end }}
{{- end }}
{{- end -}}
