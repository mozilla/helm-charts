{{- /*
Constructs the full GCP service account email address from a name and project
ID, in the standard GCP format:
  "<name>@<project_id>.iam.gserviceaccount.com"

If no projectId is set in the gcpServiceAccount config, falls back to
globals.project_id.

Params:
  gcpServiceAccount (dict): (required) The GCP service account config. Must
                            include:
    name (string):      (required) The service account name (the portion
                        before the "@").
    projectId (string): (optional) The GCP project ID. Falls back to
                        globals.project_id if not set.
  globals (dict):           (required) Global MozCloud values from
                            .Values.global.mozcloud.

Returns:
  (string) The full GCP service account email address.

Example:
  Input:
    gcpServiceAccount:
      name: my-service-account
      projectId: my-gcp-project
    globals:
      project_id: fallback-project

  Output: "my-service-account@my-gcp-project.iam.gserviceaccount.com"

  # When projectId is omitted, globals.project_id is used:
  Input:
    gcpServiceAccount:
      name: my-service-account
    globals:
      project_id: fallback-project

  Output: "my-service-account@fallback-project.iam.gserviceaccount.com"
*/ -}}
{{- define "mozcloud.serviceAccount.gcpServiceAccount" -}}
{{- $gcpServiceAccount := .gcpServiceAccount -}}
{{- $globals := .globals -}}
{{- $projectId := default $globals.project_id $gcpServiceAccount.projectId -}}
{{- $output := printf "%s@%s.iam.gserviceaccount.com" $gcpServiceAccount.name $projectId -}}
{{ $output }}
{{- end -}}
