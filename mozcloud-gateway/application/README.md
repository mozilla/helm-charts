# mozcloud-gateway

![Version: 0.4.29](https://img.shields.io/badge/Version-0.4.29-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square)

A Helm chart that creates gateways and supporting Gateway API resources

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
  - name: mozcloud-gateway
    version: ~0.4.29
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
| file://../library | mozcloud-gateway-lib | 0.5.0 |

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| backendPolicy.logging.enabled | bool | `true` |  |
| backendPolicy.logging.sampleRate | int | `100000` |  |
| backends.mozcloud-gateway.healthCheck.path | string | `"/__lbheartbeat__"` |  |
| backends.mozcloud-gateway.healthCheck.protocol | string | `"HTTP"` |  |
| backends.mozcloud-gateway.service.port | int | `8080` |  |
| backends.mozcloud-gateway.service.targetPort | string | `"http"` |  |
| enabled | bool | `true` |  |
| gateway.enabled | bool | `true` |  |
| gateway.gateways.mozcloud-gateway.addresses[0] | string | `"mozcloud-gateway-dev-ip-v4"` |  |
| gateway.gateways.mozcloud-gateway.listeners[0].name | string | `"http"` |  |
| gateway.gateways.mozcloud-gateway.listeners[0].port | int | `80` |  |
| gateway.gateways.mozcloud-gateway.listeners[0].protocol | string | `"HTTP"` |  |
| gateway.gateways.mozcloud-gateway.listeners[1].name | string | `"https"` |  |
| gateway.gateways.mozcloud-gateway.listeners[1].port | int | `443` |  |
| gateway.gateways.mozcloud-gateway.listeners[1].protocol | string | `"HTTPS"` |  |
| gateway.gateways.mozcloud-gateway.tls.certs[0] | string | `"mozcloud-gateway-certmap"` |  |
| gateway.gateways.mozcloud-gateway.tls.type | string | `"certmap"` |  |
| gateway.gateways.mozcloud-gateway.type | string | `"external"` |  |
| gatewayPolicy.sslPolicy | string | `"mozilla-intermediate"` |  |
| httpRoute.enabled | bool | `true` |  |
| httpRoute.httpRoutes.mozcloud-gateway.gatewayRefs[0].name | string | `"mozcloud-gateway"` |  |
| httpRoute.httpRoutes.mozcloud-gateway.gatewayRefs[0].section | string | `"https"` |  |
| httpRoute.httpRoutes.mozcloud-gateway.rules[0].backendRefs[0].name | string | `"mozcloud-gateway"` |  |
| httpRoute.httpRoutes.mozcloud-gateway.rules[0].backendRefs[0].port | int | `8080` |  |
| trafficDistributionPolicy | list | `[]` |  |

---

## Contributing

For general contribution workflows, unit testing conventions, JSON schema standards, and chart authoring standards that apply across all charts in this repository, see [CONTRIBUTING.md](../../CONTRIBUTING.md).

### Protected default keys

This chart uses dict-based collections with a protected key per collection type that acts as a chart-level defaults template. The key is stripped from the rendered output and its values are deep-merged as a base under each user-defined entry.

| Collection | Protected key |
|---|---|
| `gateway.gateways` | `mozcloud-gateway` |
| `httpRoute.httpRoutes` | `mozcloud-gateway` |
| `backends` | `mozcloud-gateway` |

Avoid naming your objects after these keys. See [CONTRIBUTING.md](../../CONTRIBUTING.md) for a full explanation of how the protected key pattern works.

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
