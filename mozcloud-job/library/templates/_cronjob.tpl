{{- define "mozcloud-job-lib.cronJob" -}}
{{- if gt (len ((.cronJobConfig).cronJobs)) 0 }}
{{- $cron_jobs := include "mozcloud-job-lib.config.cronJobs" . | fromYaml }}
{{- $service_accounts := list }}
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
  {{- if $config.suspend }}
  suspend: {{ $config.suspend }}
  {{- end }}
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
                requests:
                  cpu: {{ $container.resources.requests.cpu | quote }}
                  memory: {{ $container.resources.requests.memory | quote }}
                limits:
                  cpu: {{ $container.resources.limits.cpu | quote }}
                  memory: {{ $container.resources.limits.memory | quote }}
              securityContext:
                {{- $container.securityContext | toYaml | nindent 16 }}
            {{- end }}
          {{- if $job_config.restartPolicy }}
          restartPolicy: {{ $job_config.restartPolicy }}
          {{- end }}
          securityContext:
            {{- $job_config.securityContext | toYaml | nindent 12 }}
          {{- if ($job_config.serviceAccount).name }}
          serviceAccountName: {{ $job_config.serviceAccount.name }}
          {{- end }}
{{- if ($job_config.serviceAccount).create }}
{{- $service_accounts = append $service_accounts (omit $job_config.serviceAccount "create") }}
{{- end }}
{{- end }}
{{- if gt (len $service_accounts) 0 }}
{{ include "mozcloud-workload-core-lib.serviceAccount" (dict "serviceAccounts" $service_accounts) }}
{{- end }}
{{- end }}
{{- end -}}
