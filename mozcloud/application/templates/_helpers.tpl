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
Template helpers
*/}}

{{/*
Ingress resources
*/}}

{{/*
Frontend configs
*/}}
{{- define "mozcloud.config.frontendConfigs" -}}
{{- $workloads := .workloads -}}
frontendConfigs:
  {{- range $workload_name, $workload_config := $workloads }}
  {{- range $host_name, $host_config := default (dict) $workload_config.hosts }}
  {{- if eq $host_config.type "external" }}
  {{ $host_name }}:
    component: {{ $workload_config.component }}
    redirectToHttps:
      enabled: true
      responseCodeName: MOVED_PERMANENTLY_DEFAULT
    sslPolicy: mozilla-intermediate
  {{- end }}
  {{- end }}
  {{- end }}
{{- end -}}

{{/*
Ingresses
*/}}
{{- define "mozcloud.config.ingresses" -}}
{{- $globals := .Values.global.mozcloud }}
{{- $workloads := .workloads -}}
ingresses:
  {{- range $workload_name, $workload_config := $workloads }}
  {{- range $host_name, $host_config := default (dict) $workload_config.hosts }}
  {{- if eq $host_config.type "external" }}
  {{ $host_name }}:
    component: {{ $workload_config.component }}
    hosts:
      - domains:
          {{- range $domain := $host_config.domains }}
          - {{ $domain | quote }}
          {{- end }}
        paths:
          - path: /
            pathType: Prefix
            backend:
              config:
                name: {{ $workload_name }}
                {{- if (($host_config.options).iap).enabled }}
                iap:
                  enabled: {{ $host_config.options.iap.enabled }}
                {{- end }}
                {{- if ($host_config.options).logSampleRate }}
                logging:
                  {{- $sampleRate := $host_config.options.logSampleRate | float64 }}
                  sampleRate: {{ divf $sampleRate 100 }}
                {{- end }}
                {{- if ($host_config.options).timeoutSec }}
                  timeoutSec: {{ $host_config.options.timeoutSec }}
                {{- end }}
              service:
                name: {{ $workload_name }}
                port: 8080
                protocol: TCP
                targetPort: http
        tls:
          {{- $type := ($host_config.tls.type) }}
          {{- if or (not $type) (eq $type "certmap") }}
            {{- $type = "ManagedCertificate" }}
          {{- end }}
          type: {{ $type }}
          {{- if and (hasKey $host_config.tls "create") ($host_config.tls.create) }}
          createCertificates: true
          {{- if eq $type "ManagedCertificate" }}
          multipleHosts: false
          {{- end }}
          {{- end }}
          {{- if eq $type "pre-shared" }}
          preSharedCerts: {{ join "," (uniq $host_config.tls.certs | sortAlpha) | quote }}
          {{- end }}
    {{- if $host_config.addresses }}
    staticIpName: {{ $host_config.addresses | first }}
    {{- else }}
    staticIpName: {{ $globals.app_code }}-{{ $globals.env_code }}-ip-v4
    {{- end }}
  {{- end }}
  {{- end }}
  {{- end }}
{{- end -}}

{{/*
Stateless workload resources
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
Deployments
*/}}
{{- define "mozcloud.config.deployments" -}}
{{- $globals := .Values.global.mozcloud -}}
{{- $external_secrets := default (dict) .Values.externalSecrets -}}
{{- $workloads := .workloads -}}
{{- $prefix := include "mozcloud.preview.prefix" . -}}
{{- /* In preview mode, use prefixed names matching ExternalSecret; otherwise maintain backwards compatibility */ -}}
{{- $defaultSecretName := printf "%s%s-secrets" $prefix $globals.app_code -}}
{{- $defaultServiceAccount := printf "%s%s" $prefix $globals.app_code -}}
deployments:
  {{- range $workload_name, $workload_config := $workloads }}
  {{- $nginx_enabled := true }}
  {{- if or
    (not (dig "nginx" "enabled" "true" $workload_config))
    (not $workload_config.hosts)
  }}
  {{- $nginx_enabled = false }}
  {{- end }}
  {{ $workload_name }}:
    component: {{ $workload_config.component }}
    labels:
      {{- range $k, $v := (default (list) ($workload_config.labels)) }}
      {{ $k }}: {{ $v }}
      {{- end }}
    {{- if $workload_config.terminationGracePeriodSeconds }}
    terminationGracePeriodSeconds: {{ $workload_config.terminationGracePeriodSeconds }}
    {{- end }}
    containers:
      {{- $formatter_params := dict "containers" $workload_config.containers "type" "containers" }}
      {{- $containers := include "common.formatter.containers" $formatter_params | fromYaml }}
      {{- range $container_name, $container_config := $containers }}
      - name: {{ $container_name }}
        {{- if and (not ($container_config.image).repository) (not ($globals.image).repository) }}
        {{- $fail_message := printf "A fully qualified image path must be configured in either \".Values.mozcloud.workloads.%s.containers.%s.image.repository\" or \".Values.global.mozcloud.image.repository\"." $workload_name $container_name }}
        {{- fail $fail_message }}
        {{- end }}
        image: {{ default ($globals.image).repository ($container_config.image).repository }}
        {{- if and (not ($container_config.image).tag) (not ($globals.image).tag) }}
        {{- $fail_message := printf "An image tag must be configured in either \".Values.mozcloud.workloads.%s.containers.%s.image.tag\" or \".Values.global.mozcloud.image.tag\"." $workload_name $container_name }}
        {{- fail $fail_message }}
        {{- end }}
        tag: {{ default ($globals.image).tag ($container_config.image).tag }}
        {{- if $container_config.command }}
        command:
          {{- range $line := $container_config.command }}
          - {{ $line | quote }}
          {{- end }}
        {{- end }}
        {{- if $container_config.args }}
        args:
          {{- range $line := $container_config.args }}
          - {{ $line | quote }}
          {{- end }}
        {{- end }}
        {{- if $container_config.envVars }}
        env:
          {{- range $env_key, $env_val := $container_config.envVars }}
          - name: {{ $env_key }}
            value: {{ $env_val | quote }}
          {{- end }}
        {{- end }}
        envFrom:
          {{- if $container_config.configMaps }}
          {{- range $config_map := $container_config.configMaps }}
          - configMapRef:
              name: {{ $config_map }}
          {{- end }}
          {{- end }}
          - secretRef:
              name: {{ $defaultSecretName }}
          {{- if and $container_config.externalSecrets $external_secrets }}
          {{- range $external_secret := $container_config.externalSecrets }}
          {{- if has $external_secret (keys $external_secrets) }}
          - secretRef:
              name: {{ $external_secret }}
          {{- end }}
          {{- end }}
          {{- end }}
        {{- if (dig "healthCheck" "liveness" "enabled" true $container_config) }}
        livenessProbe:
          httpGet:
            {{- if (($container_config.healthCheck).liveness).httpHeaders }}
            httpHeaders:
              {{- range $header := $container_config.healthCheck.liveness.httpHeaders }}
              - name: {{ $header.name }}
                value: {{ $header.value }}
              {{- end }}
            {{- else if (($container_config.healthCheck).readiness).httpHeaders }}
            httpHeaders:
              {{- range $header := $container_config.healthCheck.readiness.httpHeaders }}
              - name: {{ $header.name }}
                value: {{ $header.value }}
              {{- end }}
            {{- end }}
            path: {{ default "/__lbheartbeat__" $container_config.healthCheck.liveness.path }}
            port: app
          {{- if (($container_config.healthCheck).liveness).probes }}
          {{- range $k, $v := $container_config.healthCheck.liveness.probes }}
          {{ $k }}: {{ $v }}
          {{- end }}
          {{- else if (($container_config.healthCheck).readiness).probes }}
          {{- range $k, $v := $container_config.healthCheck.readiness.probes }}
          {{ $k }}: {{ $v }}
          {{- end }}
          {{- end }}
        {{- end }}
        {{- if (dig "healthCheck" "readiness" "enabled" true $container_config) }}
        readinessProbe:
          httpGet:
            {{- if (($container_config.healthCheck).readiness).httpHeaders }}
            httpHeaders:
              {{- range $header := $container_config.healthCheck.readiness.httpHeaders }}
              - name: {{ $header.name }}
                value: {{ $header.value }}
              {{- end }}
            {{- end }}
            path: {{ default "/__lbheartbeat__" $container_config.healthCheck.readiness.path }}
            port: app
          {{- if (($container_config.healthCheck).readiness).probes }}
          {{- range $k, $v := $container_config.healthCheck.readiness.probes }}
          {{ $k }}: {{ $v }}
          {{- end }}
          {{- end }}
        {{- end }}
        {{- if or
            $workload_config.hosts
            (($container_config.healthCheck).readiness).enabled
            (($container_config.healthCheck).liveness).enabled
        }}
        ports:
          - name: app
            containerPort: {{ $container_config.port }}
        {{- end }}
        resources:
          requests:
            cpu: {{ $container_config.resources.cpu }}
            memory: {{ $container_config.resources.memory }}
        {{- if or ($container_config.security).uid ($container_config.security).gid ($container_config.security).addCapabilities }}
        securityContext:
          {{- $security_context := include "mozcloud.config.securityContext" $container_config.security | fromYaml }}
          uid: {{ $security_context.user }}
          gid: {{ $security_context.group }}
          {{- if gt (len $container_config.security.addCapabilities) 0 }}
          addCapabilities:
            {{- range $capability := $container_config.security.addCapabilities }}
            - {{ $capability }}
            {{- end }}
          {{- end }}
        {{- end }}
        {{- if $container_config.volumes }}
        volumes:
          {{- $container_config.volumes | toYaml | nindent 10 }}
        {{- end }}
      {{- end }}
    {{- $formatter_params = dict "containers" (default (dict) $workload_config.initContainers) "type" "init-containers" }}
    {{- $init_containers := include "common.formatter.containers" $formatter_params | fromYaml }}
    {{- if $init_containers }}
    initContainers:
      {{- range $container_name, $container_config := $init_containers }}
      - name: {{ $container_name }}
        {{- if and (not ($container_config.image).repository) (not ($globals.image).repository) }}
        {{- $fail_message := printf "A fully qualified image path must be configured in either \".Values.mozcloud.workloads.%s.initContainers.%s.image.repository\" or \".Values.global.mozcloud.image.repository\"." $workload_name $container_name }}
        {{- fail $fail_message }}
        {{- end }}
        image: {{ default ($globals.image).repository ($container_config.image).repository }}
        {{- if and (not ($container_config.image).tag) (not ($globals.image).tag) }}
        {{- $fail_message := printf "An image tag must be configured in either \".Values.mozcloud.workloads.%s.initContainers.%s.image.tag\" or \".Values.global.mozcloud.image.tag\"." $workload_name $container_name }}
        {{- fail $fail_message }}
        {{- end }}
        tag: {{ default ($globals.image).tag ($container_config.image).tag }}
        {{- if $container_config.command }}
        command:
          {{- range $line := $container_config.command }}
          - {{ $line | quote }}
          {{- end }}
        {{- end }}
        {{- if $container_config.args }}
        args:
          {{- range $line := $container_config.args }}
          - {{ $line | quote }}
          {{- end }}
        {{- end }}
        {{- if $container_config.envVars }}
        env:
          {{- range $env_key, $env_val := $container_config.envVars }}
          - name: {{ $env_key }}
            value: {{ $env_val | quote }}
          {{- end }}
        {{- end }}
        envFrom:
          {{- if $container_config.configMaps }}
          {{- range $config_map := $container_config.configMaps }}
          - configMapRef:
              name: {{ $config_map }}
          {{- end }}
          {{- end }}
          - secretRef:
              name: {{ $defaultSecretName }}
          {{- if and $container_config.externalSecrets $external_secrets }}
          {{- range $external_secret := $container_config.externalSecrets }}
          {{- if has $external_secret (keys $external_secrets) }}
          - secretRef:
              name: {{ $external_secret }}
          {{- end }}
          {{- end }}
          {{- end }}
        {{- if $container_config.port }}
        ports:
          - name: {{ $container_name }}
            containerPort: {{ $container_config.port }}
        {{- end }}
        resources:
          requests:
            cpu: {{ $container_config.resources.cpu }}
            memory: {{ $container_config.resources.memory }}
        {{- if (dig "sidecar" false $container_config) }}
        restartPolicy: Always
        {{- end }}
        {{- if or ($container_config.security).uid ($container_config.security).gid ($container_config.security).addCapabilities }}
        securityContext:
          {{- $security_context := include "mozcloud.config.securityContext" $container_config.security | fromYaml }}
          uid: {{ $security_context.user }}
          gid: {{ $security_context.group }}
          {{- if gt (len $container_config.security.addCapabilities) 0 }}
          addCapabilities:
            {{- range $capability := $container_config.security.addCapabilities }}
            - {{ $capability }}
            {{- end }}
          {{- end }}
        {{- end }}
        {{- if $container_config.volumes }}
        volumes:
          {{- $container_config.volumes | toYaml | nindent 10 }}
        {{- end }}
      {{- end }}
    {{- end }}
    {{- if $nginx_enabled }}
    nginx:
      enabled: true
      {{- if ($workload_config.nginx).image }}
      image: {{ $workload_config.nginx.image }}
      {{- end }}
      {{- if ($workload_config.nginx).configMap }}
      configMap: {{ $workload_config.nginx.configMap }}
      {{- end }}
      {{- if or (($workload_config.nginx).resources).cpu (($workload_config.nginx).resources).memory }}
      resources:
        {{- if $workload_config.nginx.resources.cpu }}
        cpu: {{ $workload_config.nginx.resources.cpu }}
        {{- end }}
        {{- if $workload_config.nginx.resources.memory }}
        memory: {{ $workload_config.nginx.resources.memory }}
        {{- end }}
      {{- end }}
    {{- end }}
    otel:
      {{- $workload_config.otel | toYaml | nindent 6 }}
    {{- if ($workload_config.security).runAsRoot }}
    securityContext:
      runAsNonRoot: false
    {{- end }}
    serviceAccount: {{ default $defaultServiceAccount $workload_config.serviceAccount }}
    strategy: {{ $workload_config.strategy }}
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
Security context
*/}}
{{- define "mozcloud.config.securityContext" -}}
{{- $user := default "" .user -}}
{{- $group := default "" .group -}}
{{- if and $user (not $group) -}}
  {{- $group = $user -}}
{{- else if and $group (not $user) -}}
  {{- $user = $group -}}
{{- end -}}
user: {{ $user }}
group: {{ $group }}
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
