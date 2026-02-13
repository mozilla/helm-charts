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
{{- if (.Values).fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name (.Values).nameOverride }}
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
{{- define "mozcloud.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

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
{{- $params | toYaml }}
{{- end }}

{{/*
Template helpers
*/}}

{{/*
ConfigMaps
*/}}
{{- define "mozcloud.config.configMap" -}}
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
{{- define "mozcloud.config.backends" -}}
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
{{- define "mozcloud.config.gatewayPolicy" -}}
sslPolicy: mozilla-intermediate
{{- end -}}

{{/*
Gateways
*/}}
{{- define "mozcloud.config.gateways" -}}
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
{{- define "mozcloud.config.httpRoutes" -}}
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
deployments:
  {{- range $workload_name, $workload_config := $workloads }}
  {{- $nginx_enabled := true }}
  {{- if or
    (and (hasKey (default (dict) $workload_config.nginx) "enabled") (not ($workload_config.nginx).enabled))
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
              name: {{ $globals.app_code }}-secrets
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
              name: {{ $globals.app_code }}-secrets
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
    serviceAccount: {{ default $globals.app_code $workload_config.serviceAccount }}
    strategy: {{ $workload_config.strategy }}
{{- end }}
{{- end -}}

{{/*
External secrets
*/}}
{{- define "mozcloud.config.externalSecrets" -}}
{{- $globals := .Values.global.mozcloud -}}
{{- $external_secrets := default (dict) .Values.externalSecrets -}}
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
  {{- range $secret_name, $secret_config := $external_secrets }}
  {{ $secret_name }}:
    {{- /*
    ConfigMaps, ExternalSecrets, and ServiceAccounts should be updated before all
    other resources
    */}}
    argo:
      syncWave: -11
    target: {{ $secret_name }}
    gsm:
      secret: {{ $secret_config.gsmSecretName }}
      version: {{ default "latest" $secret_config.version }}
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
Service accounts
*/}}
{{- define "mozcloud.config.serviceAccounts" -}}
{{- $globals := .Values.global.mozcloud -}}
{{- $service_accounts := default (dict) .Values.serviceAccounts -}}
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
  {{- range $service_account_name, $service_account_config := $service_accounts }}
  {{- if not (eq $service_account_name $globals.app_code) }}
  {{ $service_account_name }}:
    {{- /*
    ConfigMaps, ExternalSecrets, and ServiceAccounts should be updated before all
    other resources
    */}}
    argo:
      syncWave: -11
    {{- if ($service_account_config.gcpServiceAccount).name }}
    gcpServiceAccount:
      name: {{ $service_account_config.gcpServiceAccount.name }}
      projectId: {{ default $globals.project_id $service_account_config.gcpServiceAccount.projectId }}
    {{- end }}
  {{- end }}
  {{- end }}
  {{- end }}
{{- end }}

{{/*
Job resources
*/}}
{{- define "mozcloud.config.jobs" -}}
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
        {{- if $job_config.envVars }}
        env:
          {{- range $env_var_key, $env_var_val := $job_config.envVars }}
          - name: {{ $env_var_key }}
            value: {{ $env_var_val }}
          {{- end }}
        {{- end }}
        {{- if or
          $job_config.configMaps
          $job_config.externalSecrets
        }}
        envFrom:
          {{- if $job_config.configMaps }}
          configMaps:
            {{- range $config_map := $job_config.configMaps }}
            - {{ $config_map }}
            {{- end }}
          {{- end }}
          {{- if $job_config.externalSecrets }}
          secrets:
            {{- range $external_secret := default (list) $job_config.externalSecrets }}
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
    {{- if $workload_config.serviceAccount }}
    config:
      serviceAccount:
        name: {{ $workload_config.serviceAccount }}
    {{- end }}
  {{- $job_list = append $job_list $name }}
  {{- end }}
  {{- end }}
  {{- end }}
{{- end -}}

{{/*
Persistent volume claims
*/}}
{{- define "mozcloud.config.persistentVolumes" -}}
{{- $globals := .Values.global.mozcloud -}}
{{- $workloads := .workloads -}}
persistentVolumes:
  {{- range $workload_name, $workload_config := $workloads }}
  {{- $volumes := include "mozcloud.formatter.volumes" (dict "workload" $workload_config) | fromYaml }}
  {{- range $volume_name, $volume_config := $volumes.volumes }}
  {{- if and (eq $volume_config.type "persistentVolumeClaim") $volume_config.create }}
  {{ $volume_name }}:
    component: {{ $workload_config.component }}
    size: {{ $volume_config.size }}
    storageClassName: {{ $volume_config.storageClassName }}
    accessModes: 
    {{ $volume_config.accessModes | toYaml | nindent 6 }}
  {{- end }}
  {{- end }}
  {{- end }}
{{- end }}

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
        {{- $hosts = include "mozcloud.formatter.host" $helper_params | fromYaml -}}
      {{- end -}}
      {{- $_ := set $config "hosts" $hosts -}}
    {{- end -}}
    {{- $defaults := omit $default_workload "hosts" -}}
    {{- $_ := set $workloads $name (mergeOverwrite ($defaults | deepCopy) $config) -}}
  {{- end -}}
{{- end -}}
{{- range $name, $config := $workloads -}}
  {{- if not $config.component -}}
    {{- $fail_message := printf "A component was not defined for workload \"%s\". You must define a component in \".Values.mozcloud.workloads.%s.component\". See values.yaml in the mozcloud-workload chart for more details." $name $name -}}
    {{- fail $fail_message -}}
  {{- end -}}
{{- end -}}
{{ $workloads | toYaml }}
{{- end -}}

{{/* Volume config formatter */}}
{{- define "mozcloud.formatter.volumes" -}}
{{- $volumes := dict -}}
{{- $workload := .workload -}}
{{- /* First, pull volumes from workload containers */ -}}
{{- $formatter_params := dict "containers" $workload.containers "type" "containers" -}}
{{- $containers := include "common.formatter.containers" $formatter_params | fromYaml -}}
{{- range $container_name, $container_config := $containers -}}
  {{- range $container_volume := default (list) $container_config.volumes -}}
    {{- if not (hasKey $volumes $container_volume.name) -}}
      {{- $_ := set $volumes $container_volume.name $container_volume -}}
    {{- end -}}
  {{- end -}}
{{- end -}}
{{- /* Next, pull volumes from workload init containers, if any */ -}}
{{- if $workload.initContainers -}}
  {{- $formatter_params = dict "containers" $workload.containers "type" "containers" -}}
  {{- $containers = include "common.formatter.containers" $formatter_params | fromYaml -}}
  {{- range $container_name, $container_config := $containers -}}
    {{- range $container_volume := default (list) $container_config.volumes -}}
      {{- if not (hasKey $volumes $container_volume.name) -}}
        {{- $_ := set $volumes $container_volume.name $container_volume -}}
      {{- end -}}
    {{- end -}}
  {{- end -}}
{{- end -}}
{{- /* Next, pull volumes from jobs */ -}}
{{- range $job_type := list "preDeployment" "postDeployment" -}}
  {{- $jobs := default (dict) $workload.jobs -}}
  {{- if index $jobs $job_type -}}
    {{- $job := index $workload.jobs $job_type -}}
    {{- $job_volumes := default (list) ($job.volumes) -}}
    {{- range $job_volume := $job_volumes -}}
      {{- if not (hasKey $volumes $job_volume.name) -}}
        {{- $_ := set $volumes $job_volume.name $job_volume -}}
      {{- end -}}
    {{- end -}}
  {{- end -}}
{{- end -}}
{{- /* Finally, reformat back into the expected format for the parent function */ -}}
volumes:
  {{- $volumes | toYaml | nindent 2 }}
{{- end -}}

{{/*
Defaults
*/}}

{{/*
Debug helper
*/}}
{{- define "debug" -}}
{{- . | mustToPrettyJson | printf "\nThe JSON output of the dumped var is: \n%s" | fail }}
{{- end -}}
