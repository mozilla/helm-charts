{{- /*
Constructs a Gateway resource name from the app code and gateway type. When
multiple gateway types are present (both "external" and "internal"), the type
is always appended as a suffix. When only a single type is present, the suffix
is omitted for external gateways but always included for internal ones.

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

Returns:
  (string) The gateway resource name.

Example:
  # Only external gateways present in this release:
  { appCode: myapp, type: external, hasMultipleTypes: false } → "myapp"
  { appCode: myapp, type: internal, hasMultipleTypes: false } → "myapp-internal"

  # Both external and internal gateways present:
  { appCode: myapp, type: external, hasMultipleTypes: true }  → "myapp-external"
  { appCode: myapp, type: internal, hasMultipleTypes: true }  → "myapp-internal"
*/ -}}
{{- define "mozcloud.gateway.name" -}}
{{- $appCode := .appCode -}}
{{- $type := .type -}}
{{- $hasMultipleTypes := .hasMultipleTypes -}}
{{- $gatewayName := $appCode }}
{{- if or $hasMultipleTypes (eq $type "internal") }}
  {{- $gatewayName = printf "%s-%s" $gatewayName $type }}
{{- end }}
{{- $gatewayName -}}
{{- end -}}
