{{- /*
Expands to the chart name, using .Values.nameOverride if set. The result is
truncated to 63 characters and any trailing hyphen is removed to comply with
Kubernetes DNS naming requirements.

Params:
  . (dict): (required) The Helm root context.

Returns:
  (string) The chart name.
*/ -}}
{{- define "mozcloud.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}


{{- /*
Creates a fully qualified app name for use in resource metadata. If preview
mode is active, a PR-based prefix (e.g. "pr123-") is prepended. Resolution
order:
  1. .Values.fullnameOverride — used directly if set.
  2. Release name — used as-is if it already contains the chart name.
  3. "<release>-<chart>" — combined if the release name does not include the
     chart name.
The result is truncated to 63 characters and any trailing hyphen is removed.

Params:
  . (dict): (required) The Helm root context.

Returns:
  (string) The fully qualified app name.
*/ -}}
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


{{- /*
Creates a chart name and version string for use in the "helm.sh/chart" label.
The "+" character in the version string is replaced with "_" for label
compatibility, and the result is truncated to 63 characters.

Params:
  . (dict): (required) The Helm root context.

Returns:
  (string) A chart name-version string (e.g. "my-chart-1.2.3").
*/ -}}
{{- define "mozcloud.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}


{{- /*
Produces an RFC 6335-compliant port name from an arbitrary string. Lowercases
the input, replaces any character that is not a letter, digit, or hyphen with a
hyphen, truncates to 15 characters, and strips any trailing hyphen.

Note: regexReplaceAll takes (regex, inputString, replacement) — the input must
be passed as an explicit argument, not via pipeline, to avoid it being treated
as the replacement value.

Params:
  . (string): (required) The source string (e.g. a container name).

Returns:
  (string) An RFC 6335-compliant port name.
*/ -}}
{{- define "mozcloud.portName" -}}
{{- $s := . | toString | lower -}}
{{- regexReplaceAll "[^a-z0-9-]" $s "-" | trunc 15 | trimSuffix "-" -}}
{{- end }}


{{- /*
A debug utility that serializes the piped-in value as pretty-printed JSON and
immediately fails the template render with that output as the error message.
Use this to inspect any Helm variable or context dict during template
development.

Params:
  . (any): (required) The value to serialize and dump.

Returns:
  Never returns — always fails with the JSON-serialized value as the error
  message.
*/ -}}
{{- /*
Resolves and renders a fully qualified container image string (repository:tag).

Resolution order for both repository and tag:
  1. Container-level image config (per-workload override).
  2. Global image config (.Values.global.mozcloud.image).
  3. Fail with a descriptive error if neither is set.

If globalImage.registry is set, it is prepended to the resolved repository
as "registry/repository" — unless the repository already starts with the
registry value (to avoid double-prefixing).

Params:
  containerImage (dict): The container-level image config (image.repository, image.tag).
  globalImage    (dict): The global image config (.Values.global.mozcloud.image).
  workloadName   (string): Name of the workload (for error messages).
  containerName  (string): Name of the container (for error messages).

Returns:
  (string) A fully qualified image reference, e.g. "registry/repo:tag".
*/ -}}
{{- define "mozcloud.image" -}}
{{- $containerImage := default dict .containerImage }}
{{- $globalImage := default dict .globalImage }}
{{- $workloadName := .workloadName }}
{{- $containerName := .containerName }}
{{- $repo := default ($globalImage.repository) ($containerImage.repository) }}
{{- if not $repo }}
  {{- fail (printf "Container image repository must be set for workload %q container %q. Set .Values.mozcloud.workloads.%s.containers.%s.image.repository or .Values.global.mozcloud.image.repository." $workloadName $containerName $workloadName $containerName) }}
{{- end }}
{{- $tag := default ($globalImage.tag) ($containerImage.tag) }}
{{- if not $tag }}
  {{- fail (printf "Container image tag must be set for workload %q container %q. Set .Values.mozcloud.workloads.%s.containers.%s.image.tag or .Values.global.mozcloud.image.tag." $workloadName $containerName $workloadName $containerName) }}
{{- end }}
{{- $registry := default ($globalImage.registry) ($containerImage.registry) | default "" }}
{{- if and $registry (not (hasPrefix $registry $repo)) }}
  {{- $repo = printf "%s/%s" $registry $repo }}
{{- end }}
{{- printf "%s:%s" $repo $tag }}
{{- end }}


{{- define "mozcloud.debug" -}}
{{- . | mustToPrettyJson | printf "\nThe JSON output of the dumped var is: \n%s" | fail }}
{{- end -}}
