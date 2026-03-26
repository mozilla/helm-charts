---
name: chart-standards
description: "Invoke this skill whenever the user is contributing to the mozcloud Helm chart or its library charts — whether asking how to do something OR actually doing it. This includes: generating a new Helm template or helper file, modifying an existing template or helper, adding a new Kubernetes resource type to the chart, deciding where a file should live and what prefix to use, figuring out which file type to use (_helpers.tpl vs _*.yaml), handling version bumps after library chart changes, or understanding what must be done before a PR is ready. Always trigger when the user asks to create, write, add, modify, or refactor anything in the mozcloud chart — don't wait for them to ask about conventions explicitly."
---

## General Rules for working with mozcloud Helm charts
- We are using Helm version 3 to create reusable Helm charts for our platform.
  - These charts are packaged and pushed to an OCI repository.
  - We deploy these charts using ArgoCD.
- Function and variable names should use camelCase in helpers and templates.
  - If functions are copied from other sources, convert the new function and variable names to camelCase.
- Function and variable names should always be named and have helpful names. Single word is preferable if possible, but prompt for more complex names.
- Prompt for approval for any changes to templates and helpers required outside of the current task.

## Core Helm Chart
The `mozcloud` Helm chart is our core component and what will be consumed by users of our internal platform. It generally consumes library charts and contains the vast majority of our logic. We want to keep this chart maintainable and reduce the reliance on library charts where possible.

The core interface to this chart for our end users is the Values file. This should contain default settings and comments to highlight various configuration options.

## Chart Versioning
Charts follow semver: major for breaking changes, minor for backwards-compatible changes, patch for bug fixes. Version bumps are left to the user's discretion.

## Library Helm Charts
Any changes to library Helm charts should result in a new version of the `mozcloud` chart being published.

- `mozcloud-gateway-lib` this chart contains gateway api resources that are consumed by our `mozcloud` chart.
- `mozcloud-ingress-lib` this chart contains ingress resources that are consumed by our `mozcloud` chart.
- `mozcloud-labels-lib` this chart contains label resources that are consumed by our `mozcloud` chart.

## When creating or modifying Helm helpers
- Single-use helper functions should be embedded inline in the template file directly — do not create a helper file for logic used in only one place.

- When a helper is needed by multiple templates, where it lives depends on scope:
  - **Used by templates across different subdirectories** → top-level `templates/_helpers.tpl` (or a top-level `_*.yaml` if YAML-producing), using the `mozcloud.` prefix.
  - **Used by multiple templates within the same subdirectory** → `templates/{subdirectory}/_helpers.tpl`, prefixed with `mozcloud.{subdirectory}.` (e.g., `mozcloud.configMap.`, `mozcloud.preview.`, `mozcloud.task.`).

- There are two kinds of shared named template files at the top level of `templates/`:
  - `_*.yaml` — YAML/Helm template-driven named templates. Use this when the named template produces YAML structure or relies heavily on Helm template syntax. Examples: `_annotations.yaml`, `_formatter.yaml`, `_labels.yaml`, `_pod.yaml`.
  - `_helpers.tpl` — Pure Go template helper definitions. Use this for utility functions, name generators, and logic that doesn't produce YAML directly.
- Top-level helpers in `_helpers.tpl` use the `mozcloud.` prefix (e.g., `mozcloud.name`, `mozcloud.fullname`).
- Pod and container level named templates (security contexts, resource limits) live in `_pod.yaml` and use the `pod.` prefix.
- Formatter named templates live in `_formatter.yaml` and use the `mozcloud.formatter.` prefix.
- Helpers should be clearly documented with inline comments using the following JSDoc-style format:
  ```
  {{- /*
  Brief description of what the helper does.

  Params:
    paramName (type): (required/optional) Description.

  Returns:
    (type) Description of the return value.
  */ -}}
  ```
- Function parameters should be single purpose, clear and not overlapping with other parameters.
  - We should standardize on `config` across templates instead of uniquely named parameters like `jobConfig` or `workloadConfig`.

## When creating or modifying Helm templates
- Default values should exist in the template where possible.
- Templates should be the primary place where rendering and interpolation takes place.
- Complex functions in templates should be limited and offloaded to a helper function.
- Template folders should match the top level keys used in values.yaml. `configmap`, `workload`, etc.

### Dict-based configuration with protected default keys
Resources in mozcloud use dicts keyed by resource name rather than lists. Within each dict, a specially named entry acts as the default that gets merged into all real entries — it is omitted from rendered output. The protected keys are:

| Dict (values.yaml) | Protected default key |
|---|---|
| `workloads` | `default` |
| `workloads.*.containers` | `default` |
| `workloads.*.initContainers` | `default` |
| `workloads.*.hosts` | `default` |
| `tasks.cronJobs` | `default` |
| `tasks.jobs` | `default` |

When adding a new resource type that follows this pattern, define its protected key, omit it from rendering, and merge it into each real entry using the formatter helpers.

### Labels and annotations
Every template that renders a Kubernetes resource should set a `component_code` on the context and generate labels using the standard helpers. Use `mozcloud/application/templates/externalsecret/externalsecret.yaml` as the canonical reference for the correct label and annotation setup pattern.

For primary resources that need ArgoCD sync-wave ordering (e.g. ConfigMap, ExternalSecret, ServiceAccount, Deployment, Job), also include `mozcloud.annotations.argo`. Secondary or supporting resources (HPA, PodMonitoring, PVC, gateway/ingress resources) do not necessarily require annotations. Never generate labels manually — always use these helpers.

### Reference templates
When adding a new resource type, use existing templates as a reference rather than starting from scratch:
- **Simple resource** (no formatter helper needed): `templates/externalsecret/externalsecret.yaml`
- **Resource with a formatter helper**: `templates/task/job.yaml` + `templates/task/_helpers.tpl`

### Preview mode support
When adding a new resource type, consider whether it needs a separate instance per PR environment. If yes, apply `mozcloud.preview.prefix` to the resource name directly (see `templates/externalsecret/externalsecret.yaml` for an example).

Resources that get preview prefix directly: `externalsecret`, `serviceaccount`, `pvc`, `configmap`.
Resources that inherit prefix via formatters: `deployment`, `hpa`, `cronjob` (names come out of `mozcloud.formatter.workloads` or `mozcloud.task.formatter.cronJob` already prefixed).
Resources that are intentionally not preview-aware: `job` (ephemeral, one-off) and `podmonitoring` (single shared monitoring resource).

## When adding a new resource type
In addition to the template and helper rules above, ensure the following are updated:
- **`values.yaml`** — add the new top-level key with the protected default entry and comments explaining all configuration options.
- **`values.schema.json`** — add the new top-level key with appropriate schema validation.
- **`linter_values.yaml`** — add a minimal valid entry so `helm lint` passes on required fields.
- **`common.values.yaml.example`** — add representative examples showing the key configuration options a user would need. It does not need to cover every variant, but should illustrate the most common usage (e.g., if a resource type supports subtypes like Deployment, StatefulSet, or Rollout, show the type field with an example).
- **`templates/_annotations.yaml` sync-wave defaults** — if the new resource type uses `mozcloud.annotations.argo`, add it to the `mozcloud.annotations.argo.syncWaveDefaults` lookup table with an appropriate sync-wave value, and add it to the accepted types listed in the helper's JSDoc comment. Current defaults for reference: `configMap: -11`, `externalSecret: -11`, `serviceAccount: -11`, `jobPreDeployment: -1`, `jobPostDeployment: 1` (deployments intentionally have no sync-wave).

## When testing changes to Helm templates or helpers
- Additional templates should include their own set of `helm unittest` tests.
  - In addition to generic `helm unittest` significant changes should have their own snapshot test.
- If no changes are made to existing templates ensure `helm unittest` passes without updates.
- Do not update existing tests unless we are reflecting a change to a template related to the test.
- Ensure `make unit-tests` results in all tests passing before finishing a change.
