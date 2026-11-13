# NKP Insights

Use this file from skill `nkp-observability`. NKP Insights is an Ultimate app. [live 2.19.0] On Starter and Pro, stop.

| File | Site variables |
|---|---|
| `~/nkp-site.env` secrets | `INSIGHTS_S3_ACCESS_KEY` `INSIGHTS_S3_SECRET_KEY` |

The secret lines: the user types them into `~/nkp-site.env` with an editor (rule 5). Only for I2 way C.

## Facts

- Two apps. `nkp-insights-management` runs on the management cluster and is on by default (Ultimate). `nkp-insights` (the engine) runs on each cluster that you want to watch. It is off by default. [pdf p.1087, p.1089] Catalog version 1.9.7 for both. [live 2.19.0]
- The engine needs `kube-prometheus-stack` and `cloudnative-pg` on the same cluster. [live 2.19.0][pdf p.307] With the default store, it also needs `rook-ceph` and `rook-ceph-cluster`. [pdf p.1088][live 2.19.0] CloudNativePG and the upgrade gate G6: skill `nkp-platform-apps-gitops` (file `catalogs.md`, K5).
- The engine has a PostgreSQL PVC `data-nkp-insights-postgresql-0` (8 GiB) in the workspace namespace. [pdf p.1088, p.1095]
- Scanners in the engine: Polaris, Pluto, Nova, Trivy (CVE), kube-bench (CIS). Trivy is **off** by default. kube-bench is on by default. [pdf p.1114-1123] Images in the bundle: `mesosphere/insights:1.9.7`, `aquasec/kube-bench:v0.14.0`, `mesosphere/trivy-bundles:0.64.1-20260929T031542Z`. [live 2.19.0]
- **Values.** All engine settings are values of the engine app. The guide sets them in the UI (Workspace, Applications, NKP Insights, Edit, Configuration). [pdf p.1119] With the CLI, use skill `nkp-platform-apps-gitops` (file `overrides.md`, O3 for a workspace, O4 for one cluster), `APP_ID=nkp-insights`. Put all engine values in one values file: the override replaces the old one. The guide names the ConfigMap `<app-id>-overrides` [pdf p.1099]. The HelmRelease of the engine app does not read that name directly; it reads only its defaults (O2 shows `valuesFrom`). [live 2.19.0, app tree] Use the name rule of `overrides.md` O3 item 3.

## I1. Enable the engine

1. Read the state:

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n kommander get appdeployment nkp-insights-management -o jsonpath='{.spec.appRef.name}{"\n"}'
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get appdeployments | grep -E 'NAME|nkp-insights|kube-prometheus-stack|cloudnative-pg|rook-ceph|cosi'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get helmreleases -A | grep -E 'NAME|insights|cloudnative-pg|rook-ceph'
```

2. Enable the needed apps first: `kube-prometheus-stack` (skill `nkp-observability` step 3), `cloudnative-pg`, and `rook-ceph` + `rook-ceph-cluster` for the default store. Then choose the store (I2). For a non-default store, make its values file and Secrets before the enable.
3. Enable the engine (`APP_ID=nkp-insights`) with skill `nkp-platform-apps-gitops` step 2 (`--config-overrides` when you made a values ConfigMap). On the management cluster, the workspace is `kommander-workspace`. [pdf p.1089] The guide example `nkp-insights-1.4.4` is old: use the ClusterApp name from step 3 of skill `nkp-observability`. [live 2.19.0]

Done when: `helmrelease/nkp-insights` is `True` on the target cluster, and the NKP UI (Insights, in the left menu) shows the cluster. Only admins see Insights by default; roles for other users: the guide UI steps [pdf p.1089-1093], RBAC with skill `nkp-identity-security`.

## I2. Object storage of the engine

| Way | Values | Source |
|---|---|---|
| A. Rook Ceph through COSI (default) | `backend.s3.cosi.className: cosi-ceph-nkp`, `accessClassName: cosi-ceph-nkp` | [pdf p.1096] |
| B. Nutanix Objects through COSI | `className: cosi-nutanix-nkp`, `accessClassName: cosi-nutanix-nkp` (existing bucket: add `bucketName` and `driverName: ntnx.objectstorage.k8s.io`) | [pdf p.1095-1096] |
| C. Any S3 with static keys (also Nutanix Objects with a private CA) | the block below | [pdf p.1097-1099] |

- COSI cannot take a custom CA. With a private CA on Nutanix Objects, the pods fail with `x509` errors: use way C. [pdf p.1095] The COSI driver app: skill `nkp-storage-backup` (file `object-storage.md`, O5).
- Way C needs: a bucket that the S3 admin made, with the policies `s3:DeleteObject`, `s3:DeleteObjectVersion`, `s3:GetBucketLocation`, `s3:GetObject`, `s3:ListBucket`, `s3:ListMultipartUploadParts`, `s3:PutObject`, `s3:PutLifecycleConfiguration`; at least 1 GB; a TTL in days; less than 10 ms latency and more than 1 Gb/s; a host name that resolves in the cluster. [pdf p.1097]

**Way C.**
1. The user puts `INSIGHTS_S3_ACCESS_KEY` and `INSIGHTS_S3_SECRET_KEY` in `~/nkp-site.env` (rule 5). Ask the user for the CA file path (if a private CA) as a shell value.
2. Make the Secrets on the target cluster in the workspace namespace (`kommander` on the management cluster). [pdf p.1098] Show the plan. After "yes":

```bash
# CHANGES  (creates the Insights S3 credentials Secret, and the CA Secret when ca is set)
source ~/nkp-<cluster>.env 2>/dev/null
ca=''
k=$(printenv INSIGHTS_S3_ACCESS_KEY >/dev/null && printenv INSIGHTS_S3_SECRET_KEY >/dev/null && echo ok); : "${k:?INSIGHTS_S3_ACCESS_KEY or INSIGHTS_S3_SECRET_KEY is not set}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$WORKSPACE_NS" create secret generic nkp-insights-objectstore-credentials --from-file=AWS_ACCESS_KEY_ID=<(printf %s "$(printenv INSIGHTS_S3_ACCESS_KEY)") --from-file=AWS_SECRET_ACCESS_KEY=<(printf %s "$(printenv INSIGHTS_S3_SECRET_KEY)") --dry-run=client -o yaml | kubectl --kubeconfig "$CLUSTER_KUBECONFIG" apply -f - -o name
[ -n "$ca" ] && kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$WORKSPACE_NS" create secret generic nkp-insights-s3-cert --from-file=ca.crt="$ca" --dry-run=client -o yaml | kubectl --kubeconfig "$CLUSTER_KUBECONFIG" apply -f - -o name
```

3. Values (ask the user for the endpoint, port, and bucket; leave out `caSecretName` without a CA) [pdf p.1098-1099]:

```yaml
backend:
  s3:
    cosi:
      enabled: false
    port: 443
    region: "us-east-1"
    endpoint: "objects.example.com"
    bucketName: nkp-insights
    disableSSL: false
    caSecretName: nkp-insights-s3-cert
    skipTLSVerification: false
cleanup:
  insightsTTL: "168h"
```

- `endpoint` has no `http://`. `region` is `us-east-1` for Nutanix Objects. `disableSSL: false` for HTTPS. `insightsTTL` is rounded up to whole days for S3. [pdf p.1098-1099]

Done when: the engine pods run, and their logs show no `x509`, `AccessDenied`, or lifecycle errors.

## I3. Trivy CVE scan, and a new Trivy DB on an air-gapped site

Values for the engine (one values file) [pdf p.1119, p.1122]:

```yaml
trivy:
  enabled: true
  schedule: "@every 2h"
```

- On a connected site, Insights gets a new DB before each scan. On an air-gapped site, it uses the DB in the bundle image, from the date of the release build. [pdf p.1119][live 2.19.0]
- Severities: Trivy `CRITICAL` → Critical; `HIGH`, `MEDIUM` → Warning; `LOW`, `UNKNOWN` → Notice. [pdf p.1119]

**New DB on an air-gapped site.** The bundle build on a connected host and the push are in skill `nkp-airgap` (file `prestage.md`, P4). This skill does the app edit:

1. Read the image now in use (the CronJob is on the target cluster, in the workspace namespace) [pdf p.1120]:

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$WORKSPACE_NS" get cronjob nkp-insights-trivy -o jsonpath='{.spec.jobTemplate.spec.template.spec.initContainers[?(@.name=="trivy")].image}{"\n"}'
```

The tag is `<trivy version>-<DB date>`, for example `0.64.1-20260929T031542Z`. [live 2.19.0]

2. After the P4 push, ask the user for the new tag (the file name `trivy-bundles-<version>-<date>.tar.gz` has it). Add to the engine values file [pdf p.1122]:

```yaml
trivy:
  enabled: true
  image:
    imageFull: docker.io/mesosphere/trivy-bundles:0.64.1-20260929T031542Z   # change the date part to the new tag
```

The example tag is the bundle tag. Put the user's new tag in its place. Keep `docker.io/mesosphere/trivy-bundles`: the registry mirror of the nodes serves it. [pdf p.1122] The Trivy version (the part before `-`) must be the same as in item 1.

3. Apply with gitops `overrides.md` O3 (all clusters of the workspace) or O4 (one cluster). Do it for each workspace. [pdf p.1122]

Done when: the item 1 check shows the new date. An `ImagePullBackOff` on the Trivy job: the tag is not in the registry (skill `nkp-airgap`).

## I4. Other engine settings

Values for the engine (one values file) [pdf p.1113-1123]:

| Goal | Values |
|---|---|
| Alerts also for NKP parts and Kubernetes parts (off by default) | `backend.engineConfig.nkpIdentification.enabled: false` |
| Polaris, Pluto, Nova on or off | `polaris.enabled`, `pluto.enabled`, `nova.enabled` (`true` or `false`) |
| Scan schedule | `polaris.schedule`, `pluto.schedule`, `nova.schedule`, `kubeBench.schedule` (for example `"@every 35m"`) |
| Nova: Helm repositories to check | `nova.helmRepositoryURLs` (a list). On an air-gapped site, only repositories inside the site work. |
| kube-bench off; a fixed CIS version | `kubeBench.enabled: false`; `kubeBench.config.instances.defaultSetup.additionalArgs: ["--version", "cis-1.15"]` |

- `DiskFull` and `PVCFull` alerts come always, also for NKP parts. [pdf p.1113]
- CIS fixes with cluster patch files are not for Nutanix AHV clusters. [pdf p.1124] CIS on NKP: skill `nkp-identity-security`.

## I5. Insights alerts to Slack

The engine sends its alerts to the Alertmanager of `kube-prometheus-stack` on the management cluster, with the labels `source: Insights`, `severity`, `insightClass`, `cluster`. [pdf p.1104-1107] Use skill `nkp-observability` file `monitoring.md`, M4 way B, on the management cluster, namespace `kommander`, with these route matchers [pdf p.1106-1107]:

```yaml
routes:
  - receiver: slack
    matchers:
      - name: source
        value: Insights
        matchType: "="
      - name: severity
        value: Critical
        matchType: "="
    continue: true
```

The guide groups by `['source', 'insightClass', 'severity', 'cluster']`. [pdf p.1106] Microsoft Teams needs an internet chart: not in the skills.

## I6. Uninstall

All steps are CHANGES. Show the plan for each. The PVC delete loses the Insights data. [pdf p.1093-1095]

1. Engine: delete the engine AppDeployment (`APP_ID=nkp-insights`) of each workspace (skill `nkp-platform-apps-gitops`, step 2, Disable). Wait until the HelmRelease is gone from the clusters:

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$WORKSPACE_NS" wait --for=delete helmrelease/nkp-insights --timeout=5m
```

2. Then delete the PVC on each cluster (after "yes"):

```bash
# CHANGES  (deletes the Insights PostgreSQL data on this cluster)
source ~/nkp-<cluster>.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$WORKSPACE_NS" delete pvc data-nkp-insights-postgresql-0
```

3. Management part (only to remove Insights fully): delete the AppDeployment `nkp-insights-management` in `kommander`, then the alert summaries. [pdf p.1095]

```bash
# CHANGES  (removes Insights management and all insight alert summaries)
source ~/nkp-site.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n kommander delete appdeployment nkp-insights-management
kubectl --kubeconfig "$MGMT_KUBECONFIG" delete insights --all -A
```

Done when: no `nkp-insights` HelmRelease and no Insights PVC is left.
