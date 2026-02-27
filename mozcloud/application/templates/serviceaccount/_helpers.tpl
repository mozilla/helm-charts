{{- define "mozcloud.serviceAccount.gcpServiceAccount" -}}
{{- $gcpServiceAccount := .gcpServiceAccount -}}
{{- $globals := .globals -}}
{{- $projectId := default $globals.project_id $gcpServiceAccount.projectId -}}
{{- $output := printf "%s@%s.iam.gserviceaccount.com" $gcpServiceAccount.name $projectId -}}
{{ $output }}
{{- end -}}
