{{- define "mozcloud-job-lib.job" -}}
{{- if gt (len ((.jobConfig).jobs)) 0 }}
{{- $jobs := include "mozcloud-job-lib.config.jobs" . | fromYaml }}
{{- range $job := $jobs.jobs }}
{{- $failed_message := printf "Failed to create job \"%s\": " $job.name }}
---
apiVersion: batch/v1
kind: Job
metadata:
  {{- $name := $job.name }}
  {{- if $job.generateName }}
  {{- if not (hasSuffix "-" $name) }}
  {{- $name = printf "%s-" $name }}
  {{- end }}
  generateName: {{ $name }}
  {{- else }}
  name: {{ $job.name }}
  {{- end }}
  labels:
    {{- $job.labels | toYaml | nindent 4 }}
  {{- $argo := ($job.argo) }}
  {{- if or $argo.hookDeletionPolicy $argo.hooks $argo.syncWave }}
  annotations:
    {{- if $argo.hooks }}
    argocd.argoproj.io/hook: {{ $argo.hooks }}
    {{- else if and $argo.hookDeletionPolicy $argo.syncWave }}
    argocd.argoproj.io/hook: Sync
    {{- end }}
    {{- if $argo.hookDeletionPolicy }}
    argocd.argoproj.io/hook-delete-policy: {{ $argo.hookDeletionPolicy }}
    {{- end }}
    {{- if $argo.syncWave }}
    argocd.argoproj.io/sync-wave: {{ $argo.syncWave | quote }}
    {{- end }}
  {{- end }}
spec:
  {{- $config := ($job.config) }}
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
        {{- range $container := $job.containers }}
        - name: {{ required (printf "%sContainer name (containers[].name) is required!" $failed_message) $container.name }}
          image: {{ required (printf "%sContainer image (containers[].image) is required!" $failed_message) $container.image }}:{{ $container.tag }}
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
            {{- $container.resources | toYaml | nindent 12 }}
        {{- end }}
      {{- if $config.restartPolicy }}
      restartPolicy: {{ $config.restartPolicy }}
      {{- end }}
{{- end }}
{{- end }}
{{- end -}}
