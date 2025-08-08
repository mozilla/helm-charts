{{- define "mozcloud-job-lib.cronJob" -}}
{{- if gt (len ((.cronJobConfig).cronJobs)) 0 }}
{{- $cron_jobs := include "mozcloud-job-lib.config.cronJobs" . | fromYaml }}
{{- range $cron_job := $cron_jobs.cronJobs }}
{{- $failed_message := printf "Failed to create cron job \"%s\": " $cron_job.name }}
---
apiVersion: batch/v1
kind: CronJob
metadata:
  name: {{ $cron_job.name }}
  labels:
    {{- $cron_job.labels | toYaml | nindent 4 }}
spec:
  {{- $config := $cron_job.config }}
  successfulJobsHistoryLimit: {{ $config.jobHistory.successful }}
  failedJobsHistoryLimit: {{ $config.jobHistory.failed }}
  schedule: '{{ required (printf "%sSchedule (schedule) is required!" $failed_message) $config.schedule }}'
  jobTemplate:
    spec:
      {{- $job_config := ($cron_job.jobConfig) }}
      {{- if $job_config.activeDeadlineSeconds }}
      activeDeadlineSeconds: {{ $job_config.activeDeadlineSeconds }}
      {{- end }}
      {{- if $job_config.backoffLimit }}
      backoffLimit: {{ $job_config.backoffLimit }}
      {{- end }}
      {{- if $job_config.parallelism }}
      parallelism: {{ $job_config.parallelism }}
      {{- end }}
      {{- if $job_config.ttlSecondsAfterFinished }}
      ttlSecondsAfterFinished: {{ $job_config.ttlSecondsAfterFinished }}
      {{- end }}
      template:
        spec:
          containers:
            {{- range $container := $cron_job.containers }}
            - name: {{ required (printf "%sContainer name (cronJobs[].containers[].name) is required!" $failed_message) $container.name }}
              image: {{ required (printf "%sContainer image (cronJobs[].containers[].image) is required!" $failed_message) $container.image }}:{{ $container.tag }}
              {{- if $container.command }}
              command:
                {{- range $line := $container.command }}
                - {{ $line | quote }}
                {{- end }}
              {{- end }}
              {{- if $container.args }}
              args:
                {{- range $line := $container.args }}
                - {{ $line | quote }}
                {{- end }}
              {{- end }}
              resources:
                {{- $container.resources | toYaml | nindent 16 }}
            {{- end }}
          {{- if $job_config.restartPolicy }}
          restartPolicy: {{ $job_config.restartPolicy }}
          {{- end }}
{{- end }}
{{- end }}
{{- end -}}
