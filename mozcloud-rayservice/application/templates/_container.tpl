{{- /*
Builds the resources block for a single container. cpu/memory are requests;
limits default to the same values unless resources.limits overrides them.

Params:
  . (dict): the container's "resources" config (cpu, memory, limits).

Returns:
  (string) YAML for a Kubernetes ResourceRequirements object.
*/ -}}
{{- define "mozcloud-rayservice.container.resources" -}}
{{- $resources := default dict . -}}
{{- $requests := dict -}}
{{- if $resources.cpu }}{{- $_ := set $requests "cpu" $resources.cpu -}}{{- end -}}
{{- if $resources.memory }}{{- $_ := set $requests "memory" $resources.memory -}}{{- end -}}
{{- $out := dict -}}
{{- if $requests }}{{- $_ := set $out "requests" $requests -}}{{- end -}}
{{- if $resources.limits -}}
  {{- $_ := set $out "limits" $resources.limits -}}
{{- else if $requests -}}
  {{- $_ := set $out "limits" $requests -}}
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
