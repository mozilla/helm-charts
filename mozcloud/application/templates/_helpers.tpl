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
{{- define "mozcloud.debug" -}}
{{- . | mustToPrettyJson | printf "\nThe JSON output of the dumped var is: \n%s" | fail }}
{{- end -}}
