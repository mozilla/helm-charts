# mozcloud

![Version: 1.4.0](https://img.shields.io/badge/Version-1.4.0-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square)

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
    version: ~1.4.0
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
| file://../../mozcloud-gateway/library | mozcloud-gateway-lib | 1.0.0 |
| file://../../mozcloud-ingress/library | mozcloud-ingress-lib | 1.1.0 |
| file://../../mozcloud-labels/library | mozcloud-labels-lib | 1.0.0 |

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| cloud.provider | string | `"gke"` |  |
| configMaps | object | `{}` |  |
| enabled | bool | `true` |  |
| externalSecrets.default.enabled | bool | `true` |  |
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
| serviceAccounts | object | `{"default":{"enabled":true}}` | ---------------------------------------------------------------------------- This chart CANNOT create resources in GCP. For this work, you must have already created the following in GCP using Terraform:   - GCP service account   - GCP service account permissions   - Workload Identity configuration  To learn more about creating service accounts in GCP with Workload Identity, review this link: <link>  By default, a service account using the name of your tenant will be created that corresponds to the GCP service account automatically created during the tenant provisioning process. The naming convention is as follows:    gke-<environment>@<gcp_project_id>.iam.serviceaccount.com  Any service accounts created here will be created IN ADDITION to that tenant service account. To disable the default service account, set:  serviceAccounts:   default:     enabled: false  Example and configuration options:  serviceAccounts:   # This is the name of the Kubernetes service account you would like to   # create. To use this service account with your workloads or jobs, reference   # the name you specify here in the `serviceAccounts` sections in container   # configurations.   kubernetes-service-account-name:     # If this service account should map to a service account in GCP, enter     # the details here.     gcpServiceAccount:       # The name of the GCP service account (everything before "@" in the       # email address).       name: ''        # GCP project ID. If not specified, the value automatically set in       # .Values.global.mozcloud.project_id will be used.       #projectId: ''      # A list of image pull secret names to attach to this service account.     # Any pod using this service account will automatically have access to     # these secrets for pulling container images.     #     #   imagePullSecrets:     #     - my-registry-secret     #     - another-registry-secret |
| tasks.common.container.args | list | `[]` |  |
| tasks.common.container.command | list | `[]` |  |
| tasks.common.container.configMaps | list | `[]` |  |
| tasks.common.container.envVars | object | `{}` |  |
| tasks.common.container.image | object | `{}` |  |
| tasks.common.container.imagePullPolicy | string | `"Always"` |  |
| tasks.common.container.resources.cpu | string | `"100m"` |  |
| tasks.common.container.resources.memory | string | `"128Mi"` |  |
| tasks.common.container.secrets | list | `[]` |  |
| tasks.common.container.security | object | `{}` |  |
| tasks.common.container.volumes | list | `[]` |  |
| tasks.common.cronJob.jobHistory | object | `{}` |  |
| tasks.common.cronJob.schedule | string | `""` |  |
| tasks.common.job.backoffLimit | int | `6` |  |
| tasks.common.job.generateName | bool | `false` |  |
| tasks.common.job.otel.enabled | bool | `true` |  |
| tasks.common.job.parallelism | int | `1` |  |
| tasks.common.job.restartPolicy | string | `"Never"` |  |
| tasks.common.job.security | object | `{}` |  |
| tasks.common.job.serviceAccount | string | `""` |  |
| tasks.common.job.type | string | `"preDeployment"` |  |
| tasks.cronJobs.default.jobConfig | object | `{}` |  |
| tasks.cronJobs.default.jobHistory.failed | int | `1` |  |
| tasks.cronJobs.default.jobHistory.successful | int | `1` |  |
| tasks.cronJobs.default.schedule | string | `""` |  |
| tasks.jobs.default.affinity | object | `{}` |  |
| tasks.jobs.default.argo | object | `{}` |  |
| tasks.jobs.default.containers.default.args | list | `[]` |  |
| tasks.jobs.default.containers.default.command | list | `[]` |  |
| tasks.jobs.default.containers.default.configMaps | list | `[]` |  |
| tasks.jobs.default.containers.default.envFromFields | object | `{}` |  |
| tasks.jobs.default.containers.default.envVars | object | `{}` |  |
| tasks.jobs.default.containers.default.image.repository | string | `""` |  |
| tasks.jobs.default.containers.default.image.tag | string | `""` |  |
| tasks.jobs.default.containers.default.imagePullPolicy | string | `"Always"` |  |
| tasks.jobs.default.containers.default.resources | object | `{}` |  |
| tasks.jobs.default.containers.default.secrets | list | `[]` |  |
| tasks.jobs.default.containers.default.security | object | `{}` |  |
| tasks.jobs.default.containers.default.volumes | list | `[]` |  |
| tasks.jobs.default.generateName | bool | `false` |  |
| tasks.jobs.default.nodeSelector | object | `{}` |  |
| tasks.jobs.default.otel.autoInstrumentation.enabled | bool | `false` |  |
| tasks.jobs.default.otel.autoInstrumentation.language | string | `""` |  |
| tasks.jobs.default.otel.containers | list | `[]` |  |
| tasks.jobs.default.otel.enabled | bool | `true` |  |
| tasks.jobs.default.security | object | `{}` |  |
| tasks.jobs.default.serviceAccount | string | `""` |  |
| tasks.jobs.default.tolerations | list | `[]` |  |
| tasks.jobs.default.type | string | `"preDeployment"` |  |
| telegraf.enabled | bool | `false` |  |
| workloads.default.affinity | object | `{}` |  |
| workloads.default.autoscaling.enabled | bool | `true` |  |
| workloads.default.autoscaling.metrics[0].threshold | int | `60` |  |
| workloads.default.autoscaling.metrics[0].type | string | `"cpu"` |  |
| workloads.default.autoscaling.replicas.max | int | `30` |  |
| workloads.default.autoscaling.replicas.min | int | `1` |  |
| workloads.default.component | string | `""` |  |
| workloads.default.containers.default.args | list | `[]` |  |
| workloads.default.containers.default.command | list | `[]` |  |
| workloads.default.containers.default.configMaps | list | `[]` |  |
| workloads.default.containers.default.envVars | object | `{}` |  |
| workloads.default.containers.default.healthCheck.liveness.enabled | bool | `true` |  |
| workloads.default.containers.default.healthCheck.liveness.httpHeaders | list | `[]` |  |
| workloads.default.containers.default.healthCheck.liveness.path | string | `"/__lbheartbeat__"` |  |
| workloads.default.containers.default.healthCheck.liveness.probes.failureThreshold | int | `5` |  |
| workloads.default.containers.default.healthCheck.liveness.probes.initialDelaySeconds | int | `10` |  |
| workloads.default.containers.default.healthCheck.liveness.probes.periodSeconds | int | `6` |  |
| workloads.default.containers.default.healthCheck.liveness.probes.successThreshold | int | `1` |  |
| workloads.default.containers.default.healthCheck.liveness.probes.timeoutSeconds | int | `5` |  |
| workloads.default.containers.default.healthCheck.readiness.enabled | bool | `true` |  |
| workloads.default.containers.default.healthCheck.readiness.httpHeaders | list | `[]` |  |
| workloads.default.containers.default.healthCheck.readiness.path | string | `"/__lbheartbeat__"` |  |
| workloads.default.containers.default.healthCheck.readiness.probes.failureThreshold | int | `3` |  |
| workloads.default.containers.default.healthCheck.readiness.probes.initialDelaySeconds | int | `10` |  |
| workloads.default.containers.default.healthCheck.readiness.probes.periodSeconds | int | `6` |  |
| workloads.default.containers.default.healthCheck.readiness.probes.successThreshold | int | `1` |  |
| workloads.default.containers.default.healthCheck.readiness.probes.timeoutSeconds | int | `5` |  |
| workloads.default.containers.default.image.repository | string | `""` |  |
| workloads.default.containers.default.image.tag | string | `""` |  |
| workloads.default.containers.default.imagePullPolicy | string | `"Always"` |  |
| workloads.default.containers.default.port | int | `8000` |  |
| workloads.default.containers.default.resources.cpu | string | `"100m"` |  |
| workloads.default.containers.default.resources.memory | string | `"128Mi"` |  |
| workloads.default.containers.default.secrets | list | `[]` |  |
| workloads.default.containers.default.security | object | `{}` |  |
| workloads.default.enabled | bool | `true` |  |
| workloads.default.hosts.default.addresses | list | `[]` |  |
| workloads.default.hosts.default.api | string | `"gateway"` |  |
| workloads.default.hosts.default.domains[0] | string | `"example.com"` |  |
| workloads.default.hosts.default.httpRoutes.createHttpRoutes | bool | `true` |  |
| workloads.default.hosts.default.targetPort | string | `"http"` |  |
| workloads.default.hosts.default.tls.certs | list | `[]` |  |
| workloads.default.hosts.default.tls.create | bool | `true` |  |
| workloads.default.hosts.default.tls.type | string | `"certmap"` |  |
| workloads.default.hosts.default.type | string | `"external"` |  |
| workloads.default.initContainers.default.args | list | `[]` |  |
| workloads.default.initContainers.default.command | list | `[]` |  |
| workloads.default.initContainers.default.configMaps | list | `[]` |  |
| workloads.default.initContainers.default.envVars | object | `{}` |  |
| workloads.default.initContainers.default.image.repository | string | `""` |  |
| workloads.default.initContainers.default.image.tag | string | `""` |  |
| workloads.default.initContainers.default.imagePullPolicy | string | `"Always"` |  |
| workloads.default.initContainers.default.resources.cpu | string | `"100m"` |  |
| workloads.default.initContainers.default.resources.memory | string | `"128Mi"` |  |
| workloads.default.initContainers.default.secrets | list | `[]` |  |
| workloads.default.initContainers.default.security | object | `{}` |  |
| workloads.default.initContainers.default.sidecar | bool | `false` |  |
| workloads.default.labels | object | `{}` |  |
| workloads.default.nginx.enabled | bool | `true` |  |
| workloads.default.nginx.image | string | `"us-west1-docker.pkg.dev/moz-fx-platform-artifacts/platform-dockerhub-cache/nginxinc/nginx-unprivileged:1.29"` |  |
| workloads.default.nodeSelector | object | `{}` |  |
| workloads.default.otel.autoInstrumentation.enabled | bool | `false` |  |
| workloads.default.otel.autoInstrumentation.language | string | `""` |  |
| workloads.default.otel.containers | list | `[]` |  |
| workloads.default.otel.enabled | bool | `true` |  |
| workloads.default.podDisruptionBudget.enabled | bool | `true` |  |
| workloads.default.podDisruptionBudget.maxUnavailable | string | `""` |  |
| workloads.default.podDisruptionBudget.minAvailable | string | `""` |  |
| workloads.default.security | object | `{}` |  |
| workloads.default.serviceAccount | string | `""` |  |
| workloads.default.strategy | string | `"RollingUpdate"` |  |
| workloads.default.tolerations | list | `[]` |  |
| workloads.default.type | string | `"deployment"` |  |

---

## Contributing

This section covers standards specific to this chart. For general contribution workflows, unit testing conventions, JSON schema standards, and chart authoring standards that apply across all charts in this repository, see [CONTRIBUTING.md](../../CONTRIBUTING.md).

### Template organization

Template folders must mirror top-level keys in `values.yaml`. For example, a `configMaps` key in values corresponds to a `templates/configmap/` folder; `workloads` corresponds to `templates/workload/`, and so on. This 1:1 mapping makes it straightforward to locate the template responsible for any given value.

**Shared templates** that serve multiple resource types (annotations, labels, pod specs, formatters) live as `_<name>.yaml` files directly in `templates/`. These are named template definitions used across multiple subfolders, not helpers in the traditional sense.

**Resource-specific templates** (e.g. `deployment.yaml`, `cronjob.yaml`) live in the subfolder for their resource type.

### Helper file placement

Helper functions belong in a `_helpers.tpl` file located in the same folder as the templates they serve:

- Helpers used only by workload templates: `templates/workload/_helpers.tpl`
- Helpers used only by task templates: `templates/task/_helpers.tpl`
- Helpers used chart-wide: `templates/_helpers.tpl`

A helper should live in the most specific scope where it is used. Do not place a workload-specific helper in the root `_helpers.tpl` just because it seems "important". Scope it correctly.

> [!NOTE]
> An exception applies for unusually complex logic that would make a template significantly harder to read on its own. In that case, extracting the logic into a helper is encouraged even if it is only called once.

### When to write a helper vs. keep logic in a template

Templates are the primary site of rendering and interpolation. They should be readable at a glance.

If you find yourself writing loops, conditionals, or data transformations inside a template, first ask:

1. **Can the data structure be simplified** so the template doesn't need to do that work?
2. **Should this be a helper** that returns a clean value the template can use directly?

If neither applies, the logic can stay in the template. This should be the exception, not the rule.

### Helper authoring standards

- **Always use named parameters.** Helpers must accept a dict with named keys rather than relying on positional arguments or raw context. This makes call sites self-documenting.

  ```yaml
  {{- include "mozcloud.myHelper" (dict "name" $name "context" $) }}
  ```

- **Parameters must be single-purpose and non-overlapping.** Do not define both `config` and `jobConfig`, or both `workloadContainerConfig` and `jobContainerConfig`, as parameters to the same helper. Each parameter should have one clear role.

- **Keep helpers concise.** A helper that spans many lines is usually doing too much. Break it into smaller, focused helpers if needed.

- **Avoid accumulating too many helpers in a single file.** When a `_helpers.tpl` becomes hard to scan, consider whether the helpers can be split into more targeted shared templates (e.g. `_annotations.yaml`, `_labels.yaml`).

- **Document every helper.** Each helper must have a block comment above its `define` statement that describes what it does, its parameters (name, type, required/optional), and its return value. Follow the established format used throughout this chart:

  ```
  {{- /*
  Short description of what this helper does.

  Params:
    paramName (type): (required|optional) What this parameter is for.

  Returns:
    (type) What the helper produces.
  */ -}}
  ```

### Protected default keys

This chart uses dict-based collections where `default` is a reserved key that acts as a chart-level defaults template. It is stripped from the rendered output and its values are deep-merged as a base under each user-defined entry. Avoid naming your objects `default`.

| Collection       | Protected key |
|------------------|---------------|
| `workloads`      | `default`     |
| `containers`     | `default`     |
| `initContainers` | `default`     |
| `tasks.cronJobs` | `default`     |
| `tasks.jobs`     | `default`     |

Avoid naming your objects `default`. If `default` is the only entry in a collection (no user-defined entries), it is treated as a regular object and rendered as-is.

When adding a new collection type, you must:

1. Define a corresponding protected key in `values.yaml`.
2. Add a formatter helper (following the pattern in `templates/_formatter.yaml`) that applies the same strip-and-merge logic.
3. Call the formatter from the template before iterating over the collection.

See [CONTRIBUTING.md](../../CONTRIBUTING.md) for the general explanation of why this pattern exists.

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
