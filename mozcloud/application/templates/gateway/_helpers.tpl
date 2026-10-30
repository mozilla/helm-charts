{{- /*
Constructs a Gateway resource name from the app code and gateway type. When
multiple gateway types are present (both "external" and "internal"), the type
is always appended as a suffix. When only a single type is present, the suffix
is omitted for external gateways but always included for internal ones.

If nameOverride is provided, it is returned as-is, bypassing all other logic.
This is useful when migrating from a chart that used a different Gateway name.

This naming logic is shared between mozcloud.gateway.gateways (which creates
the Gateway resources) and mozcloud.gateway.httpRoutes (which references them
in gatewayRefs) to ensure consistent names across resource types.

Params:
  appCode (string):        (required) The application code
                           (e.g. .Values.global.mozcloud.app_code).
  type (string):           (required) The gateway type. Accepted values:
                           "external", "internal".
  hasMultipleTypes (bool): (required) Whether both "external" and "internal"
                           gateway types are present in this release. When
                           true, the type suffix is always appended.
  nameOverride (string):   (optional) When non-empty, returned as-is.

Returns:
  (string) The gateway resource name.

Example:
  # Only external gateways present in this release:
  { appCode: myapp, type: external, hasMultipleTypes: false } → "myapp"
  { appCode: myapp, type: internal, hasMultipleTypes: false } → "myapp-internal"

  # Both external and internal gateways present:
  { appCode: myapp, type: external, hasMultipleTypes: true }  → "myapp-external"
  { appCode: myapp, type: internal, hasMultipleTypes: true }  → "myapp-internal"

  # Name override:
  { appCode: myapp, type: external, hasMultipleTypes: false, nameOverride: "external" } → "external"
*/ -}}
{{- define "mozcloud.gateway.name" -}}
{{- $nameOverride := default "" .nameOverride -}}
{{- if $nameOverride -}}
{{- $nameOverride -}}
{{- else -}}
{{- $appCode := .appCode -}}
{{- $type := .type -}}
{{- $hasMultipleTypes := .hasMultipleTypes -}}
{{- $gatewayName := $appCode }}
{{- if or $hasMultipleTypes (eq $type "internal") }}
  {{- $gatewayName = printf "%s-%s" $gatewayName $type }}
{{- end }}
{{- $gatewayName -}}
{{- end -}}
{{- end -}}

{{- /*
Fails the render when a health check's timeoutSec exceeds its checkIntervalSec.
JSON schema cannot compare the two, and they may be set at different levels
(host and backend), so this runs on the resolved values. Does nothing unless
both are set, since the GKE default for a missing one is not known here.

Params:
  config (dict):        (required) The resolved options.healthCheck values.
  hostName (string):    (required) Host name, used in the error message.
  backendName (string): (optional) Backend name, used in the error message.

Returns:
  (string) Empty. Fails the render when timeoutSec > checkIntervalSec.
*/ -}}
{{- define "mozcloud.gateway.validateHealthCheck" -}}
{{- $config := default dict .config -}}
{{- if and $config.checkIntervalSec $config.timeoutSec (gt (int $config.timeoutSec) (int $config.checkIntervalSec)) -}}
  {{- $backend := ternary (printf " backend %q" .backendName) "" (not (empty .backendName)) -}}
  {{- fail (printf "hosts.%s%s: options.healthCheck.timeoutSec (%v) must be less than or equal to checkIntervalSec (%v)." .hostName $backend $config.timeoutSec $config.checkIntervalSec) -}}
{{- end -}}
{{- end -}}
