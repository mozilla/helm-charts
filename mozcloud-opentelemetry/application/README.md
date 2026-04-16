# mozcloud-opentelemetry

![Version: 0.2.28](https://img.shields.io/badge/Version-0.2.28-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square)

Opinionated application chart for MozCloud OpenTelemetry signals collection

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
  - name: mozcloud-opentelemetry
    version: ~0.2.28
    repository: oci://us-west1-docker.pkg.dev/moz-fx-platform-artifacts/mozcloud-charts
```

> [!IMPORTANT]
> Make sure to set a valid version for your dependencies. Helm supports pinning exact versions as well as version ranges. See [chart best practices - dependencies - versions](https://helm.sh/docs/chart_best_practices/dependencies/#versions) for more details.

Next, update your tenant's values. Shared charts are meant to be self-documented. We ship a verbose [values file](values.yaml) as well as a [JSON schema](values.schema.json).
> [!TIP]
> We're building OCI artifacts automatically with [GHA](/.github/workflows/auto-push-tag-helm-charts.yaml). When a new artifact has been built, we add a matching [tag](https://github.com/mozilla/helm-charts/tags) to this repo as well. Use this to find out about available chart versions and/or to browse the chart's code for a specific version.

## Requirements

| Repository | Name | Version |
|------------|------|---------|
| file://../../mozcloud-labels/library | mozcloud-labels-lib | 1.0.0 |

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| collectors.daemonset.resources.limits.cpu | string | `"500m"` |  |
| collectors.daemonset.resources.limits.memory | string | `"1Gi"` |  |
| collectors.daemonset.resources.requests.cpu | string | `"250m"` |  |
| collectors.daemonset.resources.requests.memory | string | `"512Mi"` |  |
| collectors.daemonset.securityContext.allowPrivilegeEscalation | bool | `false` |  |
| collectors.daemonset.securityContext.capabilities.drop[0] | string | `"ALL"` |  |
| collectors.daemonset.securityContext.privileged | bool | `false` |  |
| collectors.daemonset.securityContext.runAsGroup | int | `10001` |  |
| collectors.daemonset.securityContext.runAsNonRoot | bool | `true` |  |
| collectors.daemonset.securityContext.runAsUser | int | `10001` |  |
| collectors.daemonset.securityContext.seccompProfile.type | string | `"RuntimeDefault"` |  |
| collectors.gateway.autoscaler.maxReplicas | int | `5` |  |
| collectors.gateway.autoscaler.minReplicas | int | `2` |  |
| collectors.gateway.autoscaler.targetCPUUtilization | int | `50` |  |
| collectors.gateway.autoscaler.targetMemoryUtilization | int | `60` |  |
| collectors.gateway.endpoints.headless.endpoint | string | `"mozcloud-opentelemetry-gateway-collector-headless"` |  |
| collectors.gateway.endpoints.headless.port | string | `"4317"` |  |
| collectors.gateway.endpoints.otlp.collectorMetricsPort | string | `"14318"` |  |
| collectors.gateway.endpoints.otlp.endpoint | string | `"mozcloud-opentelemetry-gateway-collector"` |  |
| collectors.gateway.endpoints.otlp.port | string | `"4317"` |  |
| collectors.gateway.endpoints.statsd.endpoint | string | `"mozcloud-opentelemetry-gateway-statsd"` |  |
| collectors.gateway.endpoints.statsd.port | string | `"8125"` |  |
| collectors.gateway.resources.limits.cpu | string | `"400m"` |  |
| collectors.gateway.resources.limits.memory | string | `"2Gi"` |  |
| collectors.gateway.resources.requests.cpu | string | `"300m"` |  |
| collectors.gateway.resources.requests.memory | string | `"1536Mi"` |  |
| collectors.gateway.securityContext.allowPrivilegeEscalation | bool | `false` |  |
| collectors.gateway.securityContext.capabilities.drop[0] | string | `"ALL"` |  |
| collectors.gateway.securityContext.privileged | bool | `false` |  |
| collectors.gateway.securityContext.runAsGroup | int | `10001` |  |
| collectors.gateway.securityContext.runAsNonRoot | bool | `true` |  |
| collectors.gateway.securityContext.runAsUser | int | `10001` |  |
| collectors.gateway.securityContext.seccompProfile.type | string | `"RuntimeDefault"` |  |
| collectors.gateway.statsdService.enabled | bool | `true` |  |
| collectors.gateway.statsdService.sessionAffinityTimeoutSeconds | int | `10800` |  |
| global.mozcloud.app_code | string | `"mozcloud-opentelemetry"` |  |
| global.mozcloud.chart | string | `"mozcloud-opentelemetry"` |  |
| global.mozcloud.component_code | string | `"mozcloud-opentelemetry"` |  |
| global.mozcloud.env_code | string | `"cluster"` |  |
| global.mozcloud.project_id | string | `"default"` |  |
| global.mozcloud.realm | string | `"cluster"` |  |
| serviceAccount.create | bool | `true` |  |
| serviceAccount.name | string | `"mozcloud-otel-collector"` |  |

---

## Contributing

See [CONTRIBUTING.md](../../CONTRIBUTING.md) for contribution workflows, unit testing conventions, JSON schema standards, and general chart authoring standards.

### JSON schema validation

**Any change to `values.yaml` must be accompanied by a corresponding update to `values.schema.json`.** Letting the two files drift causes unrecognized keys to pass through silently or valid keys to be rejected with confusing errors.

See [CONTRIBUTING.md](../../CONTRIBUTING.md) for schema conventions. The quick reference for what to update when changing values:

| Change type | Schema action required |
|---|---|
| Add a new key | Add a matching property with type, description, and (if applicable) default |
| Remove a key | Remove its property from the schema (and from any `required` arrays) |
| Rename a key | Remove the old property, add the new one |
| Restrict a string to specific values | Add or update an `enum` constraint |
| Add a new collection type | Add an `additionalProperties` entry with the item shape (or a `$ref`) |
| Extract a repeated shape | Move it into `$defs` and replace inline copies with `$ref` |

----------------------------------------------
Autogenerated from chart metadata using [helm-docs v1.14.2](https://github.com/norwoodj/helm-docs/releases/v1.14.2)
