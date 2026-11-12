# Skanyxx's kagent fork

Upstream `v0.10.2` plus Anthropic prompt caching, until Skanyxx moves to an upstream release that has it (upstream
`main`/`v1.0.x` has it, but drops the `v1alpha2` API Skanyxx is built on).

| | |
|---|---|
| Branch | `skanyxx/v0.10.2-anthropic-caching` |
| Base | tag `v0.10.2` |
| Patch | upstream PR [#2789](https://github.com/kagent-dev/kagent/pull/2789) (backport of #2788, closed unmerged): commits `feat(models): add prompt caching for the Anthropic provider`, `test(adk): deep-copy caller objects …` |
| Version | `0.10.2-skanyxx.1` |
| Images | `ghcr.io/skanyxx/kagent/{controller,golang-adk,kagent-adk,app}:<version>` |
| Chart | `oci://ghcr.io/skanyxx/kagent/helm/kagent-crds` (upstream's `kagent` chart is used unchanged, with the images above) |

What the patch adds: `ModelConfig.spec.anthropic.promptCaching` (bool) and `cacheTTL` (`5m` | `1h`). When on, every
Messages API request marks the last tool, the last system block and the last block of the latest turn with
`cache_control`; usage reports `promptTokenCount` = input + cache read + cache write and `cachedContentTokenCount` =
cache read. Go and Python runtimes.

## Build and publish

```bash
hack/skanyxx/release.sh                 # local images (this machine's platform) + dist/kagent-crds-<version>.tgz
PUSH=true hack/skanyxx/release.sh       # amd64+arm64 images and the chart, pushed (docker/helm login to ghcr.io first)
```

A new fork release bumps `VERSION` in the script (`0.10.2-skanyxx.N`) and the pins in Skanyxx
(`deploy/helm/skanyxx/Chart.yaml`, `values.yaml`, `scripts/dev/kagent-values.yaml`, `scripts/dev/first-hour.sh`).
