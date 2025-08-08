{{/*
Data templates for mozcloud-shared-data-lib

These templates expose the common data in a way that can be accessed by dependent charts.
The data is embedded directly in the templates to avoid file access limitations.
*/}}

{{/*
mozcloud-shared-data-lib.commonData
Returns the raw common data as YAML.
This is the primary way for dependent charts to access the shared data.
*/}}
{{- define "mozcloud-shared-data-lib.commonData" -}}
jameslabel:
  labels:
    component_code: unset
    data_risk_level: high
    domain: jamesfakedomain
    env_code: unset
    is_external: false
    realm: unset
    system: jamessystem 
{{- end -}}
