{{- define "mozcloud-job-lib.cronJob" -}}
{{- if gt (keys (default (dict) (.cronJobConfig).cronJobs) | len) 0 }}
{{- $context := . | deepCopy }}
{{- if not $context.component_code }}
  {{- $_ := set $context "component_code" "cronjob" }}
{{- end }}
{{- $global_image := default (dict) .image }}
{{- $cron_jobs := include "mozcloud-job-lib.config.cronJobs" . | fromYaml }}
{{- $service_accounts := list }}
{{- range $cron_job := $cron_jobs.cronJobs }}
{{- $volumes := dict }}
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
  schedule: '{{ $config.schedule }}'
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
        {{- /* If auto injection is enabled for OTEL, we should include those annotations */}}
        {{- $otel_annotations := dict }}
        {{- if and (($cron_job.otel).autoInstrumentation).enabled (($cron_job.otel).autoInstrumentation).language }}
        {{- $container_names := list }}
        {{- range $container := $cron_job.containers }}
          {{- $container_names = append $container_names $container.name }}
        {{- end }}
        {{- $otel_annotation_params := dict "containers" $container_names "language" $cron_job.otel.autoInstrumentation.language }}
        {{- $otel_annotations = include "mozcloud-workload-core-lib.config.annotations.otel.autoInjection" $otel_annotation_params | fromYaml }}
        {{- end }}
        {{- /* Note: pod annotations will automatically include resource annotations for OTEL */}}
        {{- $annotation_params := dict "annotations" $otel_annotations "context" ($context | deepCopy) "type" "pod" }}
        {{- $annotations := include "mozcloud-workload-core-lib.config.annotations" $annotation_params | fromYaml }}
        {{- if $annotations }}
        metadata:
          annotations:
            {{- $annotations | toYaml | nindent 14 }}
        {{- end }}
        spec:
          containers:
            {{- range $container := $cron_job.containers }}
            - name: {{ default "job" $container.name }}
              {{- if and (not ($container.image).repository) (not $global_image.repository) }}
              {{- fail (printf "%sContainer image repository must be set! You can set this in either .Values.mozcloud-job.cronJobs.%s.containers[].image.repository or .Values.global.mozcloud.image.repository" $cron_job.name) }}
              {{- end }}
              image: {{ default ($global_image).repository ($container.image).repository }}:{{ $container.image.tag }}
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
              {{- if $container.env }}
              env:
                {{- range $env_var := $container.env }}
                - name: {{ $env_var.name }}
                  value: {{ $env_var.value | quote }}
                {{- end }}
              {{- end }}
              {{- if $container.envFrom }}
              envFrom:
                {{- range $config_map := default (list) $container.envFrom.configMaps }}
                - configMapRef:
                    name: {{ $config_map }}
                {{- end }}
                {{- range $secret := default (list) $container.envFrom.secrets }}
                - secretRef:
                    name: {{ $secret }}
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
              {{- if $container.volumes }}
              volumeMounts:
                {{- range $volume := $container.volumes }}
                - name: {{ $volume.name }}
                  mountPath: {{ $volume.path }}
                  {{- if $volume.key }}
                  subPath: {{ $volume.key }}
                  {{- end }}
                  {{- if eq $volume.type "secret" }}
                  readOnly: true
                  {{- else if $volume.readOnly }}
                  readOnly: {{ $volume.readOnly }}
                  {{- end }}
                  {{- if not (hasKey $volumes $volume.name) }}
                  {{- $_ := set $volumes $volume.name $volume }}
                  {{- end }}
                {{- end }}
              {{- end }}
            {{- end }}
          {{- if $job_config.restartPolicy }}
          restartPolicy: {{ $job_config.restartPolicy }}
          {{- end }}
          securityContext:
            {{- $job_config.securityContext | toYaml | nindent 12 }}
          {{- if ($job_config.serviceAccount).name }}
          serviceAccountName: {{ $job_config.serviceAccount.name }}
          {{- end }}
          {{- if gt (keys $volumes | len) 0 }}
          volumes:
            {{- range $volume_name, $volume_config := $volumes }}
            - name: {{ $volume_name }}
              {{- if eq $volume_config.type "configMap" }}
              configMap:
              {{- else if eq $volume_config.type "secret" }}
              secret:
              {{- end }}
                name: {{ $volume_name }}
            {{- end }}
          {{- end }}
{{- if ($job_config.serviceAccount).create }}
{{- $service_account := omit $job_config.serviceAccount "create" -}}
{{- $_ := set $service_account "labels" $cron_job.labels -}}
{{- $service_accounts = append $service_accounts $service_account }}
{{- end }}
{{- end }}
{{- if gt (len $service_accounts) 0 }}
{{ include "mozcloud-workload-core-lib.serviceAccount" (mergeOverwrite ($ | deepCopy) (dict "serviceAccounts" $service_accounts)) }}
{{- end }}
{{- end }}
{{- end -}}
