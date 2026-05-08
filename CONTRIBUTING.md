# Contributing to helm-charts

This document covers the standards and workflows that apply to all contributors. Whether you are fixing a bug, adding a feature, or introducing a new chart, the guidance here applies.

For environment setup and available `make` targets, see the [README](README.md).

---

## Contribution workflow

The typical loop for any change:

1. Make your changes.
2. Write or update unit tests to cover them.
3. Run `make update-dependencies && make unit-tests` to verify everything passes.
4. Commit. Pre-commit hooks regenerate READMEs and run lint and tests automatically.
5. Open a PR. CI infers a release label from your PR title. Override it if needed (see [Release process](#release-process)).
6. Merge. CI bumps chart versions, updates docs, and publishes charts to the registry automatically.

---

## Release process

Chart versions are bumped and charts are published automatically when a PR is merged. You do not need to bump versions manually.

### How the release type is determined

When you open a PR, CI reads the title and applies a release label automatically:

| PR title pattern | Label applied |
|---|---|
| `feat!:`, `fix!:`, or contains "breaking change" | `major` |
| `feat:` | `minor` |
| Everything else (`fix:`, `chore:`, `docs:`, `refactor:`, etc.) | `patch` |

### One release type per PR

The release label applies uniformly to every chart changed in the PR. When a PR touches multiple charts with changes of different severity, all of them are bumped at the highest level present. For example, if one chart warrants a `major` bump and another only a bug fix, both get a `major` bump. This is a known limitation of the model. If the mismatch matters, split the changes into separate PRs so each chart gets the appropriate release type.

### Overriding the release label

If the inferred label is wrong, apply the correct one manually from the PR sidebar before merging:

- `major`: significant change warranting a major version increment; often breaking, but not necessarily
- `minor`: new functionality, backwards compatible
- `patch`: bug fix or non-functional change
- `no-release`: merge without bumping or publishing (e.g. docs-only changes)

`no-release` takes precedence over any other label. To use it, add `no-release` to the PR. The other labels follow highest-severity-wins: if both `minor` and `patch` are present, `minor` wins. To avoid confusion, remove any label you are replacing rather than adding on top of it.

### What happens on merge

When the PR is merged, CI:

1. Bumps the version of every changed chart using the release type
2. Cascades the bump to any dependent charts and updates their dependency version references
3. Regenerates all `README.md` files via helm-docs
4. Commits the result directly to `main`
5. Packages and pushes the updated charts to the OCI registry
6. Creates a git tag for each published chart

### Releasing without a PR

To bump and publish charts without opening a PR (for example, to cut a hotfix or perform an administrative bump), use the **manually release helm charts** workflow dispatch from the GitHub Actions tab. It accepts a comma-separated list of chart paths and a release type.

---

## Pre-commit hooks

Running `make install` sets up pre-commit hooks that run automatically on commit:
- **ruff**: formats and lints Python/TOML files (with auto-fix)
- **helm update dependencies**: runs `make update-dependencies` when chart files change
- **helm lint**: lints all non-deprecated charts
- **helm unittest**: runs `make unit-tests-affected` when chart files change
- **helm-docs**: regenerates `README.md` files from `.gotmpl` templates

If a hook fails, address the reported issue before committing. Do not skip hooks.

---

## Unit tests

Every addition or change to a chart must be covered by a unit test. Tests are written using [helm-unittest](https://github.com/helm-unittest/helm-unittest) and live in each chart's `tests/` directory. The `mozcloud/application` chart has the most comprehensive test suite in this repo and is the best reference for examples and conventions. For a full reference of available test syntax and assertion types, see the [helm-unittest documentation](https://github.com/helm-unittest/helm-unittest/blob/main/DOCUMENT.md).

### Test file anatomy

Each test file is a YAML document with the following top-level fields:

```yaml
suite: "mozcloud: Descriptive suite name"
release:
  name: mozcloud-test
  namespace: mozcloud-test-dev
chart:
  version: 1.0.0   # Pin to a fixed version to prevent snapshot churn on every chart bump
values:
  - values/globals.yaml              # Shared baseline values required by all tests
  - values/my-scenario.yaml          # Scenario-specific values for this suite
templates:
  - workload/deployment.yaml         # Limit rendering to only the templates under test
  - workload/hpa.yaml
tests:
  - it: Configuration matches entire snapshot
    asserts:
      - notFailedTemplate: {}
      - matchSnapshot: {}
  - it: Deployment has correct replica settings
    template: workload/deployment.yaml
    documentSelector:
      path: $[?(@.kind == "Deployment")].metadata.name
      value: my-workload
    asserts:
      - equal:
          path: spec.replicas
          value: 2
```

Conventions to follow:

- **Pin `chart.version` to `1.0.0`.** The labels library embeds the chart version in resource labels, so leaving it unpinned causes every snapshot to change on every chart bump, adding noise to PR diffs that is unrelated to the change being reviewed.
- **Always include `notFailedTemplate` and `matchSnapshot` in the first `it:` block.** `notFailedTemplate` catches render errors; `matchSnapshot` is the primary regression safety net (see [Snapshots](#snapshots) below). Keep them in the same `it:` so the chart is only rendered once for both.
- **Prefer fewer `it:` blocks with more assertions.** helm-unittest re-renders the full chart for every `it:` block, which is the dominant cost of the suite. Group assertions under a single `it:` when they share a semantic theme, and use per-assert `template` and `documentSelector` when you need to target different documents within the same group. Split into a new `it:` only when the test requires a different `set` / `values` override, or when splitting genuinely clarifies intent.
- **Scope your `templates` list to only the templates relevant to the scenario.** Rendering every template in every suite adds noise and slows tests down.

### Values organization

Shared values that every test suite needs (e.g. global platform values the chart requires) live in `tests/values/globals.yaml`. Scenario-specific values live in separate named files:

```
tests/
  values/
    globals.yaml                    # Required by all suites
    basic-configuration.yaml        # Values for the basic workload test suite
    multi-containers.yaml           # Values for the multi-container test suite
    ...
  basic-workload-configuration_test.yaml
  multi-containers_test.yaml
  ...
  __snapshot__/                     # Auto-generated; do not edit by hand
```

Each scenario-specific values file should contain only the values that make that scenario distinct. Share as little as possible between scenarios so that test failures are easy to localize.

### Assertions

helm-unittest provides a range of assertion types. The most commonly used in this repo are listed below. For the full reference, see the [helm-unittest documentation](https://github.com/helm-unittest/helm-unittest/blob/main/DOCUMENT.md).

| Assertion | What it checks |
|---|---|
| `notFailedTemplate` | Template renders without error |
| `failedTemplate` + `errorPattern` | Template fails with a specific error message |
| `matchSnapshot` | Full rendered output matches saved snapshot |
| `hasDocuments` | Number of rendered documents |
| `equal` | Exact value at a JSONPath |
| `isSubset` | Object at a JSONPath contains the expected keys (partial match) |
| `contains` | List at a JSONPath contains the expected element |
| `lengthEqual` | List at a JSONPath has the expected length |
| `exists` / `isNotNullOrEmpty` | Field is present and non-empty |

Use `documentSelector` to target a specific document when a template renders multiple resources:

```yaml
documentSelector:
  path: $[?(@.kind == "Deployment")].metadata.name
  value: my-workload
```

Use the inline `set` field to override a specific value for a single test case without creating a separate values file:

```yaml
- it: Schema rejects invalid enum value
  template: workload/deployment.yaml
  set:
    workloads.my-workload.type: invalid-type
  asserts:
    - failedTemplate:
        errorPattern: "invalid-type"
```

### Snapshots

Snapshots are the primary safety net for catching unintended changes. When tests run, helm-unittest renders the templates and compares the output against the saved snapshot files in `tests/__snapshot__/`. If the output differs from what was saved, the test fails.

**A snapshot should only change when you intend to change the template output.** If you make a change that is not supposed to affect rendered manifests and a snapshot diff appears, treat that as a bug signal and investigate before proceeding. Do not update snapshots just to make the test pass without understanding why the output changed.

Snapshot diffs appear in PR diffs and should be reviewed with the same care as code changes. Reviewers should verify that every line in a snapshot diff is a deliberate consequence of the change being made.

When your change intentionally modifies rendered output, update snapshots explicitly:

```sh
make unit-tests UPDATE_SNAPSHOTS=1
```

Commit the updated snapshot files alongside your change so reviewers can see exactly what shifted.

### Running tests

Before opening a PR, run the full suite:

```sh
make update-dependencies && make unit-tests
```

For a faster feedback loop while iterating on a specific chart:

```sh
make unit-tests-affected
```

---

## JSON schema validation

Every application chart ships a `values.schema.json` that Helm validates against when rendering the chart. **Any addition, removal, or rename of a key in `values.yaml` must be reflected in `values.schema.json`.**

Letting the two files drift causes one of two problems: unrecognized keys silently pass through without validation, or valid keys are rejected with confusing errors. The schema also surfaces documentation in editor tooling (e.g. the VS Code YAML extension), so keeping it accurate and well-described benefits every team using the chart.

### Schema conventions

All application chart schemas in this repo target [JSON Schema draft 2020-12](https://json-schema.org/draft/2020-12/schema) and follow these conventions:

- **`additionalProperties: false`** is set on every object whose shape is fully known. This turns typos and unrecognized keys into hard errors rather than silent no-ops, which is one of the most effective ways to catch misconfiguration early.

- **`$defs`** are used for schema fragments that appear in more than one place. Add a new `$def` whenever a type is referenced from two or more locations and reference it with `$ref: "#/$defs/<name>"`. Do not copy-paste the same shape inline.

- **`description`** fields are strongly encouraged on every user-facing property. Write descriptions as full sentences.

- **`enum`** is used to constrain string fields to a known set of values wherever applicable. When adding a new string field that only accepts specific values, use `enum` rather than leaving the type open.

- **`required`** lists the fields that must be present for a resource to be valid. Do not mark optional fields as required just because they have defaults. Rely on `default` for those instead.

- **`default`** values in the schema should match the defaults in `values.yaml`. If they diverge, the schema governs validation but `values.yaml` governs rendering. Keep them in sync.

- **Strict typing.** Prefer single-type definitions for fields. Don't introduce new `anyOf`/`oneOf` to let a field accept multiple shapes (e.g., string OR object). Instead, add a new, separately-named field with its own strict type. Existing `anyOf`/`oneOf` usages aren't a sweep-replace target. Leave them unless the surrounding code is being refactored anyway. Exception: when the upstream Kubernetes CRD or resource genuinely accepts multiple types for a field (most commonly number-vs-string, e.g. `IntOrString` types), mirroring that ambiguity with `anyOf`/`oneOf` is acceptable. Validate against the actual CRD definition before going this route.

### Keep schema and values.yaml in sync

Every value referenced by a template should appear in both `values.yaml` (as a documented default) and `values.schema.json` (with a strict type definition). Letting the two files drift causes one of two problems: unrecognized keys silently pass through without validation, or valid keys are rejected with confusing errors. The schema also surfaces documentation in editor tooling (e.g. the VS Code YAML extension), so keeping it accurate and well-described benefits every team using the chart.

Three checks when adding or auditing values:

1. **Schema covers values.yaml.** Every key in `values.yaml` (including commented examples) has a corresponding schema entry.
2. **Schema covers template usage.** Every value referenced from a template (`.Values.foo`, `$.Values.bar`) has a schema entry.
3. **Schema entries are used.** Every property defined in the schema is referenced somewhere in templates. Dead schema entries should be removed.

When a check fails:
- Missing schema entry → add it with a strict type.
- Missing values.yaml entry → add a documented default (commented or uncommented per [Default values left uncommented](#default-values-left-uncommented)).
- Unused schema entry → remove it (or wire up the template, if the entry was added in anticipation).

### What to do when changing values

| Change type | Schema action required |
|---|---|
| Add a new key | Add a matching property with type, description, and (if applicable) default |
| Remove a key | Remove its property from the schema (and from any `required` arrays) |
| Rename a key | Remove the old property, add the new one |
| Restrict a string to specific values | Add or update an `enum` constraint |
| Add a new collection type | Add an `additionalProperties` entry with the item shape (or a `$ref`) |
| Extract a repeated shape | Move it into `$defs` and replace inline copies with `$ref` |

---

## General chart authoring standards

The following standards apply to all charts in this repository.

### Variable naming

Local variables inside templates and helper functions must use `$camelCase`.

### Type fidelity: prefer explicit keys over `toYaml`

Avoid rendering entire config blocks with `{{ $variable | toYaml | nindent N }}` unless you specifically intend to pass an opaque blob. Prefer explicit key rendering:

```yaml
# Preferred
resources:
  cpu: {{ $container.resources.cpu }}
  memory: {{ $container.resources.memory }}

# Avoid (unless you have a good reason)
resources: {{ $container.resources | toYaml | nindent 2 }}
```

`toYaml` converts all values to strings, which can silently clobber typed values (integers, booleans). Explicit rendering preserves types and makes the schema contract visible in the template itself.

The same principle applies to round-tripping through strings: avoid `toYaml` / `fromYaml` conversions unless you specifically need string serialization.

### Collections: dicts over lists

Collections that users configure should be defined as **dicts keyed by name**, not lists, wherever merging behavior matters.

Helm can deep-merge dicts across values files (e.g. `values.yaml` + `values-prod.yaml`), but it replaces lists wholesale. Using dicts allows users to define a base configuration in `values.yaml` and selectively override individual items in environment-specific files without repeating the entire definition.

#### Protected default keys

Charts that use dict-based collections can designate a **protected key** per collection type to act as a chart-level defaults template. The key is stripped from the rendered output and its values are deep-merged as a base under each user-defined entry, with user values taking precedence.

All charts that use this pattern designate `default` as the protected key for each collection. A user who defines a workload named `my-service` will automatically inherit all defaults from the `default` entry without having to repeat them.

Avoid naming your objects `default`, as that entry is treated as a defaults template rather than a real object (unless it is the only entry in the collection).

### Sibling key ordering in values.yaml and values.schema.json

At every nesting level in `values.yaml` and `values.schema.json`, sibling keys should be ordered alphabetically, with **priority keys** floated to the top of their block in this order:

1. **Gates**: keys that turn the block on/off: `enabled`, `create`.
2. **Discriminators**: keys whose value determines which other fields apply: `type`, `provider` (under `cloud`).
3. **Merge sources**: `default` (the protected key in dict-based collections; see [Protected default keys](#protected-default-keys)).

Priority keys are gates, discriminators, or merge sources — keys whose value determines whether the block is active or which other keys apply. New keys that fit one of those shapes (e.g., a future `kind`, `mode`, or `api` field that gates or discriminates) should be treated as priority keys too.

When inserting a new key:

- If it's a priority key, place it at the top in the order above.
- Otherwise, slot it into the correct alphabetical position among non-priority siblings.
- Don't silently re-sort an existing block whose neighbors are already non-alphabetical, unless that's the intentional scope of your change.

This rule does not apply to ordered constructs (`enum:` arrays, ordered lists), `Chart.yaml` (Helm-prescribed order), or test fixtures.

### Default values left uncommented

Prefer to leave default values **uncommented** in `values.yaml`. The chart's template logic should gracefully evaluate defaults (including empty values like `""`, `{}`, `[]`) and handle boolean conditionals correctly.

Uncommented defaults allow Helm to merge user-provided values with the actual default value, surfacing bugs in template logic that would otherwise be hidden by commented-out lines. They also serve as documentation and as a sanity check that the rendering pipeline handles the default case.

**Exception:** values that should be **conditionally defined** based on another field's value (e.g., a field that's only meaningful when another field has a specific `type`) should remain commented out **if** uncommenting them would change the rendered template output.

The test for "_is this conditional?_": uncomment the value with its default, render the chart, and compare output. If output changes, keep commented. If output is unchanged, leave uncommented.

If uncommenting a default changes output but the field isn't conceptually conditional, that's a sign the template logic isn't handling the default gracefully. Fix the template, then uncomment.

### Helper organization

Helper templates and named templates live in shared files within a chart's `templates/` directory:

- **`_helpers.tpl`**: pure Go template helpers: utility functions, name generators, and logic that doesn't produce YAML directly.
- **`_*.yaml`** (e.g. `_pod.yaml`, `_formatter.yaml`, `_annotations.yaml`, `_labels.yaml`): named templates that produce YAML structure or rely heavily on Helm template syntax.

**Single-use helpers should be inlined** in the template that uses them. Only extract a helper when it's reused across templates.

#### Helper naming conventions

Where a helper lives determines its prefix:

| Location | Prefix | Example |
|---|---|---|
| `templates/_helpers.tpl` | `mozcloud.` | `mozcloud.name`, `mozcloud.fullname` |
| `templates/<subdir>/_helpers.tpl` | `mozcloud.<subdir>.` | `mozcloud.configMap.<name>`, `mozcloud.preview.<name>` |
| `templates/_pod.yaml` | `pod.` | `pod.container.<name>` |
| `templates/_formatter.yaml` | `mozcloud.formatter.` | `mozcloud.formatter.workloads` |

Library charts use their own root prefix (e.g. `mozcloud-gateway-lib.<name>`).

#### Documenting helpers

Every helper should have a JSDoc-style comment block immediately above its definition:

```
{{- /*
Brief description of what the helper does.

Params:
  paramName (type): (required/optional) Description.

Returns:
  (type) Description of the return value.
*/ -}}
```

If a helper takes no params or returns nothing, omit those sections rather than writing "None".

#### Parameter naming

Function parameters should use `config` as the standard name across helpers. Avoid uniquely named parameters like `jobConfig` or `workloadConfig`. These make helpers harder to compose and obscure the fact that the same shape is being passed around.

### Reading optional values: prefer `default` over `dig`

When reading an optional value from a dict, use Helm's `default` function:

```
{{- $port := default 8080 $container.port -}}
```

Use `dig` only when:

1. You need to traverse a nested key chain that may have absent intermediate keys: `dig "otel" "enabled" true $config`.
2. A falsy value (empty string, `false`, `0`) is a meaningful signal that must be honored, not coerced back to the fallback. For example, `prefix: ""` to disable a default prefix:

   ```
   {{- $prefix := dig "prefix" "pr-" $config -}}
   ```

   Here, `$config.prefix: ""` (intentionally disabling the prefix) is preserved. `default "pr-" $config.prefix` would incorrectly fall back to `"pr-"`.

Avoid the `if hasKey ... then read` pattern; collapse it into a single `dig` call. `hasKey` is still appropriate when you genuinely need the boolean "was the key set?" for branching logic (rare).

---

## README generation

`README.md` files for charts are generated by `helm-docs` and must not be edited by hand. Changes will be overwritten. To update a chart's README, edit its `README.md.gotmpl` file, or create one in the chart directory to override the root `_README.md.gotmpl`. READMEs are regenerated automatically by the pre-commit hook.
