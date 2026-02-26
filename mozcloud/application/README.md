# mozcloud

![Version: 0.4.0](https://img.shields.io/badge/Version-0.4.0-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square)

Opinionated application chart used to deploy MozCloud Kubernetes resources supporting resources

## Usage

The chart is distributed as an [OCI artifact](https://helm.sh/docs/topics/registries/) on [Google Artifact Registry](https://cloud.google.com/artifact-registry/docs/helm).

* OCI registry: `oci://us-west1-docker.pkg.dev/moz-fx-platform-artifacts/mozcloud-charts`

To use this chart, include it as a [dependency](https://helm.sh/docs/chart_best_practices/dependencies/) in your tenant chart, e.g.:

```yaml
apiVersion: v2
name: my-mozcloud-tenant-chart
version: 0.1.0
type: application
dependencies:
  - name: mozcloud
    version: ~0.4.0
    repository: oci://us-west1-docker.pkg.dev/moz-fx-platform-artifacts/mozcloud-charts
```

> [!IMPORTANT]
> Make sure to set a valid version for your dependencies. Helm supports pinning exact versions as well as version ranges, see [chart best practices - dependencies - versions](https://helm.sh/docs/chart_best_practices/dependencies/#versions) for more details.

Next, update your tenant's values. Shared charts are meant to be self-documented. We ship a verbose [values file](values.yaml) as well as a [JSON schema](values.schema.json).

> [!TIP]
> We're building OCI artifacts automatically with [GHA](/.github/workflows/auto-push-tag-helm-charts.yaml). When a new artifact has been built, we add a matching [tag](https://github.com/mozilla/helm-charts/tags) to this repo as well. Use this to find out about available chart versions and/or to browse the chart's code for a specific version.

## Requirements

| Repository | Name | Version |
|------------|------|---------|
| file://../../mozcloud-gateway/library | mozcloud-gateway-lib | 0.4.25 |
| file://../../mozcloud-ingress/library | mozcloud-ingress-lib | 0.4.20 |
| file://../../mozcloud-labels/library | mozcloud-labels-lib | 0.3.16 |

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| configMaps | object | `{}` |  |
| enabled | bool | `true` |  |
| externalSecrets | object | `{}` |  |
| persistentVolumes | object | `{}` |  |
| preview.enabled | bool | `false` |  |
| preview.endpointCheck.activeDeadlineSeconds | int | `900` |  |
| preview.endpointCheck.backoffLimit | int | `1` |  |
| preview.endpointCheck.checkPath | string | `"__heartbeat__"` |  |
| preview.endpointCheck.enabled | bool | `true` |  |
| preview.endpointCheck.image | string | `"us-west1-docker.pkg.dev/moz-fx-platform-artifacts/platform-dockerhub-cache/curlimages/curl:8.14.1"` |  |
| preview.endpointCheck.maxAttempts | int | `60` |  |
| preview.endpointCheck.maxTimePerAttempt | int | `5` |  |
| preview.endpointCheck.sleepSeconds | int | `15` |  |
| preview.httpRoute.enabled | bool | `true` |  |
| preview.httpRoute.gateway.name | string | `"sandbox-high-preview-gateway"` |  |
| preview.httpRoute.gateway.namespace | string | `"preview-shared-infrastructure"` |  |
| preview.urlTransformKeys | list | `[]` |  |
| serviceAccounts | object | `{}` | ---------------------------------------------------------------------------- This chart CANNOT create resources in GCP. For this work, you must have already created the following in GCP using Terraform:   - GCP service account   - GCP service account permissions   - Workload Identity configuration  To learn more about creating service accounts in GCP with Workload Identity, review this link: <link>  By default, a service account using the name of your tenant will be created that corresponds to the GCP service account automatically created during the tenant provisioning process. The naming convention is as follows:    gke-<environment>@<gcp_project_id>.iam.serviceaccount.com  Any service accounts created here will be created IN ADDITION to that tenant service account.  Example and configuration options:  serviceAccounts:   # This is the name of the Kubernetes service account you would like to   # create. To use this service account with your workloads or jobs, reference   # the name you specify here in the `serviceAccounts` sections in container   # configurations.   kubernetes-service-account-name:     # If this service account should map to a service account in GCP, enter     # the details here.     gcpServiceAccount:       # The name of the GCP service account (everything before "@" in the       # email address).       name: ''        # GCP project ID. If not specified, the value automatically set in       # .Values.global.mozcloud.project_id will be used.       #projectId: '' |
| tasks.common.container.args | list | `[]` |  |
| tasks.common.container.command | list | `[]` |  |
| tasks.common.container.configMaps | list | `[]` |  |
| tasks.common.container.envVars | object | `{}` |  |
| tasks.common.container.externalSecrets | list | `[]` |  |
| tasks.common.container.image | object | `{}` |  |
| tasks.common.container.resources.cpu | string | `"100m"` |  |
| tasks.common.container.resources.memory | string | `"128Mi"` |  |
| tasks.common.container.security | object | `{}` |  |
| tasks.common.container.volumes | list | `[]` |  |
| tasks.common.cronJob.jobHistory | object | `{}` |  |
| tasks.common.cronJob.schedule | string | `""` |  |
| tasks.common.job.backoffLimit | int | `6` |  |
| tasks.common.job.generateName | bool | `false` |  |
| tasks.common.job.otel | object | `{}` |  |
| tasks.common.job.parallelism | int | `1` |  |
| tasks.common.job.restartPolicy | string | `"Never"` |  |
| tasks.common.job.security | object | `{}` |  |
| tasks.common.job.serviceAccount | string | `""` |  |
| tasks.common.job.type | string | `"preDeployment"` |  |
| tasks.cronJobs.mozcloud-cronjob.jobConfig | object | `{}` |  |
| tasks.cronJobs.mozcloud-cronjob.jobHistory.failed | int | `1` |  |
| tasks.cronJobs.mozcloud-cronjob.jobHistory.successful | int | `1` |  |
| tasks.cronJobs.mozcloud-cronjob.schedule | string | `""` |  |
| tasks.jobs.mozcloud-job.argo | object | `{}` |  |
| tasks.jobs.mozcloud-job.containers.mozcloud-container.args | list | `[]` |  |
| tasks.jobs.mozcloud-job.containers.mozcloud-container.command | list | `[]` |  |
| tasks.jobs.mozcloud-job.containers.mozcloud-container.configMaps | list | `[]` |  |
| tasks.jobs.mozcloud-job.containers.mozcloud-container.envVars | object | `{}` |  |
| tasks.jobs.mozcloud-job.containers.mozcloud-container.externalSecrets | list | `[]` |  |
| tasks.jobs.mozcloud-job.containers.mozcloud-container.image.repository | string | `""` |  |
| tasks.jobs.mozcloud-job.containers.mozcloud-container.image.tag | string | `""` |  |
| tasks.jobs.mozcloud-job.containers.mozcloud-container.resources | object | `{}` |  |
| tasks.jobs.mozcloud-job.containers.mozcloud-container.security | object | `{}` |  |
| tasks.jobs.mozcloud-job.containers.mozcloud-container.volumes | list | `[]` |  |
| tasks.jobs.mozcloud-job.generateName | bool | `false` |  |
| tasks.jobs.mozcloud-job.otel.autoInstrumentation.enabled | bool | `false` |  |
| tasks.jobs.mozcloud-job.otel.autoInstrumentation.language | string | `""` |  |
| tasks.jobs.mozcloud-job.otel.containers | list | `[]` |  |
| tasks.jobs.mozcloud-job.otel.enabled | bool | `false` |  |
| tasks.jobs.mozcloud-job.security | object | `{}` |  |
| tasks.jobs.mozcloud-job.serviceAccount | string | `""` |  |
| tasks.jobs.mozcloud-job.type | string | `"preDeployment"` |  |
| workloads.mozcloud-workload.autoscaling.enabled | bool | `true` |  |
| workloads.mozcloud-workload.autoscaling.metrics[0].threshold | int | `60` |  |
| workloads.mozcloud-workload.autoscaling.metrics[0].type | string | `"cpu"` |  |
| workloads.mozcloud-workload.autoscaling.replicas.max | int | `30` |  |
| workloads.mozcloud-workload.autoscaling.replicas.min | int | `1` |  |
| workloads.mozcloud-workload.component | string | `""` |  |
| workloads.mozcloud-workload.containers.mozcloud-container.args | list | `[]` |  |
| workloads.mozcloud-workload.containers.mozcloud-container.command | list | `[]` |  |
| workloads.mozcloud-workload.containers.mozcloud-container.configMaps | list | `[]` |  |
| workloads.mozcloud-workload.containers.mozcloud-container.envVars | object | `{}` |  |
| workloads.mozcloud-workload.containers.mozcloud-container.externalSecrets | list | `[]` |  |
| workloads.mozcloud-workload.containers.mozcloud-container.healthCheck.liveness.enabled | bool | `true` |  |
| workloads.mozcloud-workload.containers.mozcloud-container.healthCheck.liveness.httpHeaders | list | `[]` |  |
| workloads.mozcloud-workload.containers.mozcloud-container.healthCheck.liveness.path | string | `"/__lbheartbeat__"` |  |
| workloads.mozcloud-workload.containers.mozcloud-container.healthCheck.liveness.probes.failureThreshold | int | `5` |  |
| workloads.mozcloud-workload.containers.mozcloud-container.healthCheck.liveness.probes.initialDelaySeconds | int | `10` |  |
| workloads.mozcloud-workload.containers.mozcloud-container.healthCheck.liveness.probes.periodSeconds | int | `6` |  |
| workloads.mozcloud-workload.containers.mozcloud-container.healthCheck.liveness.probes.successThreshold | int | `1` |  |
| workloads.mozcloud-workload.containers.mozcloud-container.healthCheck.liveness.probes.timeoutSeconds | int | `5` |  |
| workloads.mozcloud-workload.containers.mozcloud-container.healthCheck.readiness.enabled | bool | `true` |  |
| workloads.mozcloud-workload.containers.mozcloud-container.healthCheck.readiness.httpHeaders | list | `[]` |  |
| workloads.mozcloud-workload.containers.mozcloud-container.healthCheck.readiness.path | string | `"/__lbheartbeat__"` |  |
| workloads.mozcloud-workload.containers.mozcloud-container.healthCheck.readiness.probes.failureThreshold | int | `3` |  |
| workloads.mozcloud-workload.containers.mozcloud-container.healthCheck.readiness.probes.initialDelaySeconds | int | `10` |  |
| workloads.mozcloud-workload.containers.mozcloud-container.healthCheck.readiness.probes.periodSeconds | int | `6` |  |
| workloads.mozcloud-workload.containers.mozcloud-container.healthCheck.readiness.probes.successThreshold | int | `1` |  |
| workloads.mozcloud-workload.containers.mozcloud-container.healthCheck.readiness.probes.timeoutSeconds | int | `5` |  |
| workloads.mozcloud-workload.containers.mozcloud-container.image.repository | string | `""` |  |
| workloads.mozcloud-workload.containers.mozcloud-container.image.tag | string | `""` |  |
| workloads.mozcloud-workload.containers.mozcloud-container.port | int | `8000` |  |
| workloads.mozcloud-workload.containers.mozcloud-container.resources.cpu | string | `"100m"` |  |
| workloads.mozcloud-workload.containers.mozcloud-container.resources.memory | string | `"128Mi"` |  |
| workloads.mozcloud-workload.containers.mozcloud-container.security | object | `{}` |  |
| workloads.mozcloud-workload.hosts.name.addresses | list | `[]` |  |
| workloads.mozcloud-workload.hosts.name.api | string | `"gateway"` |  |
| workloads.mozcloud-workload.hosts.name.domains[0] | string | `"example.com"` |  |
| workloads.mozcloud-workload.hosts.name.httpRoutes.createHttpRoutes | bool | `true` |  |
| workloads.mozcloud-workload.hosts.name.tls.certs | list | `[]` |  |
| workloads.mozcloud-workload.hosts.name.tls.create | bool | `true` |  |
| workloads.mozcloud-workload.hosts.name.tls.type | string | `"certmap"` |  |
| workloads.mozcloud-workload.hosts.name.type | string | `"external"` |  |
| workloads.mozcloud-workload.initContainers.mozcloud-init-container.args | list | `[]` |  |
| workloads.mozcloud-workload.initContainers.mozcloud-init-container.command | list | `[]` |  |
| workloads.mozcloud-workload.initContainers.mozcloud-init-container.configMaps | list | `[]` |  |
| workloads.mozcloud-workload.initContainers.mozcloud-init-container.envVars | object | `{}` |  |
| workloads.mozcloud-workload.initContainers.mozcloud-init-container.externalSecrets | list | `[]` |  |
| workloads.mozcloud-workload.initContainers.mozcloud-init-container.image.repository | string | `""` |  |
| workloads.mozcloud-workload.initContainers.mozcloud-init-container.image.tag | string | `""` |  |
| workloads.mozcloud-workload.initContainers.mozcloud-init-container.resources.cpu | string | `"100m"` |  |
| workloads.mozcloud-workload.initContainers.mozcloud-init-container.resources.memory | string | `"128Mi"` |  |
| workloads.mozcloud-workload.initContainers.mozcloud-init-container.security | object | `{}` |  |
| workloads.mozcloud-workload.initContainers.mozcloud-init-container.sidecar | bool | `false` |  |
| workloads.mozcloud-workload.labels | object | `{}` |  |
| workloads.mozcloud-workload.nginx.enabled | bool | `true` |  |
| workloads.mozcloud-workload.otel.autoInstrumentation.enabled | bool | `false` |  |
| workloads.mozcloud-workload.otel.autoInstrumentation.language | string | `""` |  |
| workloads.mozcloud-workload.otel.containers | list | `[]` |  |
| workloads.mozcloud-workload.otel.enabled | bool | `true` |  |
| workloads.mozcloud-workload.security | object | `{}` |  |
| workloads.mozcloud-workload.serviceAccount | string | `""` |  |
| workloads.mozcloud-workload.strategy | string | `"RollingUpdate"` |  |

----------------------------------------------
Autogenerated from chart metadata using [helm-docs v1.14.2](https://github.com/norwoodj/helm-docs/releases/v1.14.2)
