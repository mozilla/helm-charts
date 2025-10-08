# mozcloud-service-lib

This chart provides templates to build Kubernetes Services.

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
  - name: mozcloud-service-lib
    version: ~0.2.9
    repository: oci://us-west1-docker.pkg.dev/moz-fx-platform-artifacts/mozcloud-charts
```

> [!IMPORTANT]
> Make sure to set a valid version for your dependencies. Helm supports pinning exact versions as well as version ranges — see [chart best practices - dependencies - versions](https://helm.sh/docs/chart_best_practices/dependencies/#versions) for more details.

That’s it — subchart templates can now be included in your own chart.

> [!TIP]
> We build OCI artifacts automatically with [GHA](/.github/workflows/auto-push-tag-helm-charts.yaml). When a new artifact has been built, we add a matching [tag](https://github.com/mozilla/helm-charts/tags) to this repo as well. Use this to find out about available chart versions and/or browse the chart's code for a specific version.
