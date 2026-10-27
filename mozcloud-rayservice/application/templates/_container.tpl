{{- /*
Builds the resources block for a single container. cpu/memory are requests;
limits default to 2x the request value unless resources.limits overrides
them. Mirrors mozcloud's pod.container.resources validation.

CPU validation: accepts integer, float (whole CPUs), or millicpu notation
(e.g. "250m"). Decimal millicpu limits are rounded up using ceil to produce a
valid integer millicpu string (e.g. "1.5m" -> "2m").

Memory validation: requires a positive number with one of the following unit
suffixes: K, Ki, M, Mi, G, Gi.

Params:
  . (dict): the container's "resources" config (cpu, memory, limits). limits
            may also carry any other Kubernetes resource name (eg. to add
            nvidia.com/gpu); only cpu/memory get a computed default.

Returns:
  (string) YAML for a Kubernetes ResourceRequirements object.
*/ -}}
{{- define "mozcloud-rayservice.container.resources" -}}
{{- $resources := default dict . -}}
{{- $limits := default dict $resources.limits -}}
{{- $out := dict "requests" (dict "cpu" $resources.cpu "memory" $resources.memory) "limits" $limits -}}
{{- /* Validate CPU requests and limits */ -}}
{{- $requestSuffix := "" -}}
{{- $request := $resources.cpu | toString -}}
{{- if hasSuffix "m" $request -}}
  {{- $requestSuffix = "m" }}
  {{- $request = trimSuffix "m" $request -}}
{{- end -}}
{{- if and (not $requestSuffix) (or (regexFind "[a-zA-Z]$" $request) (le (float64 $request) 0.0)) -}}
  {{- fail "CPU requests must be positive and use one of the following formats: int, float, or millicpu notation (eg. 100m)" -}}
{{- end -}}
{{- if $limits.cpu -}}
  {{- $limitSuffix := "" -}}
  {{- $limit := $limits.cpu | toString -}}
  {{- if hasSuffix "m" $limit -}}
    {{- $limitSuffix = "m" }}
    {{- $limit = trimSuffix "m" $limit -}}
  {{- end -}}
  {{- if and (not $limitSuffix) (or (regexFind "[a-zA-Z]$" $limit) (le (float64 $limit) 0.0)) -}}
    {{- fail "CPU limits must be positive and use one of the following formats: int, float, or millicpu notation (eg. 100m)" -}}
  {{- end -}}
  {{- if or $limitSuffix (eq (float64 $limit) (floor (float64 $limit))) -}}
    {{- $limit = ceil (float64 $limit) -}}
    {{- $_ := set $out.limits "cpu" (printf "%d%s" (int $limit) $limitSuffix) -}}
  {{- end -}}
{{- else -}}
  {{- $limit := "" -}}
  {{- if or $requestSuffix (eq (float64 $request) (floor (float64 $request))) -}}
    {{- $request = ceil (float64 $request) -}}
    {{- $_ := set $out.requests "cpu" (printf "%d%s" (int $request) $requestSuffix) -}}
    {{- $limit = printf "%d%s" (mul 2 (int $request)) $requestSuffix -}}
  {{- else -}}
    {{- $limit = printf "%.3f" (mulf 2 (float64 $request)) -}}
  {{- end -}}
  {{- $_ := set $out.limits "cpu" $limit -}}
{{- end -}}
{{- /* Validate memory requests and limits */ -}}
{{- $unitPattern := "(K|Ki|M|Mi|G|Gi)$" -}}
{{- $request = $resources.memory | toString -}}
{{- $requestSuffix = regexFind $unitPattern $request -}}
{{- $request = trimSuffix $requestSuffix $request -}}
{{- if or (not $requestSuffix) (le (float64 $request) 0.0) -}}
  {{- fail "Memory requests must be positive and use one of the following unit types: K, Ki, M, Mi, G, Gi" -}}
{{- end -}}
{{- if $limits.memory -}}
  {{- $limit := $limits.memory | toString -}}
  {{- $limitSuffix := regexFind $unitPattern $limit -}}
  {{- $limit = trimSuffix $limitSuffix $limit -}}
  {{- if or (not $limitSuffix) (le (float64 $limit) 0.0) -}}
    {{- fail "Memory limits must be positive and use one of the following unit types: K, Ki, M, Mi, G, Gi" -}}
  {{- end -}}
{{- else -}}
  {{- $limit := "" -}}
  {{- if eq (float64 $request) (floor (float64 $request)) -}}
    {{- $limit = printf "%d%s" (mul 2 (int $request)) $requestSuffix -}}
  {{- else -}}
    {{- $limit = printf "%.3f%s" (mulf 2 (float64 $request)) $requestSuffix -}}
  {{- end -}}
  {{- $_ := set $out.limits "memory" $limit -}}
{{- end -}}
{{- $out | toYaml -}}
{{- end -}}

{{- /*
Merges a container's securityContext override over MozCloud's container-level
baseline.
*/ -}}
{{- define "mozcloud-rayservice.container.securityContext" -}}
{{- $default := dict "allowPrivilegeEscalation" false "capabilities" (dict "drop" (list "ALL")) "seccompProfile" (dict "type" "RuntimeDefault") -}}
{{- mergeOverwrite $default (default dict .) | toYaml -}}
{{- end -}}

{{- /*
Merges a pod's securityContext override over MozCloud's PSS-restricted
baseline.
*/ -}}
{{- define "mozcloud-rayservice.podSecurityContext" -}}
{{- $default := dict "runAsNonRoot" true "runAsUser" 10001 "runAsGroup" 10001 "seccompProfile" (dict "type" "RuntimeDefault") -}}
{{- mergeOverwrite $default (default dict .) | toYaml -}}
{{- end -}}

{{- /*
Renders a single container.

Params:
  name (string): the container name.
  config (dict):  the container config (image, env, resources, ...).
*/ -}}
{{- define "mozcloud-rayservice.container" -}}
{{- $config := .config -}}
- name: {{ .name }}
  image: {{ printf "%s:%s" $config.image.repository $config.image.tag }}
  imagePullPolicy: {{ default "Always" $config.image.pullPolicy }}
  {{- with $config.command }}
  command:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with $config.args }}
  args:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with $config.env }}
  env:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with $config.envFrom }}
  envFrom:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with $config.ports }}
  ports:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  resources:
    {{- include "mozcloud-rayservice.container.resources" $config.resources | nindent 4 }}
  securityContext:
    {{- include "mozcloud-rayservice.container.securityContext" $config.securityContext | nindent 4 }}
  {{- with $config.lifecycle }}
  lifecycle:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- $liveness := ($config.healthCheck).liveness }}
  {{- if and $liveness $liveness.enabled }}
  livenessProbe:
    httpGet:
      path: {{ $liveness.path }}
      port: {{ $liveness.port }}
    initialDelaySeconds: {{ default 10 $liveness.initialDelaySeconds }}
    periodSeconds: {{ default 10 $liveness.periodSeconds }}
    timeoutSeconds: {{ default 5 $liveness.timeoutSeconds }}
    successThreshold: {{ default 1 $liveness.successThreshold }}
    failureThreshold: {{ default 3 $liveness.failureThreshold }}
  {{- end }}
  {{- $readiness := ($config.healthCheck).readiness }}
  {{- if and $readiness $readiness.enabled }}
  readinessProbe:
    httpGet:
      path: {{ $readiness.path }}
      port: {{ $readiness.port }}
    initialDelaySeconds: {{ default 10 $readiness.initialDelaySeconds }}
    periodSeconds: {{ default 10 $readiness.periodSeconds }}
    timeoutSeconds: {{ default 5 $readiness.timeoutSeconds }}
    successThreshold: {{ default 1 $readiness.successThreshold }}
    failureThreshold: {{ default 3 $readiness.failureThreshold }}
  {{- end }}
{{- end -}}

{{- /*
Renders the "spec:" body of a Ray pod template: containers, pod-level
securityContext, serviceAccountName, and placement.

Params:
  serviceAccountName (string)
  podSecurityContext (dict)
  containers (dict): containers keyed by name.
  placement (dict): affinity, nodeSelector, tolerations,
                     topologySpreadConstraints.
*/ -}}
{{- define "mozcloud-rayservice.podSpec" -}}
spec:
  serviceAccountName: {{ .serviceAccountName }}
  securityContext:
    {{- include "mozcloud-rayservice.podSecurityContext" .podSecurityContext | nindent 4 }}
  containers:
    {{- range $name, $config := .containers }}
    {{- include "mozcloud-rayservice.container" (dict "name" $name "config" $config) | nindent 4 }}
    {{- end }}
  {{- with (.placement).affinity }}
  affinity:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with (.placement).nodeSelector }}
  nodeSelector:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with (.placement).tolerations }}
  tolerations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with (.placement).topologySpreadConstraints }}
  topologySpreadConstraints:
    {{- toYaml . | nindent 4 }}
  {{- end }}
{{- end -}}

{{- /*
Renders a full Ray pod "template:" (metadata + spec) for the head or a worker
group.

Params:
  workload (dict): the workload config (serviceAccountName,
                    podSecurityContext, annotations).
  containers (dict): this pod's containers, keyed by name.
  placement (dict): affinity, nodeSelector, tolerations,
                     topologySpreadConstraints for this pod.
  labels (dict): precomputed MozCloud labels, shared with the RayService
                 object itself.
*/ -}}
{{- define "mozcloud-rayservice.podTemplate" -}}
template:
  metadata:
    labels:
      {{- .labels | toYaml | nindent 6 }}
    {{- with .workload.annotations }}
    annotations:
      {{- toYaml . | nindent 6 }}
    {{- end }}
  {{- include "mozcloud-rayservice.podSpec" (dict
        "serviceAccountName" .workload.serviceAccountName
        "podSecurityContext" .workload.podSecurityContext
        "containers" .containers
        "placement" .placement
      ) | nindent 2 }}
{{- end -}}
