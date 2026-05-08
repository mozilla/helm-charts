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
- Before any tool call that requires user approval (Bash command, Edit, Write, etc.), narrate what you're about to do and why in the preceding text response, so the user can decide on the approval prompt with full context.
- Writing convention for "nginx" in prose (comments in `values.yaml`, schema `description` fields, template/helper comments, READMEs):
  - Use "NGINX" (all caps) when referring to NGINX generically as a product/brand.
  - Use lowercase `nginx` when referring to: a literal string value (image name, service identifier, file path), the `nginx` config block or its fields, the nginx sidecar container we deploy, or Kubernetes resources whose names contain lowercase `nginx`.
  - Never use "Nginx" (mixed case).

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

### Reading optional values
Prefer the `default` function for reading optional values from a dict. Reach for `dig` only when a falsy value (empty string, `false`, `0`) is a meaningful signal that must be honored — i.e., when the alternative would be a `hasKey` presence check.

- **Default form:** `{{- $v := default "fallback" $d.k -}}` — use whenever a falsy value should fall back to the default. This is the common case.
- **Use `dig` when** an empty/false/zero value is a legitimate signal that must not be overridden:
  ```
  {{- $prefix := dig "prefix" "pr-" $config -}}
  ```
  Here, `$config.prefix: ""` (intentionally disabling the prefix) is preserved. `default "pr-" $config.prefix` would incorrectly fall back to `"pr-"`.
- Avoid `hasKey` guards followed by reads — `dig` collapses that pattern into one expression.
- `hasKey` is still appropriate when you genuinely need the boolean "was the key set?" for branching logic (rare).

The mental rule: "Would I need `hasKey` here to distinguish absent from present-but-falsy?" If yes → `dig`. Otherwise → `default`.

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

## When editing `values.yaml` or `values.schema.json`

### Sibling key ordering
Order sibling keys alphabetically, with priority keys floated to the top of their block. This applies anywhere keys appear at the same nesting level: top-level properties, properties under `$defs.<X>.properties`, and sibling blocks in `values.yaml`.

**Priority keys** sit at the top, in this order:
1. **Gates** — turn the block on/off: `enabled`, `create`.
2. **Discriminators** — determine which other fields are meaningful: `type`, `provider` (under `cloud`).
3. **Merge sources** — `default` (the protected key in dict-based config; see "Dict-based configuration with protected default keys").

The mental model: priority keys are gates, discriminators, or merge sources — keys whose value determines whether the block is active or which other keys apply. New keys that fit one of those shapes (e.g., a future `kind`, `mode`, `api` field that gates or discriminates) should be treated as priority keys too.

When inserting a new key:
- If it's a priority key, place it at the top in the order above.
- Otherwise, slot it into the correct alphabetical position among non-priority siblings.
- Don't silently re-sort an existing block whose neighbors are already non-alphabetical — place only the new key correctly.

Does NOT apply to: `enum:` arrays and other ordered lists where order is semantically significant; `.tpl` template code; `Chart.yaml` (Helm-prescribed order); test fixtures.

### Strict typing
Prefer strict, single-type definitions for fields in `values.schema.json`. Do not introduce new `anyOf`/`oneOf` to let a field accept multiple shapes (e.g., string OR object) — instead, add a new, separately-named field with its own strict type. (Existing `anyOf`/`oneOf` usages aren't a sweep-replace target — leave them unless the surrounding code is being refactored anyway.)

**Example:** rather than making `tls.certs` accept both `[string]` and `[{name, domains}]`, add a new `tls.managedCertificates: [{name, domains}]` field — or use separate scalar fields (e.g. a toggle + an override) instead of an overloaded object list.

**Exception:** when the upstream Kubernetes CRD or resource genuinely accepts multiple types for a field (most commonly number-vs-string, e.g. `IntOrString` types), mirroring that ambiguity with `anyOf`/`oneOf` is acceptable. Validate against the actual CRD definition before going this route.

### Default values left uncommented
Prefer to leave default values **uncommented** in `values.yaml`. The chart's template logic should gracefully evaluate defaults — including empty values like `""`, `{}`, `[]` — and handle boolean conditionals correctly.

**Why:** uncommented defaults exercise the merging path with the actual default value, surfacing bugs in template logic that would otherwise be hidden by commented-out lines. They also serve as documentation AND as a sanity check that the rendering pipeline handles the default case.

**Exception:** values that should be **conditionally defined** based on another field's value (e.g., a field that's only meaningful when another field has a specific `type`) should remain commented out **if** uncommenting them would change the rendered template output.

**Test for "is this conditional?":** uncomment the value with its default, render the chart, and compare output. If output changes, keep commented. If output is unchanged, leave uncommented.

If uncommenting a default DOES change output but the field isn't conceptually conditional, that's a sign the template logic isn't handling the default gracefully — fix the template, then uncomment.

### Schema and values.yaml stay in sync
Every value referenced by a template should appear in both `values.yaml` (as a documented default) and `values.schema.json` (with a strict type definition).

Three checks when adding or auditing values:
1. **Schema covers values.yaml:** every key in `values.yaml` (including commented examples) has a corresponding schema entry.
2. **Schema covers template usage:** every value referenced from a template (`.Values.foo`, `$.Values.bar`) has a schema entry.
3. **Schema entries are used:** every property defined in the schema is referenced somewhere in templates. Dead schema entries should be removed.

When a check fails:
- Missing schema entry → add it with a strict type.
- Missing values.yaml entry → add a documented default (commented or uncommented per the "Default values left uncommented" rule above).
- Unused schema entry → remove it (or wire up the template, if the entry was added in anticipation).

## When testing changes to library charts
Before running unit tests after modifying a library chart, always run `make update-dependencies` first. Application charts cache library chart `.tgz` files under their `charts/` directory — without a dependency refresh, tests will run against the old cached version and changes will not be picked up.

## When testing changes to Helm templates or helpers
- Every change — including template modifications, helper changes, and values/schema updates — must be covered by a unit test, even if no new test file is needed.
- Additional templates should include their own set of `helm unittest` tests.
  - In addition to generic `helm unittest` significant changes should have their own snapshot test.
- If no changes are made to existing templates ensure `helm unittest` passes without updates.
- Do not update existing tests unless we are reflecting a change to a template related to the test.
- Ensure `make unit-tests` results in all tests passing before finishing a change.

### Running tests efficiently (Claude/agent guidance)
When running `make unit-tests` programmatically, redirect output to a scratch file and grep against the file rather than re-running tests just to re-read output. Re-run only after code changes. Use `UPDATE_SNAPSHOTS=1` when snapshots need updating.

```
make unit-tests > .scratch/unit-test-output.txt 2>&1
UPDATE_SNAPSHOTS=1 make unit-tests > .scratch/unit-test-output.txt 2>&1
```

The `.scratch/` directory is gitignored.

This is a recommendation, not a hard rule. If the user hasn't expressed a preference, ask before applying it the first time, and offer to save the answer as a memory so it can become durable across sessions.

### Unit test structure
Every test suite must open with a single `Configuration matches entire snapshot` case whose `asserts` contains both `notFailedTemplate: {}` and `matchSnapshot: {}`, in that order, before any feature-specific assertions.

**Exception:** test suites whose entire purpose is to verify a template fails (every `it:` uses `failedTemplate` or similar) are exempt — a `matchSnapshot` baseline cannot be rendered when the template fails. These suites should have a clear name indicating they test a failure case.

helm-unittest re-renders the full chart for every `it:` block, so keep the total number of `it:` blocks in a suite small. Group feature-specific assertions under a single `it:` when they share a theme, and use per-assert `template` and `documentSelector` to target different documents within a group. Only split into a new `it:` when the test needs a different `set` / `values` override, or when splitting genuinely clarifies intent.
