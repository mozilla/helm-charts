{{/*
Expand the name of the chart.
*/}}
{{- define "mozcloud-workload.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "mozcloud-workload.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "mozcloud-workload.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create label parameters to be used in library chart if defined as values.
*/}}
{{- define "mozcloud-workload.labelParams" -}}
{{- $params := dict "chart" (include "mozcloud-workload.name" .) -}}
{{- $label_params := list "app_code" "chart" "env_code" "project_id" -}}
{{- range $label_param := $label_params -}}
  {{- if index $.Values.global.mozcloud $label_param -}}
    {{- $_ := set $params $label_param (index $.Values.global.mozcloud $label_param) -}}
  {{- end }}
{{- end }}
{{- $params | toYaml }}
{{- end }}

{{/*
Template helpers
*/}}

{{/*
ConfigMaps
*/}}
{{- define "mozcloud-workload.config.configMap" -}}
configMaps:
  {{- range $name, $config := .configMaps }}
  {{ $name }}:
    {{- /*
    ConfigMaps, ExternalSecrets, and ServiceAccounts should be updated before all
    other resources
    */}}
    argo:
      syncWave: -11
    data:
      {{ $config.data | toYaml | nindent 6 }}
    annotations:
      {{ $config.annotations | toYaml | nindent 6 }}
  {{- end -}}
{{- end -}}

{{/*
Gateway API resources
*/}}

{{/*
Backends and backend policies
*/}}
{{- define "mozcloud-workload.config.backends" -}}
{{- $workloads := .workloads -}}
backends:
  {{- range $workload_name, $workload_config := $workloads }}
  {{- range $host_name, $host_config := default (dict) $workload_config.hosts }}
  {{- if $host_config.backends }}
  {{- range $backend := (default (list) $host_config.backends) }}
  {{ $backend.name }}:
    component: {{ $workload_config.component }}
    {{- if $backend.service }}
    service:
      {{- $backend.service | toYaml | nindent 6 }}
    {{- end }}
    {{- if $backend.backendPolicy }}
    backendPolicy:
      targetRef:
        {{- if and $backend.backendPolicy.targetRef.kind (eq $backend.backendPolicy.targetRef.kind "ServiceImport" )}}
        {{- $_ := set $backend.backendPolicy.targetRef "group" "net.gke.io" }}
        {{- end }}
        group: {{ default "" $backend.backendPolicy.targetRef.group | quote }}
        kind: {{ $backend.backendPolicy.targetRef.kind }}
        name: {{ $backend.backendPolicy.targetRef.name }}
    {{- end }}
    {{- if $backend.healthCheck }}
    healthCheck:
      path: {{ $backend.healthCheck.path }}
      {{- if ($backend.healthCheck).port }}
      port: {{ $backend.healthCheck.port }}
      {{- end }}
      {{- if ($backend.healthCheck).host }}
      host: {{ $backend.healthCheck.host }}
      {{- end }}
      targetRef:
        {{- if and $backend.healthCheck.targetRef.kind (eq $backend.healthCheck.targetRef.kind "ServiceImport" )}}
        {{- $_ := set $backend.healthCheck.targetRef "group" "net.gke.io" }}
        {{- end }}
        group: {{ default "" $backend.healthCheck.targetRef.group | quote }}
        kind: {{ default "Service" $backend.healthCheck.targetRef.kind }}
        name: {{ $backend.healthCheck.targetRef.name }}
    {{- end }}
  {{- end }}
  {{- else }}
  {{ $workload_name }}:
    component: {{ $workload_config.component }}
    service:
      port: 8080
      targetPort: http
    backendPolicy:
      logging:
        enabled: true
      {{- if ($host_config.options).logSampleRate }}
        {{- $sampleRate := $host_config.options.logSampleRate | float64 }}
        sampleRate: {{ mulf $sampleRate 10000 | round | int }}
      {{- end }}
      {{- if ($host_config.options).iap }}
      iap:
        {{- if $host_config.options.iap.enabled }}
        enabled: {{ $host_config.options.iap.enabled }}
        {{- end }}
        {{- if $host_config.options.iap.oauth2ClientId }}
        oauth2ClientId: {{ $host_config.options.iap.oauth2ClientId }}
        {{- end }}
        {{- if $host_config.options.iap.oauth2ClientSecret }}
        oauth2ClientSecret: {{ $host_config.options.iap.oauth2ClientSecret }}
        {{- end }}
      {{- end }}
      {{- if ($host_config.options).timeoutSec }}
      timeoutSec: {{ $host_config.options.timeoutSec | int }}
      {{- end }}
    healthCheck:
      {{- if (($host_config.options).healthCheck).host }}
      host: {{ $host_config.options.healthCheck.host }}
      {{- end }}
      {{- if (($host_config.options).healthCheck).port }}
      port: {{ $host_config.options.healthCheck.port }}
      {{- end }}
      {{- if (($host_config.options).healthCheck).path }}
      path: {{ $host_config.options.healthCheck.path }}
      {{- else if kindIs "string" (($host_config).healthCheckEndpoints).loadBalancer }}
      path: {{ default "/__lbheartbeat__" (($host_config).healthCheckEndpoints).loadBalancer }}
      {{- else if kindIs "map" (($host_config).healthCheckEndpoints).loadBalancer }}
      path: {{ default "/__lbheartbeat__" ($host_config.healthCheckEndpoints.loadBalancer).path }}
      {{- end }}
      protocol: HTTP
  {{- end }}
  {{- end }}
  {{- end }}
{{- end -}}

{{/*
Gateway policy
*/}}
{{- define "mozcloud-workload.config.gatewayPolicy" -}}
sslPolicy: mozilla-intermediate
{{- end -}}

{{/*
Gateways
*/}}
{{- define "mozcloud-workload.config.gateways" -}}
{{- $globals := .Values.global.mozcloud -}}
{{- $workloads := .workloads }}
gateways:
  {{- range $workload_name, $workload_config := $workloads }}
  {{- range $host_name, $host_config := default (dict) $workload_config.hosts }}
  {{- if not (default false $host_config.disableGateway) }}
  {{ $host_name }}:
    component: {{ $workload_config.component }}
    type: {{ $host_config.type }}
    {{- if ($host_config).multiCluster }}
    className: gke-l7-global-external-managed-mc
    {{- end }}
    addresses:
      {{- if $host_config.addresses }}
      {{- range $address := $host_config.addresses }}
      - {{ $address }}
      {{- end }}
      {{- else }}
      - {{ $globals.app_code }}-{{ $globals.env_code }}-ip-v4
      {{- end }}
    listeners:
      - name: http
        protocol: HTTP
        port: 80
      {{- if eq $host_config.type "external" }}
      - name: https
        protocol: HTTPS
        port: 443
      {{- end }}
    {{- if eq $host_config.type "external" }}
    tls:
      certs:
        {{- if gt (len (default (list) $host_config.tls.certs)) 0 }}
        {{- range $cert := $host_config.tls.certs }}
        - {{ $cert }}
        {{- end }}
        {{- else }}
        - {{ $globals.app_code }}-{{ $globals.realm }}-{{ $globals.env_code }}
        {{- end }}
      type: certmap
    {{- end }}
  {{- end }}
  {{- end }}
  {{- end }}
{{- end -}}

{{/*
HTTPRoute
*/}}
{{- define "mozcloud-workload.config.httpRoutes" -}}
{{- $workloads := .workloads -}}
httpRoutes:
  {{- range $workload_name, $workload_config := $workloads }}
  {{- range $host_name, $host_config := default (dict) $workload_config.hosts }}
  {{- if (($host_config).httpRoutes).createHttpRoutes }}
  {{ $host_name }}:
    component: {{ $workload_config.component }}
    gatewayRefs:
      - name: {{ $host_name }}
        {{- /*
        Uncomment and configure "namespace" line below when switching to shared
        Gateways:

        namespace: <namespace-of-shared-gateway>
        */}}
        {{- if eq $host_config.type "external" }}
        section: https
        {{- else }}
        section: http
        {{- end }}
    hostnames:
      {{- range $domain := $host_config.domains }}
      - {{ $domain | quote }}
      {{- end }}
    {{- if eq $host_config.type "internal" }}
    httpToHttpsRedirect: false
    {{- end }}
      {{/*
      Some tenants might want to pass HTTPRoute rules in from values. A rules Array item
      has a high number of possible combinations of values, so we currently only want to
      support weighted backends here (e.g. for Multi-Cluster Scenarios)
      */}}
    rules:
    {{- if (($host_config).httpRoutes).rules }}
      {{- range $rule := (default (list) $host_config.httpRoutes.rules) }}
      - backendRefs:
          {{- range $backend_ref := (default (list) $rule.backendRefs) }}
          {{- if and $backend_ref.kind (eq $backend_ref.kind "ServiceImport") }}
          {{- $_ := set $backend_ref "group" "net.gke.io" }}
          {{- end }}
          - group: {{ default "" $backend_ref.group | quote }}
            kind: {{ default "Service" $backend_ref.kind }}
            name: {{ $backend_ref.name }}
            port: {{ default 8000 $backend_ref.port }}
            {{- if or (eq (toString $backend_ref.weight) "0") (gt (int $backend_ref.weight) 0) }}
            weight: {{ $backend_ref.weight }}
            {{- end }}
          {{- end }}
      {{- end }}
    {{- else }}
      - backendRefs:
          - name: {{ $workload_name }}
            port: 8080
    {{- end }}
  {{- end }}
  {{- end }}
  {{- end }}
{{- end -}}

{{/*
Ingress resources
*/}}

{{/*
Frontend configs
*/}}
{{- define "mozcloud-workload.config.frontendConfigs" -}}
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
{{- define "mozcloud-workload.config.ingresses" -}}
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
{{- define "mozcloud-workload.config.autoscaling" -}}
{{- $workloads := .workloads -}}
hpas:
  {{- range $workload_name, $workload_config := $workloads }}
  {{- $container := $workload_config.container }}
  {{- if (dig "autoscaling" "enabled" true $container) }}
  {{ $workload_name }}:
    component: {{ $workload_config.component }}
    minReplicas: {{ default 1 (($container.autoscaling).replicas).min }}
    maxReplicas: {{ default 30 (($container.autoscaling).replicas).max }}
    scaleTargetRef:
      {{/*
      The following 3 lines will need to be tweaked when we officially support
      Argo Rollout resources
      */}}
      apiVersion: apps/v1
      kind: Deployment
      name: {{ $workload_name }}
    metrics:
      {{- range $metric := (default (list) ($container.autoscaling).metrics) }}
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
{{- define "mozcloud-workload.config.deployments" -}}
{{- $globals := .Values.global.mozcloud -}}
{{- $workloads := .workloads -}}
deployments:
  {{- range $workload_name, $workload_config := $workloads }}
  {{- $nginx_enabled := true }}
  {{- if or
    (and (hasKey (default (dict) $workload_config.nginx) "enabled") (not ($workload_config.nginx).enabled))
    (not $workload_config.hosts)
  }}
  {{- $nginx_enabled = false }}
  {{- end }}
  {{- $container := $workload_config.container }}
  {{ $workload_name }}:
    component: {{ $workload_config.component }}
    labels:
      {{- range $k, $v := (default (list) ($workload_config.labels)) }}
      {{ $k }}: {{ $v }}
      {{- end }}
    {{- if $container.terminationGracePeriodSeconds }}
    terminationGracePeriodSeconds: {{ $container.terminationGracePeriodSeconds }}
    {{- end }}
    containers:
      - name: {{ default "app" $container.name }}
        {{- if and (not ($container.image).repository) (not ($globals.image).repository) }}
        {{- $fail_message := printf "A fully qualified image path must be configured in either \".Values.mozcloud-workload.workloads.%s.container.image.repository\" or \".Values.global.mozcloud.image.repository\"." $workload_config.component }}
        {{- fail $fail_message }}
        {{- end }}
        image: {{ default ($globals.image).repository ($container.image).repository }}
        {{- if and (not ($container.image).tag) (not ($globals.image).tag) }}
        {{- $fail_message := printf "An image tag must be configured in either \".Values.mozcloud-workload.workloads.%s.container.image.tag\" or \".Values.global.mozcloud.image.tag\"." $workload_config.component }}
        {{- fail $fail_message }}
        {{- end }}
        tag: {{ default ($globals.image).tag ($container.image).tag }}
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
        {{- if $container.envVars }}
        env:
          {{- range $env_key, $env_val := $container.envVars }}
          - name: {{ $env_key }}
            value: {{ $env_val | quote }}
          {{- end }}
        {{- end }}
        envFrom:
          {{- if $container.configMaps }}
          {{- range $config_map := $container.configMaps }}
          - configMapRef:
              name: {{ $config_map }}
          {{- end }}
          {{- end }}
          - secretRef:
              name: {{ $globals.app_code }}-secrets
          {{- if $container.externalSecrets }}
          {{- range $external_secret := $container.externalSecrets }}
          - secretRef:
              name: {{ $external_secret.name }}
          {{- end }}
          {{- end }}
        {{- if (dig "healthCheck" "liveness" "enabled" true $workload_config) }}
        livenessProbe:
          httpGet:
            {{- if (($workload_config.healthCheck).liveness).httpHeaders }}
            httpHeaders:
              {{- range $header := $workload_config.healthCheck.liveness.httpHeaders }}
              - name: {{ $header.name }}
                value: {{ $header.value }}
              {{- end }}
            {{- else if (($workload_config.healthCheck).readiness).httpHeaders }}
            httpHeaders:
              {{- range $header := $workload_config.healthCheck.readiness.httpHeaders }}
              - name: {{ $header.name }}
                value: {{ $header.value }}
              {{- end }}
            {{- end }}
            path: {{ default "/__lbheartbeat__" $workload_config.healthCheck.liveness.path }}
            port: app
          {{- if (($workload_config.healthCheck).liveness).probes }}
          {{- range $k, $v := $workload_config.healthCheck.liveness.probes }}
          {{ $k }}: {{ $v }}
          {{- end }}
          {{- else if (($workload_config.healthCheck).readiness).probes }}
          {{- range $k, $v := $workload_config.healthCheck.readiness.probes }}
          {{ $k }}: {{ $v }}
          {{- end }}
          {{- end }}
        {{- end }}
        {{- if (dig "healthCheck" "readiness" "enabled" true $workload_config) }}
        readinessProbe:
          httpGet:
            {{- if (($workload_config.healthCheck).readiness).httpHeaders }}
            httpHeaders:
              {{- range $header := $workload_config.healthCheck.readiness.httpHeaders }}
              - name: {{ $header.name }}
                value: {{ $header.value }}
              {{- end }}
            {{- end }}
            path: {{ default "/__lbheartbeat__" $workload_config.healthCheck.readiness.path }}
            port: app
          {{- if (($workload_config.healthCheck).readiness).probes }}
          {{- range $k, $v := $workload_config.healthCheck.readiness.probes }}
          {{ $k }}: {{ $v }}
          {{- end }}
          {{- end }}
        {{- end }}
        {{- if or
            $workload_config.hosts
            (($workload_config.healthCheck).readiness).enabled
            (($workload_config.healthCheck).liveness).enabled
        }}
        ports:
          - name: app
            containerPort: {{ $container.port }}
        {{- end }}
        resources:
          requests:
            cpu: {{ $container.resources.cpu }}
            memory: {{ $container.resources.memory }}
        {{- if or ($container.security).uid ($container.security).gid ($container.security).addCapabilities }}
        securityContext:
          {{- $security_context := include "mozcloud-workload.config.securityContext" $container.security | fromYaml }}
          uid: {{ $security_context.user }}
          gid: {{ $security_context.group }}
          {{- if gt (len $container.security.addCapabilities) 0 }}
          addCapabilities:
            {{- range $capability := $container.security.addCapabilities }}
            - {{ $capability }}
            {{- end }}
          {{- end }}
        {{- end }}
        {{- if $container.volumes }}
        volumes:
          {{- $container.volumes | toYaml | nindent 10 }}
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
    {{- if and (($workload_config.otel).autoInstrumentation).enabled (($workload_config.otel).autoInstrumentation).language }}
    otel:
      {{- $workload_config.otel | toYaml | nindent 6 }}
    {{- end }}
    {{- if ($container.security).runAsRoot }}
    securityContext:
      runAsNonRoot: false
    {{- end }}
    {{- if ($container.serviceAccount).name }}
    serviceAccount: {{ $container.serviceAccount.name }}
    {{- else }}
    serviceAccount: {{ $globals.app_code }}
    {{- end }}
    strategy: {{ $container.strategy }}
{{- end }}
{{- end -}}

{{/*
External secrets
*/}}
{{- define "mozcloud-workload.config.externalSecrets" -}}
{{- $globals := .Values.global.mozcloud -}}
{{- $workloads := .workloads -}}
externalSecrets:
  {{- $default_secret_name := printf "%s-secrets" $globals.app_code }}
  {{ $default_secret_name }}:
    {{- /*
    ConfigMaps, ExternalSecrets, and ServiceAccounts should be updated before all
    other resources
    */}}
    argo:
      syncWave: -11
    target: {{ $globals.app_code }}-secrets
    gsm:
      secret: {{ .Values.global.mozcloud.env_code }}-gke-app-secrets
  {{- range $workload_name, $workload_config := $workloads }}
  {{- $external_secrets := include "mozcloud-workload.formatter.externalSecrets" $workload_config | fromYaml }}
  {{- range $external_secret := $external_secrets.secrets }}
  {{- if (default true $external_secret.create) }}
  {{- $k8s_secret_name := default $external_secret.name $external_secret.k8sSecretName }}
  {{ $k8s_secret_name }}:
    component: {{ $workload_config.component }}
    {{- /*
    ConfigMaps, ExternalSecrets, and ServiceAccounts should be updated before all
    other resources
    */}}
    argo:
      syncWave: -11
    target: {{ $k8s_secret_name }}
    gsm:
      secret: {{ $external_secret.name }}
      version: {{ default "latest" $external_secret.version }}
  {{- end }}
  {{- end }}
  {{- end }}
{{- end -}}

{{/*
Pod monitorings
*/}}
{{- define "mozcloud-workload.config.podMonitorings" -}}
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
{{- define "mozcloud-workload.config.securityContext" -}}
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
Service accounts
*/}}
{{- define "mozcloud-workload.config.serviceAccounts" -}}
{{- $globals := .Values.global.mozcloud -}}
{{- $workloads := .workloads -}}
serviceAccounts:
  {{- range $workload_name, $workload_config := $workloads }}
  {{ $globals.app_code }}:
    component: serviceaccount
    {{- /*
    ConfigMaps, ExternalSecrets, and ServiceAccounts should be updated before all
    other resources
    */}}
    argo:
      syncWave: -11
    gcpServiceAccount:
      name: gke-{{ $globals.env_code }}
      projectId: {{ $globals.project_id }}
  {{- $service_accounts := include "mozcloud-workload.formatter.serviceAccounts" (dict "workload" $workload_config) | fromYaml }}
  {{- range $service_account_name, $service_account_config := $service_accounts.serviceAccounts }}
  {{- if not (eq $service_account_name $globals.app_code) }}
  {{ $service_account_name }}:
    component: {{ $workload_config.component }}
    {{- /*
    ConfigMaps, ExternalSecrets, and ServiceAccounts should be updated before all
    other resources
    */}}
    argo:
      syncWave: -11
    {{- if ($service_account_config.gcpServiceAccount).name }}
    gcpServiceAccount:
      name: {{ $service_account_config.gcpServiceAccount.name }}
      {{- if ($service_account_config.gcpServiceAccount).projectId }}
      projectId: {{ default $globals.project_id $service_account_config.gcpServiceAccount.projectId }}
      {{- end }}
    {{- end }}
  {{- end }}
  {{- end }}
  {{- end }}
{{- end }}

{{/*
Job resources
*/}}
{{- define "mozcloud-workload.config.jobs" -}}
{{- $globals := .Values.global.mozcloud -}}
{{- $job_type := .jobType -}}
{{- $workloads := .workloads -}}
jobs:
  {{- range $workload_name, $workload_config := $workloads }}
  {{- $job_list := list }}
  {{- range $job_name, $job_config := default (dict) (index (default (dict) $workload_config.jobs) $job_type) }}
  {{- /* Check if job name is "name" and replace if so */}}
  {{- $name := $job_name }}
  {{- if eq $name "name" -}}
  {{- $name := printf "%s-%s" $workload_name ($job_type | lower) }}
  {{- end }}
  {{- /* Ensure job names are unique */}}
  {{- if not (has $name $job_list) }}
  {{ $name }}:
    component: {{ $workload_config.component }}
    argo:
      {{- $sync_wave := "" }}
      {{- if eq $job_type "preDeployment" }}
      {{- $sync_wave = "-1" }}
      {{- if ($job_config.argo).syncWave }}
      {{- $configured_wave := $job_config.argo.syncWave | int }}
      {{- if and (gt $configured_wave -11) (lt $configured_wave 0) }}
      {{- $sync_wave = $configured_wave | toString }}
      {{- end }}
      {{- end }}
      {{- else if eq $job_type "postDeployment" }}
      {{- $sync_wave = "1" }}
      {{- if ($job_config.argo).syncWave }}
      {{- $configured_wave := $job_config.argo.syncWave | int }}
      {{- if gt $configured_wave 0 }}
      {{- $sync_wave = $configured_wave | toString }}
      {{- end }}
      {{- end }}
      {{- end }}
      syncWave: {{ $sync_wave }}
    containers:
      - name: {{ default "job" $job_config.containerName }}
        image:
          repository: {{ default ($globals.image).repository ($job_config.image).repository }}
          tag: {{ default "latest" (default (($globals.image).tag) ($job_config.image).tag) }}
        {{- if $job_config.command }}
        command:
          {{- range $line := $job_config.command }}
          - {{ $line | quote }}
          {{- end }}
        {{- end }}
        {{- if $job_config.args }}
        args:
          {{- range $line := $job_config.args }}
          - {{ $line | quote }}
          {{- end }}
        {{- end }}
        {{- if or
          ($job_config.envVars).customVars
          (default true ($job_config.envVars).useAppEnvVars)
        }}
        {{- $merged_vars := mergeOverwrite
          (default (dict) $workload_config.container.envVars)
          (default (dict) ($job_config.envVars).customVars)
        }}
        env:
          {{- range $env_var_key, $env_var_val := $merged_vars }}
          - name: {{ $env_var_key }}
            value: {{ $env_var_val }}
          {{- end }}
        {{- end }}
        {{- if or
          $job_config.configMaps
          (not (default false ($job_config.externalSecrets).disableAppExternalSecrets))
          ($job_config.externalSecrets).customExternalSecrets
        }}
        envFrom:
          {{- if $job_config.configMaps }}
          configMaps:
            {{- range $config_map := $job_config.configMaps }}
            - {{ $config_map }}
            {{- end }}
          {{- end }}
          {{- if or
            (not (default false ($job_config.externalSecrets).disableAppExternalSecrets))
            ($job_config.externalSecrets).customExternalSecrets
          }}
          secrets:
            - {{ $globals.app_code }}-secrets
            {{- range $external_secret := default (list) $workload_config.container.externalSecrets }}
            - {{ $external_secret.name }}
            {{- end }}
            {{- range $external_secret := default (list) ($job_config.externalSecrets).customExternalSecrets }}
            - {{ $external_secret.name }}
            {{- end }}
          {{- end }}
        {{- end }}
        {{- if or ($job_config.resources).cpu ($job_config.resources).memory }}
        resources:
          requests:
          {{- if ($job_config.resources).cpu }}
            cpu: {{ $job_config.resources.cpu }}
          {{- end }}
          {{- if ($job_config.resources).memory }}
            memory: {{ $job_config.resources.memory }}
          {{- end }}
        {{- end }}
    {{- if or ($job_config.serviceAccount).useAppServiceAccount (($job_config.serviceAccount).customServiceAccount).name }}
    config:
      serviceAccount:
        {{- if ($job_config.serviceAccount).useAppServiceAccount }}
        name: {{ default $globals.app_code ($workload_config.container.serviceAccount).name }}
        {{- else }}
        name: {{ $job_config.serviceAccount.customServiceAccount.name }}
        {{- end }}
    {{- end }}
  {{- $job_list = append $job_list $name }}
  {{- end }}
  {{- end }}
  {{- end }}
{{- end -}}

{{/*
Formatting helpers
*/}}
{{- define "mozcloud-workload.formatter.host" -}}
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

{{- define "mozcloud-workload.formatter.externalSecrets" -}}
{{- $secrets := dict -}}
{{- $workload := .workload -}}
{{- /* First, pull secrets from workload */ -}}
{{- range $workload_secret := default (list) $workload.externalSecrets -}}
  {{- if not hasKey $secrets $workload_secret.name -}}
    {{- $_ := set $secrets $workload_secret.name $workload_secret.version -}}
  {{- end -}}
{{- end -}}
{{- /* Next, pull secrets from jobs */ -}}
{{- range $job_type := list "preDeployment" "postDeployment" -}}
  {{- $jobs := default (dict) $workload.jobs -}}
  {{- if index $jobs $job_type -}}
    {{- $job := index $workload.jobs $job_type -}}
    {{- $job_secrets := default (list) ($job.externalSecrets).customExternalSecrets -}}
    {{- range $job_secret := $job_secrets -}}
      {{- if not hasKey $secrets $job_secret.name -}}
        {{- $_ := set $secrets $job_secret.name $job_secret.version -}}
      {{- end -}}
    {{- end -}}
  {{- end -}}
{{- end -}}
{{- /* Finally, reformat back into the expected format for the parent function */ -}}
secrets:
  {{- range $secret_name, $secret_version := $secrets }}
  - name: {{ $secret_name }}
    version: {{ $secret_version }}
  {{- end }}
{{- end -}}

{{- define "mozcloud-workload.formatter.serviceAccounts" -}}
{{- $service_accounts := dict -}}
{{- $container := .workload.container -}}
{{- /* First, pull service accounts from workload */ -}}
{{- if ($container.serviceAccount).create -}}
  {{- $_ := set $service_accounts $container.serviceAccount.name $container.serviceAccount -}}
{{- end -}}
{{- /* Next, pull service accounts from jobs */ -}}
{{- range $job_type := list "preDeployment" "postDeployment" -}}
  {{- $jobs := default (dict) $container.jobs -}}
  {{- if index $jobs $job_type -}}
    {{- $job := index $container.jobs $job_type -}}
    {{- if and (($job.serviceAccount).customServiceAccount).create (not hasKey (($job.serviceAccount).customServiceAccount).name $service_accounts) -}}
      {{- $_ := set $service_accounts $job.serviceAccount.customServiceAccount.name $job.serviceAccount.customServiceAccount -}}
    {{- end -}}
  {{- end -}}
{{- end -}}
{{- /* Finally, reformat back into the expected format for the parent function */ -}}
serviceAccounts:
  {{- $service_accounts | toYaml | nindent 2 }}
{{- end -}}

{{- define "mozcloud-workload.formatter.workloads" -}}
{{- $component := .component -}}
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
      If we are working with a Gateway or Ingress template, we will want to
      filter out hosts that are not set to the correct API type
      */ -}}
      {{- if or (eq $component "gateway") (eq $component "ingress") -}}
        {{- $helper_params := dict "component" $component "hosts" $hosts "workloadName" $name -}}
        {{- $hosts = include "mozcloud-workload.formatter.host" $helper_params | fromYaml -}}
      {{- end -}}
      {{- $_ := set $config "hosts" $hosts -}}
    {{- end -}}
    {{- $defaults := omit $default_workload "hosts" -}}
    {{- $_ := set $workloads $name (mergeOverwrite ($defaults | deepCopy) $config) -}}
  {{- end -}}
{{- end -}}
{{- range $name, $config := $workloads -}}
  {{- if not $config.component -}}
    {{- $fail_message := printf "A component was not defined for workload \"%s\". You must define a component in \".Values.mozcloud-workload.workloads.%s.component\". See values.yaml in the mozcloud-workload chart for more details." $name $name -}}
    {{- fail $fail_message -}}
  {{- end -}}
{{- end -}}
{{ $workloads | toYaml }}
{{- end -}}

{{/*
Defaults
*/}}

{{/*
Debug helper
*/}}
{{- define "mozcloud-workload.debug" -}}
{{- . | mustToPrettyJson | printf "\nThe JSON output of the dumped var is: \n%s" | fail }}
{{- end -}}
