---
name: chart-standards
description: Ensures mozcloud Helm chart standards are used when making updates to both the mozcloud and supporting library charts
---

## General Rules for working with mozcloud Helm charts
- We are using Helm version 3 to create resuable Helm charts for our platform.
  - These charts are packaged and pushed to an OCI repository.
  - We deploy these charts using ArgoCD.
- Function and variable names should use camelCase in helpers and templates.
  - If functions are copied from other sources, convert the new function and variable names to camelCase.
- Function and variable names should always be named and have helpful names. Single word is preferable if possible, but prompt for more complex names.
- Prompt for approval for any changes to templates and helpers required outside of the current task.

## Core Helm Chart
The `mozcloud` Helm chart is our core component and what will be consumed by users of our internal platform. It generally consumes library charts and contains the vast majority of our logic. We want to keep this chart maintainable and reduce the reliance on library charts where possible.

The core interface to this chart for our end users is the Values file. This should contain default settings and comments to highlight various configuration options.

## Library Helm Charts
Any changes to library Helm charts should result in a new version of the `mozcloud` chart being published.

- `mozcloud-gateway-lib` this chart contains gateway api resources that are consumed by our `mozcloud` chart.
- `mozcloud-ingress-lib` this chart contains ingress resources that are consumed by our `mozcloud` chart.
- `mozcloud-labels-lib` this chart contains label resources that are consumed by our `mozcloud` chart.

## When creating or modifying Helm helpers
- Helper files should only be created when used by 2 or more templates or resources, single use helper functions can be embedded in template files directly.

- Helper files should live in the folder relative to where they are used and be named accordingly.
    - Helpers used by workload templates they would be in `templates/workload/_helpers.tpl` and their name starts with `workload.`
    - Common helpers should live in `templates/_common.tpl` and their name starts with `common.`
- Helpers should be clearly documented with inline comments
- Function parameters should be single purpose, clear and not overlapping with other parameters.
  - We should standardize on `config` across templates instead of uniquely named parameters like `jobConfig` or `workloadConfig`.

## When creating or modifying Helm templates
- Default values should exist in the template where possible.
- Templates should be the primary place where rendering and interpolation takes place.
- Complex functions in templates should be limited and offloaded to a helper function.
- Template folders should match the top level keys used in values.yaml. `configmap`, `workload`, etc.

## When testing changes to Helm templates or helpers
- Additional templates should include their own set of `helm unittest` tests.
  - In addition to generic `helm unittest` significant changes should have their own snapshot test.
- If no changes are made to existing templates ensure `helm unittest` passes without updates.
- Do not update existing tests unless we are reflecting a change to a template related to the test.
- Ensure `make unit-tests` results in all tests passing before finishing a change.
