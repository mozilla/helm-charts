# mozcloud-workload

![Version: 0.3.5](https://img.shields.io/badge/Version-0.3.5-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square)

Opinionated application chart used to deploy MozCloud workloads and supporting resources

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
  - name: mozcloud-workload
    version: ~0.3.5
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
| file://../../mozcloud-gateway/library | mozcloud-gateway-lib | 0.4.20 |
| file://../../mozcloud-ingress/library | mozcloud-ingress-lib | 0.4.15 |
| file://../../mozcloud-job/library | mozcloud-job-lib | 0.5.6 |
| file://../../mozcloud-labels/library | mozcloud-labels-lib | 0.3.11 |
| file://../../mozcloud-workload-core/library | mozcloud-workload-core-lib | 0.6.16 |
| file://../../mozcloud-workload-stateless/library | mozcloud-workload-stateless-lib | 0.4.32 |

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| configMaps | object | `{}` |  |
| enabled | bool | `true` |  |
| workloads.mozcloud-workload.component | string | `""` |  |
| workloads.mozcloud-workload.container.autoscaling.enabled | bool | `true` |  |
| workloads.mozcloud-workload.container.autoscaling.metrics[0].threshold | int | `60` |  |
| workloads.mozcloud-workload.container.autoscaling.metrics[0].type | string | `"cpu"` |  |
| workloads.mozcloud-workload.container.autoscaling.replicas.max | int | `30` |  |
| workloads.mozcloud-workload.container.autoscaling.replicas.min | int | `1` |  |
| workloads.mozcloud-workload.container.image.repository | string | `""` |  |
| workloads.mozcloud-workload.container.image.tag | string | `""` |  |
| workloads.mozcloud-workload.container.name | string | `"app"` |  |
| workloads.mozcloud-workload.container.port | int | `8000` |  |
| workloads.mozcloud-workload.container.resources.cpu | string | `"100m"` |  |
| workloads.mozcloud-workload.container.resources.memory | string | `"64Mi"` |  |
| workloads.mozcloud-workload.container.strategy | string | `"RollingUpdate"` |  |
| workloads.mozcloud-workload.healthCheck.liveness.enabled | bool | `true` |  |
| workloads.mozcloud-workload.healthCheck.liveness.httpHeaders | list | `[]` |  |
| workloads.mozcloud-workload.healthCheck.liveness.path | string | `"/__lbheartbeat__"` |  |
| workloads.mozcloud-workload.healthCheck.liveness.probes.failureThreshold | int | `5` |  |
| workloads.mozcloud-workload.healthCheck.liveness.probes.initialDelaySeconds | int | `10` |  |
| workloads.mozcloud-workload.healthCheck.liveness.probes.periodSeconds | int | `6` |  |
| workloads.mozcloud-workload.healthCheck.liveness.probes.successThreshold | int | `1` |  |
| workloads.mozcloud-workload.healthCheck.liveness.probes.timeoutSeconds | int | `5` |  |
| workloads.mozcloud-workload.healthCheck.readiness.enabled | bool | `true` |  |
| workloads.mozcloud-workload.healthCheck.readiness.httpHeaders | list | `[]` |  |
| workloads.mozcloud-workload.healthCheck.readiness.path | string | `"/__lbheartbeat__"` |  |
| workloads.mozcloud-workload.healthCheck.readiness.probes.failureThreshold | int | `3` |  |
| workloads.mozcloud-workload.healthCheck.readiness.probes.initialDelaySeconds | int | `10` |  |
| workloads.mozcloud-workload.healthCheck.readiness.probes.periodSeconds | int | `6` |  |
| workloads.mozcloud-workload.healthCheck.readiness.probes.successThreshold | int | `1` |  |
| workloads.mozcloud-workload.healthCheck.readiness.probes.timeoutSeconds | int | `5` |  |
| workloads.mozcloud-workload.hosts.name.addresses | list | `[]` |  |
| workloads.mozcloud-workload.hosts.name.api | string | `"gateway"` |  |
| workloads.mozcloud-workload.hosts.name.domains[0] | string | `"example.com"` |  |
| workloads.mozcloud-workload.hosts.name.httpRoutes.createHttpRoutes | bool | `true` |  |
| workloads.mozcloud-workload.hosts.name.tls.certs | list | `[]` |  |
| workloads.mozcloud-workload.hosts.name.tls.create | bool | `true` |  |
| workloads.mozcloud-workload.hosts.name.tls.type | string | `"certmap"` |  |
| workloads.mozcloud-workload.hosts.name.type | string | `"external"` |  |
| workloads.mozcloud-workload.otel.autoInstrumentation.enabled | bool | `false` |  |
| workloads.mozcloud-workload.otel.autoInstrumentation.language | string | `""` |  |

----------------------------------------------
Autogenerated from chart metadata using [helm-docs v1.14.2](https://github.com/norwoodj/helm-docs/releases/v1.14.2)
