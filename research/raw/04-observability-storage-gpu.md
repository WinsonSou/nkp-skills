# Area 04 — Observability, Storage, Backup, GPU/AI (NKP 2.19)

Sources: PDF text `research/raw/pdf/2.19/` (primary) > web > field notes. `[field]` = field-note claim, not vendor-documented.
All names/IPs/secrets from field notes are scrubbed.

Cross-cutting facts used below:
- Platform apps are deployed as `AppDeployment` CRs (`apps.kommander.d2iq.io/v1alpha2|v1alpha3`); `spec.appRef.name` = `<app-id>-<chart-version>`, `kind: ClusterApp` for platform apps, `kind: App` for catalog apps; config comes from a ConfigMap referenced by `spec.configOverrides.name` (workspace-wide) or `spec.clusterConfigOverrides` (per cluster). [pdf p.271-273, p.298, p.348-350]
- Config-override ConfigMap shape is always `data.values.yaml: |` and lands in the **workspace namespace** (`kommander` on the management cluster). [pdf p.558-561]
- Workspace namespace lookup: `nkp get workspaces`. Management cluster = `kommander`; Ultimate workspace namespaces are generated (`kommander-<name>-<suffix>`). [pdf p.635, p.512]
- Flux `HelmRelease` per app lives in the workspace namespace; readiness check is `kubectl get helmreleases -n ${WORKSPACE_NAMESPACE}`. [pdf p.561-562]
- Air-gap pattern for everything here: images come from `nkp-air-gapped-bundle_<ver>_linux_amd64.tar.gz` → `nkp push bundle --bundle ./container-images/<konvoy|kommander>-image-bundle-<ver>.tar --to-registry=...`. Catalog apps need `nkp create catalog-bundle --airgapped --apps=<id>=<ver>` + `nkp push bundle` + `nkp create catalog-application --url oci://...`. [pdf p.995-996, p.339-340, p.1526]

---

## Components

### kube-prometheus-stack (Prometheus Monitoring)
- **What**: Umbrella Helm chart that installs the Prometheus Operator, Prometheus, Alertmanager, node-exporter, kube-state-metrics, Grafana and the default PrometheusRule/ServiceMonitor set.
- **Upstream**: prometheus-community/helm-charts `kube-prometheus-stack` — https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack
- **NKP role / name**: platform app id `kube-prometheus-stack`; UI label "Prometheus Monitoring". Deployed by default on the **management cluster and on every attached/managed cluster**. [pdf p.634]
- **Runs on**: management cluster + workload clusters.
- **Deployed by**: Kommander platform app (Flux HelmRelease) via `AppDeployment`; created with `nkp create appdeployment kube-prometheus-stack --app kube-prometheus-stack-82.13.6 --workspace ${WORKSPACE_NAME}`. [pdf p.264, p.271]
- **Default**: enabled (management cluster installer default `kube-prometheus-stack: enabled: true`). **Not** in NKP Starter licence — alerting/monitoring requires Pro/Ultimate. [pdf p.960, p.634]
- **Version in 2.19**: chart `kube-prometheus-stack-82.13.6` in 2.19 examples; older doc pages still show `kube-prometheus-stack-46.8.0` (stale example text — use the defaults ConfigMap on the cluster). [pdf p.271, p.317, p.1064]
- **Depends on / talks to**: cert-manager + traefik (ingress/UI), persistent storage for Prometheus (default StorageClass), Thanos Query (data source for centralized Grafana), prometheus-adapter (custom metrics), Alertmanager (notifications).
- **Sub-components** (all inside the chart): `prometheus-operator` (orchestrates), `prometheus` (TSDB + query), `alertmanager`, `node-exporter` (per node, hardware/OS), `kube-state-metrics` (object state), `grafana` (UI), ServiceMonitors. [pdf p.634]
- **Default ServiceMonitors**: kube-apiserver, kube-scheduler, kube-controller-manager, etcd, kube-dns/coredns, kube-proxy. [pdf p.644]
- **Air-gap notes**: images in the kommander image bundle; chart ships in the platform-app catalog; nothing special beyond the registry mirror. Grafana/Prometheus UIs are behind Traefik at `https://<CLUSTER_URL>/dkp/grafana` and `/dkp/alertmanager`. [pdf p.633, p.637]
- **Key CRDs / namespaces / CLI**: CRDs `monitoring.coreos.com/v1`: `Prometheus`, `ServiceMonitor`, `PrometheusRule`, `Probe`; `v1alpha1`: `AlertmanagerConfig`. Namespace = workspace namespace (typically `kommander`). Overrides ConfigMap name convention `kube-prometheus-stack-overrides`. Commands: `nkp edit appdeployment -n ${WORKSPACE_NAMESPACE} kube-prometheus-stack`, `kubectl get helmrelease -A | grep kube-prometheus-stack`. [pdf p.632, p.636, p.639]
- **Sizing (Nutanix-tested, Prometheus)**: 10 clusters/1k pods → 100m/500Mi req, 35Gi; 50 clusters/1.5k pods → 2 CPU/8Gi req, 100Gi; 200 clusters/10k pods → 15 CPU/50Gi req, 100Gi. Prometheus storage is set via `prometheus.prometheusSpec.storageSpec.volumeClaimTemplate`. [pdf p.631, p.646]
- **Sources**: [pdf p.629-645], [pdf p.271]

### Grafana (cluster-level, inside kube-prometheus-stack)
- **What**: Metrics/logs visualisation UI and dashboard host.
- **Upstream**: grafana/helm-charts `grafana` — https://github.com/grafana/helm-charts
- **NKP role / name**: installed as a sub-chart of `kube-prometheus-stack` (cluster Grafana) and separately as `grafana-logging` (log Grafana, see below). "Centralised Grafana" is a third instance (see `centralized-grafana`).
- **Runs on**: management + workload clusters.
- **Deployed by**: kube-prometheus-stack (sub-chart).
- **Default**: enabled with the stack. Dashboard access: `https://<CLUSTER_URL>/dkp/grafana`.
- **Version in 2.19**: UNKNOWN standalone; bundled with chart 82.13.6.
- **Depends on / talks to**: Prometheus (and Thanos Query on the management cluster), Loki (logging data source), Dex/traefik-forward-auth SSO.
- **Default dashboards**: Kubernetes Components (API server, nodes, pods, kubelet, scheduler, StatefulSets, PVs), Kubernetes USE (cluster, nodes), Calico, etcd, Prometheus; plus Thanos Query dashboard, Logging Operator, Loki, Ceph, NVIDIA DCGM exporter, NAI, Kasten (field catalog). [pdf p.632, p.640-641, p.549, p.554, p.619]
- **Air-gap notes**: none specific; dashboards embedded in the chart.
- **Key CRDs / namespaces / CLI**: dashboards via ConfigMap sidecar. Cluster Grafana expects label `grafana_dashboard: "1"`; the **centralised** Grafana expects `grafana_dashboard_kommander: "1"`. Disable defaults with `grafana.defaultDashboardsEnabled: false`. [pdf p.632-634, p.640]
- **Sources**: [pdf p.632-634, p.640]

### centralized-grafana
- **What**: Dedicated Grafana instance on the management cluster for multi-cluster (centralised) monitoring; queries Thanos Query.
- **Upstream**: grafana (see above); NKP wrapper.
- **NKP role / name**: platform app `centralized-grafana`, "only applicable for management clusters", marked internal in the app table.
- **Runs on**: management cluster.
- **Deployed by**: Kommander platform app (default internal).
- **Default**: enabled on management clusters (internal app). Licence tier: management-cluster-only.
- **Version in 2.19**: UNKNOWN.
- **Depends on / talks to**: `thanos` (data source), Dex (SSO), workspace Grafana is separate — "a separate Grafana instance from the one installed on all attached clusters". [pdf p.641]
- **Air-gap notes**: bundled.
- **Key CRDs / namespaces / CLI**: URL `https://<CLUSTER_URL>/dkp/kommander/monitoring/grafana`. Custom dashboard ConfigMap label `grafana_dashboard_kommander: "1"`. [pdf p.640-641]
- **Sources**: [pdf p.640-641, p.302]

### Thanos
- **What**: Centralised metrics read path — Thanos Query on the management cluster queries each cluster's Prometheus via a Thanos sidecar; provides long-term/global query view.
- **Upstream**: thanos-io/thanos — https://github.com/thanos-io/thanos (chart: bitnami/thanos or prometheus-community)
- **NKP role / name**: platform app `thanos`; "ThanOS: open-source, highly available Prometheus-compatible solution". Distinct item in the app table: "only applicable for management clusters", internal.
- **Runs on**: management cluster (Query) + Thanos sidecar alongside each Prometheus in attached/managed clusters.
- **Deployed by**: Kommander platform app (management cluster, internal).
- **Default**: enabled on management clusters.
- **Version in 2.19**: UNKNOWN.
- **Depends on / talks to**: Prometheus sidecars in every attached cluster; Grafana (centralized-grafana) as data source.
- **Constraint**: metrics are read **remotely**, not backed up. If an attached cluster goes down, its metrics and history disappear from the central view. [pdf p.641]
- **Air-gap notes**: bundled.
- **Key CRDs / namespaces / CLI**: Thanos Query UI `https://<CLUSTER_URL>/dkp/kommander/monitoring/query/`; verify sidecars at `.../query/stores`.
- **Sources**: [pdf p.640-641, p.302]

### Karma
- **What**: Alert dashboard that aggregates Alertmanager alerts from all attached clusters on one page.
- **Upstream**: prymitive/karma — https://github.com/prymitive/karma
- **NKP role / name**: platform app `karma` with required dependency `karma-traefik`; "only applicable for management clusters", internal.
- **Runs on**: management cluster.
- **Deployed by**: Kommander platform app.
- **Default**: enabled on management clusters (internal).
- **Version in 2.19**: UNKNOWN.
- **Depends on / talks to**: Alertmanagers in attached clusters; traefik.
- **Known limits**: **silencing alerts from the Karma UI is not supported**. With no attached clusters the UI shows a `placeholder.invalid` lookup error — expected. [pdf p.641]
- **Air-gap notes**: bundled.
- **Key CRDs / namespaces / CLI**: `https://<CLUSTER_URL>/dkp/kommander/monitoring/karma`.
- **Sources**: [pdf p.641, p.302]

### prometheus-adapter
- **What**: Exposes Prometheus metrics through the Kubernetes custom-metrics API so HPA (and other controllers) can scale on application metrics.
- **Upstream**: kubernetes-sigs/prometheus-adapter — https://github.com/kubernetes-sigs/prometheus-adapter
- **NKP role / name**: platform app `prometheus-adapter`, "Provides cluster metrics from Prometheus".
- **Runs on**: management + workload clusters.
- **Deployed by**: Kommander platform app.
- **Default**: **enabled** in the management-cluster installer defaults (`prometheus-adapter: enabled: true`); required dependency = `kube-prometheus-stack`. Disabled in the minimal test config. [pdf p.960, p.954, p.303]
- **Version in 2.19**: UNKNOWN.
- **Depends on / talks to**: kube-prometheus-stack (required), HPA.
- **Air-gap notes**: bundled.
- **Key CRDs / namespaces / CLI**: provides `custom.metrics.k8s.io` / `external.metrics.k8s.io` APIs; verify with `kubectl get apiservice | grep metrics`.
- **Sources**: [pdf p.302-303, p.960], [pdf p.629] (metrics-pipeline prerequisite for HPA)

### Custom alerts — PrometheusRule + AlertmanagerConfig + override ConfigMap
- **What**: Three supported ways to add/modify NKP alerts.
  1. **Overrides ConfigMap** (NKP-blessed): `kube-prometheus-stack-overrides` with `defaultRules.rules.<group>: false`, `defaultRules.create: false`, `additionalPrometheusRulesMap`, `mesosphereResources.rules.velero: true`.
  2. **`PrometheusRule` CR** with the label the operator selects.
  3. **`AlertmanagerConfig` CR** (`monitoring.coreos.com/v1alpha1`) in the workspace namespace for routes/receivers (Slack, Teams, email, PagerDuty).
- **Upstream**: prometheus-operator CRDs.
- **NKP role / name**: not a separate app — configuration surface of kube-prometheus-stack.
- **Runs on**: management + workload clusters.
- **Deployed by**: manual (kubectl), then referenced from the `AppDeployment`.
- **Default**: default rule groups enabled (node, kubelet, kube-apiserver, …); **Velero alert rules are OFF by default** and must be enabled only when the velero app is enabled. Disable platform services ⇒ disable their rules to avoid misfires. [pdf p.636]
- **Version in 2.19**: n/a.
- **Depends on / talks to**: Prometheus Operator rule selector; Alertmanager.
- **Details that matter for an agent**:
  - A user `ServiceMonitor` is only picked up when labelled `prometheus.kommander.d2iq.io/select: "true"`, **or** listed under `prometheus.additionalServiceMonitors` in the overrides ConfigMap. [pdf p.645]
  - Field-note `PrometheusRule` used `labels: release: kube-prometheus-stack` and worked [field: everything-nkp/customalert.yaml]; the vendor-documented path remains the overrides ConfigMap / `additionalPrometheusRulesMap`. Do not assume the `release:` label is selected on every NKP version.
  - Alertmanager config is **not** edited in-place: overwrite the Secret `alertmanager-kube-prometheus-stack-alertmanager` in the workspace namespace with `kubectl create secret generic ... --from-file=alertmanager.yaml --dry-run=client -o yaml | kubectl apply -f -`, then verify inside the pod at `/etc/alertmanager/config_out/alertmanager.env.yaml`. [pdf p.638-639]
  - Insights→Alertmanager notification example uses `AlertmanagerConfig` with `matchers: [{name: source, value: Insights}, {name: severity, value: Critical}]`, namespace `kommander`. [pdf p.1106-1107]
- **Air-gap notes**: none (config only).
- **Key CRDs / namespaces / CLI**: `PrometheusRule`, `AlertmanagerConfig`; secret `alertmanager-kube-prometheus-stack-alertmanager`; `kubectl exec -it alertmanager-kube-prometheus-stack-alertmanager-0 -n <ns> -- cat /etc/alertmanager/config_out/alertmanager.env.yaml`.
- **Sources**: [pdf p.635-639, p.645, p.1104-1107], [field: everything-nkp/customalert.yaml]

### OpenCost (cost monitoring; adjacent to monitoring)
- **What**: Real-time Kubernetes cost allocation/observability, shown in the NKP UI (replaces Kubecost).
- **Upstream**: opencost/opencost — https://github.com/opencost/opencost-helm-chart
- **NKP role / name**: platform app `opencost`; NKP enables it on the **management cluster** and collects cost metrics remotely from workload clusters. NKP UI shows cost for last day / 7 days per cluster, workspace, project.
- **Runs on**: management cluster (+ per-cluster metrics collection).
- **Deployed by**: Kommander platform app.
- **Default**: enabled with NKP **Ultimate**; optional dependency `kube-prometheus-stack`. [pdf p.642, p.302]
- **Version in 2.19**: UNKNOWN (retention follows the upstream chart defaults).
- **Depends on / talks to**: Prometheus, Rook Ceph (OpenCost is one of the four Ceph consumers).
- **Air-gap notes**: bundled; cloud-billing APIs (Cloud Costs tab) do not work air-gapped — only on-prem custom pricing via `opencost.customPricing`.
- **Key CRDs / namespaces / CLI**: custom pricing override in the workspace app config: `opencost.customPricing.{enabled,provider,costModel.{CPU,RAM,storage,GPU}}`.
- **Sources**: [pdf p.641-644, p.302]

### Logging Operator (Banzai Cloud / kube-logging)
- **What**: Operator that manages Fluent Bit (collector DaemonSet) and Fluentd (aggregator) from CRs, and routes logs to outputs.
- **Upstream**: kube-logging/logging-operator — https://github.com/kube-logging/logging-operator, docs https://kube-logging.dev
- **NKP role / name**: platform app `logging-operator`; NKP still calls it "BanzaiCloud Logging-operator". Deploys the `logging-operator-logging` HelmRelease (the Fluentd StatefulSet + Fluent Bit DaemonSet from the `Logging` CR).
- **Runs on**: management + workload clusters (per workspace).
- **Deployed by**: Kommander platform app: `nkp create appdeployment logging-operator --app logging-operator-6.4.0 --workspace ${WORKSPACE_NAME}`.
- **Default**: **enabled in the management-cluster installer defaults**, but **logging is disabled on managed/attached clusters by default** — enable per workspace/UI. [pdf p.960, p.546-547]
- **Version in 2.19**: `logging-operator-6.4.0` (+ `logging-operator-logging` HelmRelease). Upstream 6.4 adds `terminationGracePeriodSeconds` for Fluent Bit/Fluentd, `prometheusRulesOverride` for buffer-volume alerts. [pdf p.558], [web: https://kube-logging.dev/docs/whats-new/]
- **Depends on / talks to**: Grafana Loki (output), Rook Ceph (Loki backend), cert-manager + traefik (Grafana ingress), kube-prometheus-stack (Logging Operator Grafana dashboard + buffer metrics).
- **Fluent Bit buffering behaviour**: 5 MB memory buffer, 1 s flush, per-file checkpoints on host, 5 s grace on exit, 30 s pod termination grace; optional hostPath buffer volume. Buffer/positions hostPath is documented upstream. [pdf p.548]
- **Scaling**: Fluentd is usually the bottleneck. Sign of trouble = buffer directory growth beyond `timekey + timekey_wait`. Knobs: `fluentd.scaling.replicas`, `fluentd.disablePvc` + `emptyDir.medium: Memory`, `fluentbit.inputTail.Mem_Buf_Limit: 512MB`, disable the loki `clusterOutput` buffering. Tested sizing: 50 workers/1.4 MB/s → fluentd 10 replicas; 100 workers/8.5 MB/s → larger. [pdf p.548-549, p.275-276]
- **Air-gap notes**: images in the kommander bundle; no external dependency unless you forward logs out.
- **Key CRDs / namespaces / CLI**: `logging.banzaicloud.io/v1beta1`: `Logging`, `Flow`, `ClusterFlow`, `Output`, `ClusterOutput`. Governs every per-workspace Logging CR. Restrict namespaces with a `clusterFlows[0].spec.match[0].exclude.namespaces` override; override ConfigMap name `logging-operator-logging-overrides`. [pdf p.559-560, p.574]
- **Sources**: [pdf p.546-549, p.558-560, p.574, p.300-301]

### Fluent Bit (kollektor + admin/audit collector)
- **What**: Node-level log collector. Two roles in NKP: (a) the DaemonSet managed by the Logging Operator (pod logs), (b) the separate `fluent-bit` app that collects **admin logs** — Kubernetes audit, systemd/journal, kernel (`kmsg`).
- **Upstream**: fluent/fluent-bit — https://github.com/fluent/fluent-bit (chart: fluent/fluent-bit)
- **NKP role / name**: platform app `fluent-bit` (a.k.a. `kommander-fluent-bit` when talking about audit collection). Writes straight to the workspace Loki, bypassing the Logging Operator, so tenants cannot see admin logs.
- **Runs on**: workload clusters (admin-log collection) and management cluster when explicitly enabled.
- **Deployed by**: Kommander platform app: `nkp create appdeployment fluent-bit --app fluent-bit-0.57.2 --workspace ${WORKSPACE_NAME}`.
- **Default**: **disabled on the management cluster**. Enabling it multiplies logging-stack inbound traffic ~3-4× and costs **~2 GB/day/node** in Loki (10 nodes × 7 days ≈ +140 GB). [pdf p.555, p.570]
- **Version in 2.19**: `fluent-bit-0.57.2`.
- **Depends on / talks to**: `rook-ceph-cluster` sized for the extra volume, `grafana-loki-v3`.
- **systemd path override**: default `/var/log/journal`; for volatile journal (`/run/log/journal`) add `extraVolumes`/`extraVolumeMounts` `kubernetes-host` + `Path` in the `systemd` input, then override ConfigMap `fluent-bit-overrides`. Extraction of defaults: `kubectl get -n ${WORKSPACE_NAMESPACE} configmaps fluent-bit-0.57.2-config-defaults -o=jsonpath='{.data.values\.yaml}'`. [pdf p.570-573]
- **Air-gap notes**: bundled. Audit-log Fluent Bit needs the kube-apiserver audit policy/path configured at cluster creation (control-plane config) — cannot be changed afterwards. [pdf p.570]
- **Key CRDs / namespaces / CLI**: ConfigMap `<app>-config-defaults`, override ConfigMap, label in Loki: `log_source=kubernetes_host`.
- **Sources**: [pdf p.555, p.569-574]

### Grafana Loki (grafana-loki-v3)
- **What**: Label-indexed log store (does not index log bodies), deployed in **microservice mode** (distributor, ingester, querier, query-frontend, compactor, ruler, gateway).
- **Upstream**: grafana/loki — https://github.com/grafana/loki (chart: grafana/loki)
- **NKP role / name**: platform app `grafana-loki-v3` (project-level: `project-grafana-loki-v3`).
- **Runs on**: workload clusters per workspace; management cluster for the management workspace.
- **Deployed by**: Kommander platform app: `nkp create appdeployment grafana-loki-v3 --app grafana-loki-v3-3.6.7 --workspace ${WORKSPACE_NAME}`.
- **Default**: workspace-enabled (enabled on management cluster installer defaults; enable explicitly on attached clusters).
- **Version in 2.19**: `grafana-loki-v3-3.6.7` (v2 → v3 migration is automatic during platform upgrade; see Troubleshooting).
- **Depends on / talks to**: `rook-ceph-cluster` (S3 bucket `grafana-loki`, default backend), traefik + cert-manager (Grafana ingress), logging-operator (writes), grafana-logging (reads). Optional dependency table: `grafana-loki` → `rook-ceph-cluster`. [pdf p.300]
- **Storage/retention**: default retention **1 week** via the Compactor, minimum 24 h; set with `loki.structuredConfig.limits_config.retention_period` (e.g. `360h`). Default index type **boltdb-shipper**; migrate to **TSDB** (schema v13) only via a future-dated `schemaConfig` period + `tsdb_shipper` block; you **must** add a new period entry. [pdf p.551-552, p.560-561]
- **Object storage**: default Rook Ceph S3; alternatives: AWS S3 (`loki.structuredConfig.storage_config.aws.s3` + `extraEnvFrom` secret on ingester/querier/queryFrontend/compactor/ruler/distributor), any S3-compatible store (secret `nkp-loki` with `AWS_ACCESS_KEY_ID`/`AWS_SECRET_ACCESS_KEY`), or Nutanix Objects. [pdf p.550-551, p.660-661]
- **Scaling**: scale **ingesters first**; scale distributors only under real CPU pressure; distributors ≪ ingesters. [pdf p.549]
- **Air-gap notes**: bundled. External S3/Nutanix Objects endpoint must resolve inside the cluster (fix CoreDNS) and a custom CA must be provided where supported.
- **Key CRDs / namespaces / CLI**: gateway service `grafana-loki-loki-distributed-gateway.<workspace-ns>.svc.cluster.local:<port>` (the ClusterOutput URL NKP documents); override ConfigMaps `grafana-loki-v3-overrides`, `grafana-loki-v3-custom-overrides`; condition `LoggingStack/GrafanaLokiV3Deployed`.
- **Sources**: [pdf p.549-554, p.559-561, p.660-661, p.300]

### Grafana Logging (grafana-logging / project-grafana-logging)
- **What**: Grafana instance dedicated to Loki; the UI users actually query logs in.
- **Upstream**: grafana/helm-charts.
- **NKP role / name**: platform apps `grafana-logging` (workspace) and `project-grafana-logging` (multi-tenant).
- **Runs on**: workload clusters; one per workspace, plus one per Project for multi-tenancy.
- **Deployed by**: `nkp create appdeployment grafana-logging --app grafana-logging-11.3.3 --workspace ${WORKSPACE_NAME}`; project: `--app project-grafana-logging-11.3.3 --workspace ... --project ${PROJECT_NAME}`.
- **Default**: workspace-enabled together with Loki; project-level only when multi-tenant logging is turned on.
- **Version in 2.19**: `grafana-logging-11.3.3`, `project-grafana-logging-11.3.3`.
- **Depends on / talks to**: `grafana-loki-v3` / `project-grafana-loki-v3`; traefik + cert-manager **must** be deployed on the attached cluster or the UI is unreachable; Dex/traefik-forward-auth SSO.
- **Access URL**: read the ingress —
  `kubectl get ingress -n ${WORKSPACE_NAMESPACE} grafana-logging -o go-template=...` (workspace) and
  `kubectl get ingress -n ${PROJECT_NAMESPACE} ${PROJECT_NAMESPACE}-project-grafana-logging ...` (project), then append `/explore`. [pdf p.563, p.569]
- **Air-gap notes**: bundled.
- **Key CRDs / namespaces / CLI**: chart values; ingress names above; per-Project URL is unique per cluster — map WorkspaceRoleBinding/ClusterRoleBinding per Grafana instance. [pdf p.569]
- **Sources**: [pdf p.562-563, p.568-569]

### Multi-tenant logging (project-logging + project-grafana-loki-v3 + project-grafana-logging)
- **What**: Per-Project log isolation: a custom controller deploys a Loki+Grafana pair and a `Flow` in each Project namespace; a cluster-scoped pair with a `ClusterFlow` gives admins the whole view.
- **Upstream**: Nutanix application (`project-logging`) wrapped around kube-logging + Loki + Grafana.
- **NKP role / name**: platform apps `project-logging`, `project-grafana-loki-v3`, `project-grafana-logging`.
- **Runs on**: workload clusters, inside Project namespaces.
- **Deployed by**: `nkp create appdeployment project-grafana-loki-v3 --app project-grafana-loki-v3-3.6.7 --workspace ${W} --project ${P}` (plus the other two; see [pdf p.566]).
- **Default**: optional; **workspace-level logging is a prerequisite**; access control is per-Project RBAC. Projects are an Ultimate-licence construct. [pdf p.563-564]
- **Version in 2.19**: `project-logging-1.1.0`, `project-grafana-loki-v3-3.6.7`, `project-grafana-logging-11.3.3`.
- **Depends on / talks to**: workspace logging stack, `rook-ceph-cluster` bucket `project-grafana-loki` (cap set by `nkp.project-grafana-loki.maxSize`), grafana-loki + logging-operator (optional deps per app table). [pdf p.554, p.301]
- **Air-gap notes**: bundled.
- **Key CRDs / namespaces / CLI**: HelmReleases `project-grafana-logging`, `project-grafana-loki-v3`, `project-loki-object-bucket-claims` in the Project namespace; `kubectl get projects -n ${WORKSPACE_NAMESPACE}` (column `PROJECT NAMESPACE`).
- **Sources**: [pdf p.554, p.563-569, p.301]

### Rook Ceph (rook-ceph + rook-ceph-cluster)
- **What**: In-cluster Ceph object store (S3/RGW) that is NKP's **default blob storage** for logging (Loki), Velero backups, OpenCost and NKP Insights.
- **Upstream**: rook/rook — https://github.com/rook/rook (charts `rook-ceph`, `rook-ceph-cluster`)
- **NKP role / name**: platform apps `rook-ceph` (operator) and `rook-ceph-cluster` (the CephCluster + `dkp-object-store` CephObjectStore + buckets).
- **Runs on**: management cluster (namespace `kommander`) and workload clusters (workspace namespace).
- **Deployed by**: Kommander platform apps: `rook-ceph-1.19.5`, `rook-ceph-cluster-1.19.6`. Enabled by default on the management cluster.
- **Default**: enabled; **only** for NKP Insights, logging stack, Velero, Harbor, OpenCost — explicitly not a general application storage backend. Disable all four consumers to drop it. [pdf p.646-647]
- **Version in 2.19**: `rook-ceph-1.19.5`, `rook-ceph-cluster-1.19.6`; Ceph must be **19.2.3+** to expand OSD PVCs safely (19.2.1/2.2 crash the OSD during `expand-bluefs`). [pdf p.558, p.652]
- **Shape**: **PVC cluster mode** (Ceph relies on an existing CSI provisioner), so Ceph **cannot be the CSI provisioner** in this mode. Default layout: 4 × 40 GiB block PVCs (160 GiB raw) + 3 × 10 GiB MON PVCs, **erasure coding k=3/m=1 → 75 % efficiency ≈ 120 GiB usable** (earlier text also quotes 33 % overhead / 750 GB usable per 1000 GB — use the erasure-coding numbers). [pdf p.648-651, p.554]
- **Resources**: ≈2000m CPU / ≈8 GiB RAM total (mgr ×2, mon ×3, osd ×4, rgw ×2, crashcollector per node); ~4 nodes recommended, one OSD per worker node (Rook uses soft anti-affinity). [pdf p.649-650]
- **Growing it (upgrade-safe)**: **never** edit `rook-ceph-cluster-<ver>-config-defaults`, never patch `CephCluster`/OSD objects. Create `rook-ceph-cluster-config-overrides` in the workspace namespace with the **full** `storageClassDeviceSets` list entry copied from defaults, changed `count` (scale out, min 4) and/or `volumeClaimTemplates.spec.resources.requests.storage` (scale up), set `spec.configOverrides.name`, then fix OSD CRUSH weights (`ceph osd crush reweight osd.N <TiB>`). Growing OSDs does **not** raise the ObjectBucketClaim `maxSize`; raise `dkp.grafana-loki.additionalConfig.maxSize` / `nkp.project-grafana-loki.maxSize` separately. [pdf p.651-654]
- **Depends on / talks to**: default StorageClass supporting `volumeMode: Block`; consumed by grafana-loki, velero, opencost, NKP Insights (via COSI), Harbor.
- **Air-gap notes**: images in the kommander bundle.
- **Key CRDs / namespaces / CLI**: `ceph.rook.io/v1` `CephCluster`, `CephObjectStore`, `CephBlockPool`; `objectbucket.io/v1alpha1` `ObjectBucketClaim` (`maxSize` cap). Tools pod `deploy/rook-ceph-tools` → `ceph status|osd df|df|versions`. Dashboard password: `kubectl get secret -n ${NAMESPACE} rook-ceph-dashboard-password -ogo-template='{{ .data.password | base64decode }}'` (user `admin`). Known install failure: `CephObjectStore dkp-object-store` stuck Progressing → `radosgw-admin zonegroup default --rgw-zonegroup=dkp-object-store` + `period update --commit`, then restart `deploy/rook-ceph-operator`. [pdf p.655, p.1071-1072]
- **Sources**: [pdf p.554, p.646-655, p.1071-1072, p.300-301]

### COSI driver (Nutanix COSI / ceph COSI)
- **What**: Kubernetes Container Object Storage Interface driver that provisions S3 buckets + credentials from a `BucketClass`/`BucketAccessClass`, so apps do not hand-roll ObjectBucketClaims.
- **Upstream**: kubernetes-sigs/container-object-storage-interface; Nutanix CSI COSI driver.
- **NKP role / name**: platform app "COSI Driver Nutanix" (licence table); used by NKP Insights with class names `cosi-nutanix-nkp` (Nutanix Objects, driver `ntnx.objectstorage.k8s.io`) and `cosi-ceph-nkp` (Rook Ceph, driver `rook-ceph.ceph.objectstorage.k8s.io`). [pdf p.1096, p.295]
- **Runs on**: management + workload clusters (with Insights).
- **Deployed by**: Kommander platform app.
- **Default**: enabled where Insights/Nutanix Objects integration is used. **Do not disable** while another app (e.g. Harbor) still uses it. [pdf p.1097]
- **Version in 2.19**: UNKNOWN.
- **Depends on / talks to**: Rook Ceph or Nutanix Objects; NKP Insights backend.
- **Limits**: COSI **cannot** take a custom CA certificate — with a private CA on Nutanix Objects, use manual S3 + `caSecretName` instead. [pdf p.1095]
- **Air-gap notes**: bundled.
- **Key CRDs / namespaces / CLI**: `objectstorage.k8s.io` `BucketClass`, `BucketAccessClass`, `BucketClaim`; values `backend.s3.cosi.{className,accessClassName,driverName,bucketName}`.
- **Sources**: [pdf p.1095-1097, p.295]

---

### Nutanix CSI driver
- **What**: CSI driver for Nutanix Volumes (block), Nutanix Files (NFS) and hypervisor-attached volumes.
- **Upstream**: nutanix/nutanix-csi-driver; charts https://github.com/nutanix/helm (Nutanix CSI 3.0+ charts moved out of that repo index) — https://opendocs.nutanix.com
- **NKP role / name**: default storage provider on Nutanix infrastructure; provisioner `csi.nutanix.com`, default StorageClass `nutanix-volume`. Deployed as a cluster addon by CAREN/the cluster class, not an AppDeployment.
- **Runs on**: workload clusters on AHV (control-plane addon) — node plugin as DaemonSet in `ntnx-system`.
- **Deployed by**: CAPI cluster creation / CAREN addon (`nkp create cluster nutanix ...`); CSI config verified in preflight (storage containers must exist in Prism Central).
- **Default**: enabled on Nutanix; `allowVolumeExpansion: true` **by default on AHV** (false for other providers). [pdf p.38]
- **Version in 2.19**: driver **3.9.0** (default-storage table). NDK 2.3 needs CSI **3.7.1+** (UI 3.8+). [pdf p.37, p.338]
- **StorageClass parameters**: `storageType: NutanixVolumes|NutanixFiles`, `storageContainer`, `hypervisorAttached: ENABLED|DISABLED` (default ENABLED, toggled from UI/CLI), `flashMode`, `csi.storage.k8s.io/{provisioner,node-publish,controller-expand}-secret-{name,namespace}` (`nutanix-csi-credentials` / `ntnx-system`), `fstype`, `volumeBindingMode: WaitForFirstConsumer`. [pdf p.39, p.41]
- **Files**: `storageType: NutanixFiles` with `nfsPath`/`nfsServer` (static) or `dynamicProv: ENABLED` + `nfsServerName` (dynamic); needs a Files REST user in the secret (`files-key:`). [pdf p.329], [field: <vault>/NAI on NKP.md]
- **2.19 addition**: **AOS multi-writer** — ReadWriteMany file storage served directly from AOS through the CSI driver (new in 2.19). [web: https://www.nutanix.com/blog/production-ai-meets-dual-native-choice-with-nkp]
- **Immutability**: StorageClass parameters cannot be changed after creation — make a new StorageClass. Keep `Cluster.spec` (`allowExpansion`) consistent with the StorageClass. [pdf p.40, p.42]
- **Air-gap notes**: CSI images part of the konvoy/CAREN bundle; the *storage* side is on-prem so no registry involvement.
- **Key CRDs / namespaces / CLI**: `ntnx-system` namespace; secrets `nutanix-csi-credentials`(+`-files`); `kubectl get sc`, `kubectl patch sc nutanix-volume -p '{"allowVolumeExpansion":true}'`.
- **Sources**: [pdf p.37-45, p.338, p.329], [web]

### local-static-provisioner (localvolumeprovisioner)
- **What**: Watches `/mnt/disks` on each host and turns discovered mounts into local PVs.
- **Upstream**: kubernetes-sigs/sig-storage-local-static-provisioner — https://github.com/kubernetes-sigs/sig-storage-local-static-provisioner
- **NKP role / name**: platform app `localvolumeprovisioner`; **default StorageClass for pre-provisioned clusters**.
- **Runs on**: pre-provisioned workload clusters.
- **Deployed by**: Kommander platform app / pre-provisioned cluster defaults.
- **Default**: enabled as default SC on pre-provisioned; **not suitable for production** — replace with a production CSI. [pdf p.37-38, p.41]
- **Version in 2.19**: `2.8.0`.
- **Depends on / talks on**: node-level `/mnt/disks` directories (mount tmpfs/ext4 and the PV appears).
- **Air-gap notes**: bundled.
- **Key CRDs / namespaces / CLI**: SC `localvolumeprovisioner`; PV names `local-pv-*`; `kubectl get pv`. Disable by removing the default annotation from the SC and making another SC default.
- **Sources**: [pdf p.37-38, p.41, p.44-45]

### AWS EBS CSI driver
- **What**: Dynamic EBS volumes on EKS/NKP-on-AWS.
- **Upstream**: kubernetes-sigs/aws-ebs-csi-driver — https://github.com/kubernetes-sigs/aws-ebs-csi-driver
- **NKP role / name**: default provider on AWS; provisioner `ebs.csi.aws.com`, default SC `ebs-sc`, `type: gp3`, `fstype: ext4`, `volumeBindingMode: WaitForFirstConsumer`.
- **Runs on**: workload clusters on AWS/EKS.
- **Deployed by**: cluster addon (EKS addon / CAREN).
- **Default**: enabled, `allowVolumeExpansion: false` by default (non-Nutanix providers) — flip it. [pdf p.38]
- **Version in 2.19**: `1.62` (as printed in the default-storage table).
- **Depends on / talks to**: IAM policy `AmazonEBSCSIDriverPolicy` on the control-plane role for snapshots; Velero CSI snapshots need a `VolumeSnapshotClass` (`velero.io/csi-volumesnapshot-class: "true"`). [pdf p.476]
- **Air-gap notes**: n/a (cloud images from ECR public → mirror if the cluster is air-gapped).
- **Key CRDs / namespaces / CLI**: `kube-system` `ebs-csi-*` pods; `VolumeSnapshotClass aws`.
- **Sources**: [pdf p.37, p.40, p.42, p.476]

### Azure Disk CSI driver
- **What**: Dynamic Azure managed disks.
- **Upstream**: kubernetes-sigs/azuredisk-csi-driver.
- **NKP role / name**: default on Azure; provisioner `disk.csi.azure.com`, default SC `azuredisk-sc`, SKU `StandardSSD_LRS`.
- **Runs on**: workload clusters on Azure/AKS.
- **Deployed by**: cluster addon.
- **Default**: enabled; expansion off by default.
- **Version in 2.19**: `1.34.4`.
- **Depends on / talks to**: Azure credentials; Velero Azure plugin (`velero-plugin-for-microsoft-azure:v1.5.1` is the tested version) for BSL + snapshots.
- **Air-gap notes**: n/a.
- **Key CRDs / namespaces / CLI**: SC `azuredisk-sc`; storage-class conversion for migrations uses a Velero `change-storage-class-config` ConfigMap (`ebs-sc: azuredisk-sc`). [pdf p.523]
- **Sources**: [pdf p.37, p.523-526]

### GCP PD CSI driver (and Filestore)
- **What**: Dynamic GCE persistent disks; the docs also reference the Filestore CSI driver for NFS.
- **Upstream**: kubernetes-sigs/gcp-compute-persistent-disk-csi-driver.
- **NKP role / name**: default on GCP; provisioner `pd.csi.storage.gke.io`, default SC `csi-gce-pd`.
- **Runs on**: workload clusters on GCP/GKE.
- **Deployed by**: cluster addon.
- **Default**: enabled; expansion off by default.
- **Version in 2.19**: `1.15.4`.
- **Depends on / talks to**: GCP service account; Velero GCP plugin `v1.5.0` (tested).
- **Air-gap notes**: n/a.
- **Key CRDs / namespaces / CLI**: SC `csi-gce-pd`; Velero BSL `--provider gcp --credential=velero-gcp-credentials=gcp`.
- **Sources**: [pdf p.37, p.42, p.528-531]

### vSphere CSI driver
- **What**: Block volumes on vSphere (dynamic + static provisioning).
- **Upstream**: kubernetes-sigs/vsphere-csi-driver (VMware CSI).
- **NKP role / name**: default on vSphere; provisioner `csi.vsphere.vmware.com`, default SC `vsphere-raw-block-sc`.
- **Runs on**: workload clusters on vSphere.
- **Deployed by**: cluster addon.
- **Default**: enabled; expansion off by default.
- **Version in 2.19**: `3.4.0`.
- **Depends on / talks to**: vSphere credentials/CSI config Secret; `vsphere-raw-block-sc`.
- **Air-gap notes**: images must be mirrored for air-gapped vSphere installs.
- **Key CRDs / namespaces / CLI**: SC `vsphere-raw-block-sc`.
- **Sources**: [pdf p.37, p.41-43]

### CSI snapshot controller (external-snapshotter)
- **What**: `VolumeSnapshotClass`/`VolumeSnapshot`/`VolumeSnapshotContent` controller that lets Velero take CSI volume snapshots.
- **Upstream**: kubernetes-csi/external-snapshotter — https://github.com/kubernetes-csi/external-snapshotter; Nutanix snapshot chart in https://github.com/nutanix/helm
- **NKP role / name**: not an NKP-named app — comes with the cloud CSIs (the `snapshot-controller-*` pods run in `kube-system` on EKS). Nutanix ships a separate CSI snapshot chart.
- **Runs on**: workload clusters.
- **Deployed by**: CSI addon / manual.
- **Default**: present where the CSI provides it; **Velero node-agent (Kopia/Restic) is the default path**, snapshots are opt-in (`features: EnableCSI`).
- **Version in 2.19**: UNKNOWN.
- **Depends on / talks to**: Velero (`EnableCSI`), CSI driver, `VolumeSnapshotClass` with `velero.io/csi-volumesnapshot-class: "true"`.
- **Air-gap notes**: images must be mirrored.
- **Key CRDs / namespaces / CLI**: `snapshot.storage.k8s.io/v1` `VolumeSnapshotClass`, `VolumeSnapshot`; `velero client config set features=EnableCSI`.
- **Sources**: [pdf p.476-477, p.544]

### Nutanix Data Services for Kubernetes (NDK)
- **What**: Application-centric data management on NKP + Nutanix CSI: BCDR, replication/failover, data protection, app self-service, governance.
- **Upstream**: Nutanix product (proprietary); catalog definition https://github.com/nutanix-cloud-native/nkp-nutanix-product-catalog
- **NKP role / name**: **workspace catalog application** `ndk` (appears in the catalog repository, not as a platform app); cluster-scoped — one NDK instance per cluster. [pdf p.337-340]
- **Runs on**: management and workload clusters, **Nutanix infrastructure only**.
- **Deployed by**: NKP UI catalog enable, or `nkp create catalog-application --url oci://<registry>/nkp-nutanix-product-catalog/ndk --tag <ver> --workspace kommander-workspace`.
- **Default**: optional. Licence: Pro / Ultimate / NKPFS.
- **Version in 2.19**: **NDK 2.3** (compatibility list). [web: NKP 2.19 release notes]
- **Depends on / talks to**: Nutanix CSI 3.7.1+ (3.8+ for NDK UI); Prism Central admin account; AOS 7.5+/pc.7.5+; `iscsi-initiator-utils` on workers; PE cluster VIP for iSCSI; MetalLB address pool for `type: LoadBalancer`; DockerHub token (`nutanixndk`). [pdf p.337-339]
- **Air-gap notes**: images come from **Nutanix DockerHub**, not the generic NKP bundle. Bundle: `nkp create catalog-bundle --airgapped --apps=ndk="<ndk-version>"` then `nkp push bundle --bundle ndk-<ver>-airgapped.tar --to-registry-mirror-url=...`; the air-gapped bundle also ships `nutanix-product-catalog-<nkp-ver>-airgapped.tar`, needed **only** if you deploy NDK. Image-pull secret must be created **on every workload cluster** (not propagated). [pdf p.340, p.1526]
- **Key CRDs / namespaces / CLI**: namespaces `ntnx-system` (+ NDK namespace); NDK CRs (`StorageCluster`, `ReplicationTarget`, app replication CRs); NDK UI optional (needs TLS secret `ndk-ui-tls` + hashed local users, `ADMIN` role); UI does **not** support Files-backed apps. [pdf p.341-346], [field: everything-nkp/ndk/*]
- **Pre-2.17 method (historical)**: manual tarball `ndk-<ver>.tar` + `k8s-agent-<ver>.tar`, load/tag/push every image to the local registry, then `ndk-cli` onboarding. Superseded by the catalog app. [field: <vault>/NKP with NDK Unofficial Guide.md]
- **Sources**: [pdf p.337-346, p.1526], [web], [field]

### Nutanix Objects / BYOS object storage (for Loki, Velero, Insights)
- **What**: External S3-compatible object store (Nutanix Objects, AWS S3, or any S3) used instead of Rook Ceph.
- **Upstream**: Nutanix Objects (product); S3 API.
- **NKP role / name**: BYOS path: "Bring Your Own Storage (BYOS) to NKP Clusters" for Ceph, plus per-app S3 overrides. [pdf p.655, p.660]
- **Runs on**: outside the cluster.
- **Deployed by**: manual (buckets + secrets + AppDeployment overrides or installer config).
- **Default**: optional; **recommended for production** (Nutanix recommends external S3 for Velero and Ceph for logging only by default).
- **Version in 2.19**: n/a.
- **Depends on / talks to**: Velero (`s3Url`, `s3ForcePathStyle`, `insecureSkipTLSVerify`/`caCert`, `profile`), Loki (`storage_config.aws.s3`), NKP Insights (`backend.s3.*` + `caSecretName`), COSI (`cosi-nutanix-nkp`).
- **Hard requirements**: FQDN resolvable inside the cluster (fix CoreDNS); custom CA ⇒ secret + `caSecretName` (COSI cannot do this); each cluster needs **its own bucket**; Insights needs ≥1 GB, S3 TTL set to `N` days, latency <10 ms, >1 Gb/s, ~100 Mb/day. [pdf p.511, p.1095-1098]
- **Air-gap notes**: on-prem appliance, so no image pull; but credentials/CA and DNS must be pre-arranged.
- **Key CRDs / namespaces / CLI**: Secret with `[profile]` INI (`aws_access_key_id`/`aws_secret_access_key`), Velero `BackupStorageLocation`, `ObjectBucketClaim` for Ceph, S3 bucket policy verbs for Insights (`s3:GetObject`, `s3:PutObject`, `s3:ListBucket`, `s3:DeleteObject`, `s3:DeleteObjectVersion`, `s3:GetBucketLocation`, `s3:ListMultipartUploadParts`, `s3:PutLifecycleConfiguration`).
- **Sources**: [pdf p.511-518, p.655-661, p.1095-1100]

---

### Velero
- **What**: Backup/restore of cluster state, namespaces, CRs and PV data (node-agent Kopia/Restic; CSI snapshots opt-in).
- **Upstream**: vmware-tanzu/velero — https://github.com/vmware-tanzu/velero (chart `velero/velero`)
- **NKP role / name**: platform app `velero`. **Installed in the `kommander` namespace, not `velero`** — set `velero client config set namespace=kommander`. [pdf p.532]
- **Runs on**: management + workload clusters.
- **Deployed by**: Kommander platform app; default on the management cluster, optional dependency `rook-ceph-cluster` (removable — then configure external storage). [pdf p.305, p.960]
- **Default**: enabled; default schedule `velero-default` = **daily backup of all namespaces**, **no volume snapshots**. Licence: Pro/Ultimate. [pdf p.533]
- **Version in 2.19**: UNKNOWN (app version). Tested plugins: AWS `v1.1.0`, Azure `v1.5.1`, GCP `v1.5.0`; field notes ran `velero-plugin-for-aws:v1.7.0` + `velero-plugin-for-csi:v0.7.1` with `uploaderType: kopia`. [pdf p.519-531], [field: everything-nkp/velero/velero-gui-values.yaml]
- **Default BSL**: Rook Ceph `dkp-object-store` bucket `dkp-velero`, over **TLS with a self-signed certificate** (hence `--insecure-skip-tls-verify` on CLI calls). [pdf p.532]
- **Depends on / talks to**: `rook-ceph-cluster` (default) or external S3 (Nutanix Objects / AWS / Azure / GCS); a `pre-install` job `velero-pre-install` that waits on Rook Ceph (delete/recreate it if Rook Ceph is absent). [pdf p.516]
- **Restore caveats**: restore only into the **same NKP version and same cluster**; delete the `one-kommandercluster-per-kommander-workspace` ResourceQuota and disable the `kommander-validating` webhook `CREATE` rule before restore, then re-add it afterwards. `velero describe/logs` can fail against the internal Ceph BSL — check `kubectl logs -l name=velero -n kommander --tail -1`. [pdf p.535-536]
- **Management-cluster DR**: two patterns — standby management cluster's internal bucket, or external S3. Procedure: pause all CAPI clusters (`spec.paused: true`) → backup → resume; restore **in order**: workspaces → projects → AppDeployment-managed ConfigMaps (label `kommander.d2iq.io/managed-by-kind=AppDeployment`) → RBAC/`appdeployments,kommanderprojectroles,kommanderworkspaceroles,projectroles,virtualgroups` → `kommanderclusters` → CAPI secrets (`cluster.x-k8s.io/cluster-name`) → provider secrets (`cluster.x-k8s.io/provider`) → provider namespace secrets (`*cap*`) → CAPI CRDs (`cluster.x`,`preprovisioned`) → resume clusters. **No application volume backups** in this path. [pdf p.539-544]
- **Stateful workload example (Prometheus)**: annotate the pod `backup.velero.io/backup-volumes=<volume-name>` (volume, not PVC), remove `envFrom` from `deploy/velero` and `ds/node-agent`, `velero backup create restic-prometheus --include-namespaces=kommander --snapshot-volumes=false --selector=app.kubernetes.io/name=prometheus --storage-location <bsl>`; restore needs the Prometheus operator scaled to 0 + sts/PVC delete + `change-storage-class-config` ConfigMap when the target SC differs. [pdf p.544-546]
- **Air-gap notes**: bundled; external BSL endpoints must resolve internally; plugins must be in the mirror.
- **Key CRDs / namespaces / CLI**: `velero.io/v1` `Backup`, `Restore`, `Schedule`, `BackupStorageLocation`, `VolumeSnapshotLocation`, `DeleteBackupRequest`; plugin ConfigMaps `velero-overrides`; `kubectl get bsl -n ${WORKSPACE_NAMESPACE}` must be `Available`; `--snapshot-volumes=false` is the NKP default idiom.
- **Sources**: [pdf p.510-546, p.305, p.960], [field]

### Prism Central Backup and Recovery (PCBR)
- **What**: Nutanix-side protection of the management dependencies (PC entities, configs, AOS cluster associations) that NKP relies on.
- **Upstream**: Nutanix Prism Central feature (not a Kubernetes component).
- **NKP role / name**: documented as part of NKP backup/DR; requires PCBR licence on the PC.
- **Runs on**: Prism Central outside the cluster.
- **Deployed by**: n/a (Nutanix infrastructure).
- **Default**: optional prerequisite for NKP DR.
- **Version in 2.19**: n/a.
- **Depends on / talks to**: CAPX, CCM, CSI secrets (they store PC endpoints/credentials).
- **Recovery actions (same IP)**: re-import all NKP OS images into PC; restore the PC cluster name (region labels); reset the admin password to the pre-recovery value (or use a custom user — admin is factory-reset).
- **Recovery actions (new IP)**: everything above **plus** update the PC endpoint in the management `Cluster` resource, and in the CCM and CSI secrets. [pdf p.537-538]
- **Air-gap notes**: n/a.
- **Key CRDs / namespaces / CLI**: `Cluster` (CAPI/CAPX), CCM/CSI secrets in `ntnx-system`/`kube-system`.
- **Sources**: [pdf p.537-538]

### Kasten K10 (community/custom catalog app — NOT shipped by Nutanix)
- **What**: Veeam Kasten data-management platform (backup/restore, DR, app mobility) for Kubernetes.
- **Upstream**: kasten/k10 — https://docs.kasten.io (Helm repo `kasten-io`)
- **NKP role / name**: **custom catalog application** built in the NKP catalog format (`helm-repositories/`, `services/<app>/<version>/`, `metadata.yaml`, `defaults/cm.yaml`, Grafana dashboard). Category `Backup`, `scope: workspace`, `allowMultipleInstances: false`. Tested with K10 **7.5.8** in the field. [field: everything-nkp/nkp-kasten-catalog]
- **Runs on**: workload clusters (workspace).
- **Deployed by**: catalog `GitRepository` on the management cluster (label `kommander.d2iq.io/gitrepository-type: catalog`), then enable from the NKP UI; catalog apps use `appRef.kind: App`. **On 2.19 GitRepository-based catalogs are no longer supported — use `OCIRepository`.** [pdf p.348-350], [web: NKP 2.19 release notes]
- **Default**: not deployed; no Nutanix support statement. Licence: customer's Veeam licence.
- **Version in 2.19**: n/a (independent).
- **Depends on / talks to**: its own object storage / CSI VolumeSnapshotClass; Prometheus for dashboards.
- **Air-gap notes**: full manual mirror of Kasten images + charts into the local registry; catalog bundle via `nkp create catalog-bundle`.
- **Key CRDs / namespaces / CLI**: `k10.kasten.io` CRDs, namespace `kasten-io`; `kubectl get apps,clusterapps,appdeployments -A` to verify.
- **Sources**: [field: everything-nkp/nkp-kasten-catalog], [pdf p.348-350], [web]

---

### NVIDIA GPU Operator
- **What**: Manages NVIDIA drivers, container toolkit, device plugin, DCGM exporter, NFD/GFD and GPU feature labels on GPU nodes.
- **Upstream**: NVIDIA/gpu-operator — https://github.com/NVIDIA/gpu-operator (docs: NVIDIA Cloud Native Technologies)
- **NKP role / name**: platform app `nvidia-gpu-operator`; the only supported way to run NVIDIA passthrough/vGPU in NKP. It is also listed in the **AI Catalog** ("Deploy the NVIDIA GPU Operator from the AI Catalog and configure DRA"). [pdf p.610]
- **Runs on**: workload clusters (and management cluster for AI). GPUs can only be added to **worker** node pools, never control plane. [pdf p.611]
- **Deployed by**: Kommander platform app (UI toggle or `AppDeployment` `nvidia-gpu-operator-gpu-operator-<ver>` in `kommander`), config via `nvidia-gpu-operator-overrides`.
- **Default**: **optional** — enable after the cluster exists; licence Pro/Ultimate. Requires GPU-enabled node pool + a VM image with drivers (or precompiled drivers).
- **Version in 2.19**: chart version UNKNOWN (docs use placeholder `nvidia-gpu-operator-gpu-operator-version`); **supported NVIDIA driver = 580.x** (field example: 580.126.18). vGPU Token Operator UI shows `v1.0.7`. [pdf p.607], [pdf p.617]
- **Driver deployment options**: (a) custom OS image with drivers baked in via `nkp create image nutanix --gpu-name=...` / `--vgpu-runfile=...`; (b) **precompiled drivers** (recommended for production) with
  `driver: {enabled: true, usePrecompiled: true, version: 580, kernelModuleType: auto, image: driver}` + `nvidiaDriverRoot: /run/nvidia/driver` (valid for Nutanix-provided Ubuntu images). [pdf p.608-609, p.612, p.615]
- **Sharing**: MIG via node labels `nvidia.com/mig.config=all-1g.6gb` and `mig.strategy: single|mixed`; time-slicing via a `time-slicing-config` ConfigMap + `devicePlugin.config.name` with `sharing.timeSlicing.resources[{name: nvidia.com/gpu, replicas: 4}]`. [pdf p.612-615], [field: everything-nkp/nvidia-timeslicing/*]
- **MIG constraints**: MIG profiles hidden in UI/CLI from AOS 7.3/AHV 10.3 to prevent accidental assignment; **MIG is only supported with GPU passthrough VMs, not vGPU**. 2.19 release note: DRA supports GPU scheduling/slicing for NVIDIA **and** AMD, but "NVIDIA multi-instance GPU partitioning is not included" in the DRA path. [pdf p.612-613], [web: NKP 2.19 release notes]
- **DRA**: from 2.19, DRA is enabled by default (K8s 1.36+ / containerd 2.1.x with CDI); configure the operator to use the **DRA driver instead of the device plugin**, and keep them from conflicting on the same node pool. [pdf p.610]
- **Observability**: DCGM exporter + `NVIDIA DCGM Exporter Dashboard` in Kommander Grafana; DCGM `ServiceMonitor` (field values: `interval: 15s`, extra label `monitoring: apps`). Prereqs: operator/plugin pods healthy, exporter on all accelerator nodes, Prometheus scrape includes the targets, network policy allows the metrics path. [pdf p.619-620], [field]
- **Troubleshooting**: `nvidia-smi` on the node; toolkit version mismatch ⇒ `nvidia-dcgm` CrashLoop + validators `Init:CrashLoopBackOff` (fix by overriding the toolkit version via ConfigMap); missing NFD labels ⇒ label manually `feature.node.kubernetes.io/pci-0302_10de.present=true`. [pdf p.620-621]
- **Air-gap notes**: driver/toolkit/DCGM/validator images must be in the mirror; precompiled driver images are large — size the mirror accordingly. vGPU additionally needs an NVIDIA licence token (`.tok`) supplied by the `vGPU Token Operator`.
- **Key CRDs / namespaces / CLI**: namespace `nvidia-gpu-operator`; CRs `ClusterPolicy`; node labels `nvidia.com/gpu.present`, `nvidia.com/gpu.product`, `nvidia.com/vgpu.present`, `nvidia.com/mig.config`; `kubectl get pods -n nvidia-gpu-operator`; `kubectl delete appdeployment -n kommander nvidia-gpu-operator` to disable (delete GPU workloads first).
- **Sources**: [pdf p.607-621, p.1006], [field], [web]

### vGPU Token Operator
- **What**: Distributes the NVIDIA vGPU client-configuration token (licence) to vGPU nodes.
- **Upstream**: Nutanix application wrapping NVIDIA vGPU licensing.
- **NKP role / name**: platform app `vGPU Token Operator` (`v1.0.7`), configured with the client secret configuration token (`.tok`).
- **Runs on**: management / attached / managed clusters that have vGPU node pools.
- **Deployed by**: Kommander platform app (UI: Applications → vGPU Token Operator → Edit → paste token → Enable).
- **Default**: optional; required before creating vGPU node pools. Pro/Ultimate.
- **Version in 2.19**: `v1.0.7` (UI string).
- **Depends on / talks to**: NVIDIA licensing portal / cloud or delegated licence server; `nvidia-gpu-operator`.
- **Air-gap notes**: licensing needs reachability to a **delegated licence server**; the .tok is a customer secret.
- **Key CRDs / namespaces / CLI**: chart values hold the client secret token; verify node label `nvidia.com/vgpu.present: "true"`.
- **Sources**: [pdf p.611, p.617-619]

### AMD GPU Operator / AMD KMM Operator
- **What**: AMD accelerator driver management + Kernel Module Management.
- **Upstream**: rocm/gpu-operator — https://github.com/ROCm/gpu-operator ; kubernetes-sigs/kernel-module-management
- **NKP role / name**: platform apps `amd-gpu-operator` and `amd-kmm-operator` in the licence/app table; validated for AMD Instinct MI350 via the NKP Catalog in 2.19. [pdf p.296], [web: NKP 2.19 blog]
- **Runs on**: workload clusters with AMD GPUs.
- **Deployed by**: Kommander platform app / catalog.
- **Default**: optional. Pro/Ultimate.
- **Version in 2.19**: UNKNOWN (2.19 adds validated MI350 support).
- **Depends on / talks to**: DRA (2.19 supports GPU scheduling/slicing for AMD through DRA), observability stack.
- **Air-gap notes**: ROCm driver images must be mirrored (large).
- **Key CRDs / namespaces / CLI**: `DeviceConfig` (AMD GPU operator); `kubectl get pods -n <amd-ns>`.
- **Sources**: [pdf p.296, p.610], [web]

### AI Catalog applications (KAI Scheduler, Slurm Operator, Kueue, Kubeflow Pipelines, JupyterHub, Milvus Operator)
- **What**: Curated, validated AI/ML workload components deployed from the workspace catalog.
- **Upstream**: kai-scheduler (https://github.com/NVIDIA/KAI-Scheduler), slurm-operator (https://github.com/SlinkyProject/slurm-operator), kueue (https://github.com/kubernetes-sigs/kueue), kubeflow/pipelines, jupyterhub (z2jh), milvus-operator (https://github.com/zilliztech/milvus-operator).
- **NKP role / name**: **AI Catalog** workspace catalog apps. [pdf p.622-623]
- **Runs on**: management/attached/managed clusters in a workspace.
- **Deployed by**: workspace catalog (UI) — `AppDeployment` with `appRef.kind: App`.
- **Default**: optional; **requires NKP Pro or Ultimate** + a managed/attached cluster in a workspace. Prerequisites: NVIDIA GPU Operator (for GPU workloads), Prometheus+Grafana (observability), ingress/Gateway (external access), cert-manager, GPU node labels. [pdf p.624]
- **Version in 2.19**: UNKNOWN app versions; NAI dependencies pin: NAI-Envoy Gateway `v1.8.2`, KServe `v0.19.0`, OpenTelemetry Operator `v0.114.1`, LeaderWorkerSet `0.8.0`. [pdf p.329]
- **Role split (scheduler choice)**: Kueue = queue admission + gang scheduling; Slurm Operator = Slurm/HPC semantics; KAI Scheduler = policy/fairness for shared GPU pools. Configure GPU operator **before** the scheduler. [pdf p.623-625]
- **Metrics**: Kueue exposes job-queue metrics; KServe exposes inference-service metrics, collected by NKP monitoring in Prometheus exposition format. [pdf p.623]
- **Air-gap notes**: catalog bundles: `nkp create catalog-bundle --airgapped --apps=<app>=<ver>` then push; catalog repositories must be OCI on 2.19.
- **Key CRDs / namespaces / CLI**: Kueue `LocalQueue`/`ClusterQueue`/`Workload`; `kubectl get helmreleases -n ${WORKSPACE_NAMESPACE}`; NKP UI Application status.
- **Sources**: [pdf p.622-628, p.329]

### Nutanix Enterprise AI (NAI)
- **What**: Inference endpoint management for LLMs on Kubernetes — model catalog/deploy, API endpoints + keys, RBAC, UI, metrics dashboard.
- **Upstream**: Nutanix product; catalog definition `nkp-nutanix-product-catalog`. Bundles KServe, Envoy Gateway (NAI gateway), OpenTelemetry Operator, LeaderWorkerSet, CloudNativePG, Valkey/Redis, ClickHouse, Postgres, vLLM/TGI/HuggingFace runtimes.
- **NKP role / name**: workspace catalog application "Nutanix Enterprise AI"; also shipped as NAI product. Deployable on NKP **and** EKS.
- **Runs on**: management and workload clusters.
- **Deployed by**: NKP UI catalog enable (v2.16+; `nkp create catalog` is deprecated). Starts with the `nai-system` namespace.
- **Default**: optional; needs Pro/Ultimate + a **Nutanix DockerHub access token** (`nai-regcred`).
- **Version in 2.19**: **NAI 2.8.0 / 2.8.1** (upgrade only from 2.7.0). [pdf p.330], [web: NKP 2.19 release notes]
- **Prerequisites on the cluster**: cert-manager, Prometheus monitoring, NVIDIA GPU Operator, CloudNativePG, NAI-Envoy Gateway v1.8.2, KServe v0.19.0, OpenTelemetry Operator v0.114.1, LeaderWorkerSet 0.8.0; a **Files** StorageClass (e.g. `nai-nfs-storage`, `storageType: NutanixFiles`); `docker-registry` secret in **both** `nai-system` and `envoy-gateway-system`. [pdf p.329-330]
- **Profiles**: `default` (300 concurrent requests / 100 API keys), `c1k_k200`, `c5k_k1k` — pasted as app override at enable time. [pdf p.331]
- **Known limitation in 2.19**: some single-instance NAI configurations can block worker node drain during cluster upgrades. [web: NKP 2.19 release notes]
- **Air-gap notes**: NAI air-gapped bundle (helm charts + images) must be loaded and retagged to the local registry/Harbor project; image overrides are per-component (`naiApi`, `naiIam`, `naiInferenceUi`, `naiDatabase`, `nai-clickhouse-*`, `naiMonitoring`, `ai-gateway-helm`, …). NAI is **not** part of the generic NKP bundle.
- **Key CRDs / namespaces / CLI**: namespaces `nai-system`, `envoy-gateway-system`; `nai-ui` ConfigMap `dashboardLink`; secrets `nai-regcred`, `nai-certificate`, `runai-ca-cert`-style CA secrets; NAI monitoring ServiceMonitors point at `kommander` node-exporter/DCGM; storage overrides `naiApi.storageClassName`, `defaultStorageClassName`. [field: <vault>/NAI on NKP.md]
- **Sources**: [pdf p.327-336], [web], [field]

### Run:ai (field only — not a Nutanix-supported NKP app)
- **What**: GPU workload management/scheduling control plane (backend + cluster components).
- **Upstream**: run.ai (now NVIDIA) — `runai-backend`, `runai-cluster` Helm charts.
- **NKP role / name**: **none** — installed manually over NKP. [field]
- **Runs on**: management/backend + workload cluster.
- **Deployed by**: manual Helm into `runai-backend` and `runai` namespaces, images from the local Harbor project, custom CA secrets (`runai-ca-cert`), `nginx-ingress` as DaemonSet + LoadBalancer.
- **Default**: not deployed.
- **Version in 2.19**: n/a.
- **Depends on / talks to**: its own registry credentials, CA trust, GPU node taints (`nvidia.com/gpu=present:NoSchedule`) to reserve GPU nodes, Prometheus.
- **Air-gap notes**: all Run:ai images must be mirrored; `global.customCA.enabled=true`.
- **Key CRDs / namespaces / CLI**: namespaces `runai-backend`, `runai`; helm `control-plane.tgz`, `runai-cluster.tgz`.
- **Sources**: [field: <vault>/Run-ai installation on NKP.md]

### NKP Insights (Management + Engine)
- **What**: Predictive/rule-based anomaly detection over cluster events and metrics; alert table, root-cause analysis, recommended fixes; notifies via Alertmanager.
- **Upstream**: Nutanix application (`dkp-insights.d2iq.io` API group).
- **NKP role / name**: two apps — `nkp-insights-management` (management cluster, **enabled by default**) and `nkp-insights` / "Insights Engine" (each monitored cluster, must be enabled explicitly).
- **Runs on**: management cluster (management) + attached/managed clusters (engine); Pro single-cluster runs both on the same cluster.
- **Deployed by**: Kommander platform app; e.g. `nkp create appdeployment nkp-insights --app nkp-insights-1.4.4 --workspace kommander-workspace` (example version string).
- **Default**: management app enabled; engine opt-in per cluster. **Requires NKP Ultimate.**
- **Version in 2.19**: release notes reference **NKP Insights 1.9** (security alert forwarding, state restore after restart, image-tag CVE reports); PDF example app strings `nkp-insights-1.4.4` / `nkp-insights-1.6.8`; catalog bundle example references `nkp-insights-v2.5.0.tar.gz`. Treat the app string as cluster-specific. [pdf p.1089, p.1100-1101], [web]
- **Depends on / talks to**: Rook Ceph + rook-ceph-cluster, kube-prometheus-stack, **CloudNativePG**, COSI (or external S3). Storage backends: Rook Ceph via `cosi-ceph-nkp`, Nutanix Objects via `cosi-nutanix-nkp`, or manual S3 secret + `caSecretName`.
- **Resources**: management 100m/128Mi; backend 250m/128Mi; reforwarder 100m/64Mi; postgresql ~250m/256Mi + 1 PV 8Gi; resolution 100m/64Mi. PriorityClass `NKP Critical (100002000)`.
- **Data model**: alerts persist **72 h** unless updated; severities Critical/Warning/Notice; types Availability/Best Practices/Configuration/Security; statuses Open/Muted/Resolved (Resolved is irreversible).
- **RBAC**: summary cards → `dkp-insights.d2iq.io` resources `insights`, verbs get/list/watch; alert details → `virtual.backend.dkp-insights.d2iq.io` resources `insights, rca, solutions`, verb get.
- **Alerts to Slack/Teams**: `AlertmanagerConfig` (`monitoring.coreos.com/v1alpha1`) in `kommander` with matchers `source=Insights`, `severity=Critical`; webhook in a Secret (`slack-webhook`).
- **Air-gap notes**: enable via `kommander.yaml` with `nkp-insights-management.backend.s3.{endpoint,bucketSize,storageClassName: nkp-object-store,enableObjectBucketClaim: true}`; a catalog repository entry for `application-repositories/nkp-insights-*.tar.gz` is required. [pdf p.1100-1101]
- **Key CRDs / namespaces / CLI**: `Insight` CRs (`kubectl delete insights --all -A`); `kubectl delete pvc data-nkp-insights-postgresql-0 -n ${WORKSPACE_NAMESPACE}`; uninstall = `kubectl delete appdeployment -n kommander nkp-insights-management`.
- **Sources**: [pdf p.1086-1107, p.960], [web]

---

## Relationships

- kube-prometheus-stack -> prometheus-adapter: adapter reads Prometheus so HPA can use custom metrics. [pdf p.302-303]
- kube-prometheus-stack -> Thanos sidecar (per cluster) -> Thanos Query (management) -> centralized-grafana: the only way metrics cross clusters. [pdf p.640-641]
- Karma -> Alertmanagers of all attached clusters: read-only aggregation; silencing not supported. [pdf p.641]
- NKP Insights -> kube-prometheus-stack Alertmanager: `AlertmanagerConfig` with `source=Insights` matchers. [pdf p.1104-1107]
- logging-operator -> Fluent Bit DaemonSet + Fluentd StatefulSet -> Loki distributor/gateway: the workspace log write path. [pdf p.555-557]
- grafana-loki-v3 -> rook-ceph-cluster (`dkp-object-store`, bucket `grafana-loki`): default log storage; project logs use bucket `project-grafana-loki`. [pdf p.554, p.300]
- fluent-bit (admin logs) -> workspace Loki directly, **bypassing** logging-operator, to isolate sensitive logs. [pdf p.555]
- grafana-logging -> grafana-loki-v3: UI/data-source pair; both need traefik + cert-manager on the cluster. [pdf p.563]
- project-logging / project-grafana-loki-v3 / project-grafana-logging -> workspace logging stack: multi-tenancy is layered on top and requires workspace logging first. [pdf p.563-566]
- velero -> rook-ceph-cluster (`dkp-velero` bucket) by default, or external S3 (Nutanix Objects / AWS / Azure / GCS). [pdf p.510, p.532]
- rook-ceph-cluster -> default StorageClass (`nutanix-volume`): Ceph in PVC mode needs an existing CSI to bind its OSD/MON PVCs, so Ceph cannot be the CSI itself. [pdf p.648]
- Nutanix CSI -> `nutanix-csi-credentials` secret in `ntnx-system` -> Prism Central/Element: every StorageClass references those secrets. [pdf p.39]
- NDK -> Nutanix CSI (3.7.1+/3.8+): NDK is built on CSI snapshots/replication, Nutanix infra only. [pdf p.338]
- NAI -> NVIDIA GPU Operator + KServe + Envoy Gateway + CloudNativePG + OpenTelemetry Operator + LeaderWorkerSet + a Nutanix **Files** StorageClass. [pdf p.329]
- NAI -> Rook Ceph sizing: a 1 TiB object-store target ("such as Nutanix Enterprise AI") drives 4×500 GiB OSDs ≈ 1.5 TiB usable. [pdf p.652]
- AI Catalog schedulers -> NVIDIA GPU Operator: configure GPUs first, then Kueue/KAI/Slurm. [pdf p.623]
- NVIDIA GPU Operator -> kube-prometheus-stack: DCGM exporter via ServiceMonitor feeds the DCGM Grafana dashboard. [pdf p.619]
- NKP Insights -> Rook Ceph + kube-prometheus-stack + CloudNativePG + COSI: all four are hard prerequisites. [pdf p.1088]
- COSI -> Rook Ceph **or** Nutanix Objects: bucket + credentials for Insights, and the reason COSI must not be disabled while Harbor uses it. [pdf p.1095-1097]
- Prism Central (PCBR) -> CAPX / CCM / CSI secrets: a PC restore with a new IP invalidates them. [pdf p.538]

## Version deltas

| Version | Change in this area | Source |
|---|---|---|
| 2.16 | NAI reachable directly from the NKP UI as a catalog app (`nkp create catalog` deprecated); vGPU support requires NKP 2.16.0+; Ubuntu Pro as worker OS option | [pdf p.329, p.609], [web: nutanix.com/tech-center/blog/nutanix-kubernetes-platform-216-is-here] |
| 2.17 | **Kubecost → OpenCost** (Kubecost removed from the NKP UI; upgrade aborts if an active Kubecost licence exists unless resources are orphaned); **NDK installable from the NKP UI/catalog** instead of tarball + k8s-agent | [pdf p.642-644, p.339] |
| 2.18 | Management cluster runs in the `kommander` namespace (affects every `-n kommander` command); Kubernetes Dashboard deprecated (→ Headlamp in 2.19); KubeFed deprecated; AI Navigator Cluster Info Agent removed; NKP becomes **CNCF Certified Kubernetes AI Conformance** | [pdf p.641-note, p.1133], [web: itcs.lu/blog/nkp-218-released-verified], [web: NKP 2.19 blog] |
| 2.19 | **DRA enabled by default** (K8s 1.36.2 default, containerd 2.1.x/CDI) for NVIDIA **and** AMD (MIG partitioning not in the DRA path); **AI Catalog** (KAI Scheduler, Slurm Operator, Kueue, Kubeflow Pipelines, JupyterHub, Milvus Operator) for Pro/Ultimate; **AMD Instinct MI350** validated; **AOS multi-writer (RWX via Nutanix CSI)**; **Headlamp replaces Kubernetes Dashboard**; GitRepository catalogs no longer supported → **OCIRepository**; NDK 2.3; NAI 2.8.0/2.8.1; NKP Insights 1.9; `--kommander-applications-repository` flag removed; `nkp upgrade workspace` deprecated | [pdf p.610, p.622], [web: next.nutanix.com NKP 2.19], [web: NKP 2.19 blog] |
| Loki (2.18/2.19) | App id changed `grafana-loki` → **`grafana-loki-v3`**; the logging stack controller auto-converts v2 override ConfigMaps to v3 during upgrade and blocks on failure (condition `LoggingStack/GrafanaLokiV3Deployed`), needing manual conversion + `reconcile.loggingstack.nkp.nutanix.com/requestedAt` annotation | [pdf p.551-554] |
| Rook Ceph | OSD PVC expansion requires **Ceph 19.2.3+**; capacity increase must go through the AppDeployment override (editing defaults or patching `CephCluster` reverts on reconcile) | [pdf p.651-654] |
| Velero | `uploaderType: kopia` replaces Restic in newer field deployments (Restic still the documented label `backup.velero.io/backup-volumes`); AWS plugin v1.1.0 / Azure v1.5.1 / GCP v1.5.0 are the "tested" versions | [pdf p.519-531], [field] |

## Gaps / open questions

1. **Exact app versions for 2.19** (Velero, Thanos, Karma, prometheus-adapter, opencost, centralized-grafana, nvidia-gpu-operator, amd-gpu-operator, cosi, harbor) are not in the PDF text. They are only in the NVKP Release Notes on the support portal (login-gated) or in the `*-config-defaults` ConfigMaps on a live cluster. Use placeholders in skills and tell the agent to read:
   `kubectl get appdeployment <app> -n <ns> -o jsonpath='{.spec.appRef.name}'`.
2. **kube-prometheus-stack version is inconsistent** in the 2.19 PDF: `82.13.6` in the 2.19 pages (p.271, p.317) but `46.8.0` in older example blocks (p.1064, p.1058, p.1068). Confirm per cluster.
3. **Licence tier per app** cannot be read reliably from Table 22 (p.295-297) — the column alignment is destroyed in text extraction. Confirmed from prose only: Prometheus monitoring not in Starter (p.634), OpenCost Ultimate (p.642), Insights requires Ultimate (p.1088), multi-tenant logging needs Projects (Ultimate). Everything else = UNKNOWN; re-extract p.295-297 from the PDF as an image/table.
4. **`PrometheusRule` selection label**: the vendor path is the overrides ConfigMap / `prometheus.kommander.d2iq.io/select`. The `release: kube-prometheus-stack` label used in the field note worked on that cluster but is not documented — verify before teaching it.
5. **Kasten K10**: no Nutanix documentation, no support statement, version 7.5.8 from one field catalog. Also: the catalog `GitRepository` recipe in that repo is **broken on 2.19** (OCIRepository required).
6. **Nutanix Objects as a Loki/Velero backend**: documented generically ("S3 compatible"), but the PDF's concrete Nutanix Objects examples are for Velero (p.511-518) and Insights (p.1095-1098). No official Nutanix Objects → Loki procedure found; the Loki doc only shows AWS S3. Treat "Nutanix Objects for Loki" as field-only.
7. **Log forwarding to Splunk / Elastic / syslog** is **not** in the NKP PDF at all. Only syslog→Logstash, syslog/UDP→rsyslog and Prometheus `remoteWrite`→Elastic Agent appear in field notes. Any skill must present these as generic logging-operator `ClusterOutput` recipes, not vendor features.
8. **run:ai**: field-only, no NKP integration point, unsupported. Keep out of the skills or mark clearly as unsupported.
9. **MIG vs DRA**: PDF says MIG via node labels is supported; the 2.19 release note says DRA does not include MIG partitioning. Both are true for different code paths, but the exact "which one for which workload" guidance is missing. Needs a live-cluster check.
10. **GPU operator app version + `nvidiaDriverRoot`**: values in the PDF are annotated "specific to Nutanix-provided Ubuntu images" — behaviour on Rocky/RHEL or pre-provisioned/bare-metal is UNKNOWN.
11. **`nkp-insights` app versions** are contradictory across the PDF (`1.4.4`, `1.6.8`, `2.5.0` catalog tarball) while the 2.19 release note says Insights 1.9. Resolve from the cluster, not the docs.
12. **Thanos retention/object storage** (the "unlimited retention through object storage" claim in the app table) is not backed by any NKP procedure in the PDF — UNKNOWN whether NKP configures a Thanos object-storage bucket or only remote query.
