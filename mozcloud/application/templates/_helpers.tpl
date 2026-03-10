{{/*
Expand the name of the chart.
*/}}
{{- define "mozcloud.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "mozcloud.fullname" -}}
{{- $prefix := include "mozcloud.preview.prefix" . -}}
{{- if (.Values).fullnameOverride }}
{{- printf "%s%s" $prefix (.Values.fullnameOverride | trunc 63 | trimSuffix "-") }}
{{- else }}
{{- $name := default .Chart.Name (.Values).nameOverride }}
{{- if contains $name .Release.Name }}
{{- printf "%s%s" $prefix (.Release.Name | trunc 63 | trimSuffix "-") }}
{{- else }}
{{- printf "%s%s-%s" $prefix .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "mozcloud.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Preview mode helpers
*/}}

{{/*
Check if preview mode is enabled and has required configuration
*/}}
{{- define "mozcloud.preview.enabled" -}}
{{- if and .Values.preview.enabled .Values.global.preview .Values.global.preview.pr -}}
true
{{- end -}}
{{- end -}}

{{/*
Transform ConfigMap data for preview mode
Populates empty URL variables with preview host for keys specified in preview.urlTransformKeys
No transformation occurs by default - keys must be explicitly listed
*/}}
{{- define "mozcloud.preview.transformConfigMapData" -}}
{{- $data := .data -}}
{{- $previewHost := .previewHost -}}
{{- $transformKeys := .transformKeys | default list -}}
{{- $transformedData := dict -}}
{{- range $key, $value := $data -}}
  {{- $shouldTransform := false -}}
  {{- /* Check if key is in the explicit transform list */ -}}
  {{- range $transformKeys -}}
    {{- if eq $key . -}}
      {{- $shouldTransform = true -}}
    {{- end -}}
  {{- end -}}
  {{- /* Transform if key is listed and value is empty */ -}}
  {{- if and $shouldTransform (or (not $value) (eq $value "")) -}}
    {{- $_ := set $transformedData $key (printf "https://%s" $previewHost) -}}
  {{- else -}}
    {{- $_ := set $transformedData $key $value -}}
  {{- end -}}
{{- end -}}
{{ $transformedData | toYaml }}
{{- end -}}

{{/*
Generate preview prefix if preview mode is enabled
*/}}
{{- define "mozcloud.preview.prefix" -}}
{{- if include "mozcloud.preview.enabled" . -}}
{{- printf "pr%v-" .Values.global.preview.pr -}}
{{- end -}}
{{- end -}}

{{/*
Check if preview HTTPRoute should be used instead of standard
Defaults to true if not explicitly set
*/}}
{{- define "mozcloud.preview.usePreviewHttpRoute" -}}
{{- if include "mozcloud.preview.enabled" . -}}
  {{- $httpRouteEnabled := true -}}
  {{- if .Values.preview.httpRoute -}}
    {{- if hasKey .Values.preview.httpRoute "enabled" -}}
      {{- $httpRouteEnabled = .Values.preview.httpRoute.enabled -}}
    {{- end -}}
  {{- end -}}
  {{- if $httpRouteEnabled -}}
true
  {{- end -}}
{{- end -}}
{{- end -}}

{{/*
Check if preview endpoint check should be enabled
Defaults to true if not explicitly set
*/}}
{{- define "mozcloud.preview.endpointCheckEnabled" -}}
{{- if include "mozcloud.preview.enabled" . -}}
  {{- $endpointCheckEnabled := true -}}
  {{- if .Values.preview.endpointCheck -}}
    {{- if hasKey .Values.preview.endpointCheck "enabled" -}}
      {{- $endpointCheckEnabled = .Values.preview.endpointCheck.enabled -}}
    {{- end -}}
  {{- end -}}
  {{- if $endpointCheckEnabled -}}
true
  {{- end -}}
{{- end -}}
{{- end -}}

{{/*
Create label parameters to be used in library chart if defined as values.
*/}}
{{- define "mozcloud.labelParams" -}}
{{- $params := dict "chart" (include "mozcloud.name" .) -}}
{{- $label_params := list "app_code" "artifact_id" "chart" "env_code" "project_id" -}}
{{- range $label_param := $label_params -}}
  {{- if index $.Values.global.mozcloud $label_param -}}
    {{- $_ := set $params $label_param (index $.Values.global.mozcloud $label_param) -}}
  {{- end }}
{{- end }}
{{- $mozcloud_chart_labels := dict "mozcloud_chart" .Chart.Name "mozcloud_chart_version" .Chart.Version -}}
{{- $params = mergeOverwrite $params $mozcloud_chart_labels -}}
{{- /* Add preview PR as selector label if in preview mode */ -}}
{{- if and .Values.global.preview .Values.global.preview.pr -}}
  {{- $_ := set $params "preview_pr" .Values.global.preview.pr -}}
{{- end -}}
{{- $params | toYaml }}
{{- end }}

{{/*
Workload helpers
*/}}

{{/*
Autoscaling (HPAs)
*/}}
{{- define "mozcloud.config.autoscaling" -}}
{{- $workloads := .workloads -}}
hpas:
  {{- range $workload_name, $workload_config := $workloads }}
  {{- if (dig "autoscaling" "enabled" true $workload_config) }}
  {{ $workload_name }}:
    component: {{ $workload_config.component }}
    minReplicas: {{ default 1 (($workload_config.autoscaling).replicas).min }}
    maxReplicas: {{ default 30 (($workload_config.autoscaling).replicas).max }}
    scaleTargetRef:
      {{/*
      The following 3 lines will need to be tweaked when we officially support
      Argo Rollout resources
      */}}
      apiVersion: apps/v1
      kind: Deployment
      name: {{ $workload_name }}
    metrics:
      {{- range $metric := (default (list) ($workload_config.autoscaling).metrics) }}
      {{- if eq $metric.type "network" }}
      - type: Object
        object:
          describedObject:
            kind: Service
            name: {{ $workload_name }}
          metric:
            name: {{ default "autoscaling.googleapis.com|gclb-capacity-fullness" $metric.customMetric }}
          target:
            averageValue: {{ $metric.threshold | quote }}
            type: AverageValue
      {{- else }}
      - type: Resource
        resource:
          name: {{ $metric.type }}
          target:
            type: Utilization
            averageUtilization: {{ $metric.threshold }}
      {{- end }}
      {{- end }}
  {{- end }}
  {{- end }}
{{- end -}}

{{/*
Pod monitorings
*/}}
{{- define "mozcloud.config.podMonitorings" -}}
{{- $globals := .Values.global.mozcloud -}}
podMonitorings:
  {{- $globals.app_code }}:
    endpoints:
      {{- /* Defaults for all tenants */}}
      - port: 8080
        scheme: http
        interval: 30s
        path: /metrics
{{- end -}}

{{/*
Formatting helpers
*/}}
{{- define "mozcloud.formatter.host" -}}
{{- $component := .component -}}
{{- $hosts := .hosts -}}
{{- $output := dict -}}
{{- $workload_name := .workloadName -}}
{{- range $host_name, $host_config := $hosts -}}
  {{- if and (eq $host_config.api $component) (not (hasKey $output $workload_name)) -}}
    {{- /*
    If, for some reason, a user does not set a real name under
    .Values.workloads.hosts, use the workload name.
    */}}
    {{- if eq $host_name "name" -}}
      {{- $host_name = $workload_name -}}
    {{- end -}}
    {{- $_ := set $output $host_name $host_config -}}
  {{- end -}}
{{- end -}}
{{ $output | toYaml }}
{{- end -}}

{{- define "mozcloud.formatter.workloads" -}}
{{- $api := .api -}}
{{- $workload_values := .workloads -}}
{{- $workloads := .workloads -}}
{{- /* Remove default workloads key and merge with user-defined keys, if defined */}}
{{- if or
  (and (eq (keys $workload_values | len) 1) (keys $workload_values | first) "mozcloud-workload")
  (gt (keys $workload_values | len) 1)
}}
  {{- $workloads = omit $workloads "mozcloud-workload" -}}
  {{- range $name, $config := $workloads -}}
    {{- $default_workload := index $workload_values "mozcloud-workload" -}}
    {{- /* Merge host configs with defaults */}}
    {{- $host_values := $default_workload.hosts -}}
    {{- $hosts := dict -}}
    {{- $config_hosts := default (dict) $config.hosts -}}
    {{- range $host_name, $host_config := $config_hosts -}}
      {{- $_ := set $hosts $host_name (mergeOverwrite ($host_values.name | deepCopy) $host_config) -}}
    {{- end -}}
    {{- if gt (keys $hosts | len) 0 -}}
      {{- /*
      If an api parameter is provided, filter hosts to only those matching that API type.
      If no api parameter is provided, return all hosts regardless of API type.
      */ -}}
      {{- if and $api (or (eq $api "gateway") (eq $api "ingress")) -}}
        {{- $helper_params := dict "component" $api "hosts" $hosts "workloadName" $name -}}
        {{- $hosts = include "mozcloud.formatter.host" $helper_params | fromYaml -}}
      {{- end -}}
      {{- $_ := set $config "hosts" $hosts -}}
    {{- end -}}
    {{- $defaults := omit $default_workload "hosts" -}}
    {{- $_ := set $workloads $name (mergeOverwrite ($defaults | deepCopy) $config) -}}
  {{- end -}}
{{- end -}}
{{- /* Apply preview prefix to workload names if in preview mode */ -}}
{{- $preview_config := dig "preview" dict . -}}
{{- if and ($preview_config.enabled) ($preview_config.pr) -}}
  {{- $prefix := printf "pr%v-" $preview_config.pr -}}
  {{- $prefixed_workloads := dict -}}
  {{- range $name, $config := $workloads -}}
    {{- $prefixed_name := printf "%s%s" $prefix $name -}}
    {{- $_ := set $prefixed_workloads $prefixed_name $config -}}
  {{- end -}}
  {{- $workloads = $prefixed_workloads -}}
{{- end -}}
{{- range $name, $config := $workloads -}}
  {{- if not $config.component -}}
    {{- $fail_message := printf "A component was not defined for workload \"%s\". You must define a component in \".Values.mozcloud.workloads.%s.component\". See values.yaml in the mozcloud-workload chart for more details." $name $name -}}
    {{- fail $fail_message -}}
  {{- end -}}
{{- end -}}
{{ $workloads | toYaml }}
{{- end -}}

{{/*
Debug helper
*/}}
{{- define "mozcloud.debug" -}}
{{- . | mustToPrettyJson | printf "\nThe JSON output of the dumped var is: \n%s" | fail }}
{{- end -}}
