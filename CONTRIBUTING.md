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

The release label applies uniformly to every chart changed in the PR. When a PR touches multiple charts with changes of different severity, all of them are bumped at the highest level present. For example, if one chart receives a breaking change and another only a bug fix, both get a `major` bump. This is a known limitation of the model. If the mismatch matters, split the changes into separate PRs so each chart gets the appropriate release type.

### Overriding the release label

If the inferred label is wrong, apply the correct one manually from the PR sidebar before merging:

- `major` — breaking change, incompatible with previous versions
- `minor` — new functionality, backwards compatible
- `patch` — bug fix or non-functional change
- `no-release` — merge without bumping or publishing (e.g. docs-only changes)

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
- **ruff** — formats and lints Python/TOML files (with auto-fix)
- **helm update dependencies** — runs `make update-dependencies` when chart files change
- **helm lint** — lints all non-deprecated charts
- **helm unittest** — runs `make unit-tests-affected` when chart files change
- **helm-docs** — regenerates `README.md` files from `.gotmpl` templates

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
  - it: Ensure no failures occur
    asserts:
      - notFailedTemplate: {}
  - it: Configuration matches entire snapshot
    asserts:
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
- **Always include `notFailedTemplate` as the first test in every suite.** This catches render errors before any other assertions run.
- **Always include `matchSnapshot`.** See [Snapshots](#snapshots) below.
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

---

## README generation

`README.md` files for charts are generated by `helm-docs` and must not be edited by hand. Changes will be overwritten. To update a chart's README, edit its `README.md.gotmpl` file, or create one in the chart directory to override the root `_README.md.gotmpl`. READMEs are regenerated automatically by the pre-commit hook.
