---
name: nkp-observability
description: >
  NKP monitoring and logging: Prometheus (kube-prometheus-stack), alert rules, Alertmanager receivers
  (Slack, email), Grafana dashboards, Thanos, Karma, centralized Grafana; logging stack (logging-operator,
  Fluent Bit admin and audit logs, ClusterOutput log forwarding to syslog, Splunk, Elasticsearch);
  Loki storage, retention, S3 or Nutanix Objects; NKP Insights, Trivy DB image.
metadata:
  nkp_versions: "2.19"
  last_verified: "2026-11-03"
  sources: "live 2.19.0, pdf 2.19, field"
---

# NKP observability

<!-- RULES:BEGIN -->
## Rules for every NKP skill

1. **Marks.** Line 1 of each command block is `# READ-ONLY`, `# CHANGES`, or `# USER-TERMINAL`. CHANGES: it changes a cluster, the infrastructure, a registry, the container engine, or a file on the operator host. USER-TERMINAL: it shows a secret on the screen, or it runs on another host (the text after the mark names the host). Give it to the user to run in their own terminal. Do not run it.
2. **Approval.** Before a CHANGES block, show the command, the target, and the result. Stop. Run it only after the user types "yes" to that plan. "Just run it" is not "yes". If the user answers with another word (for example "proceed" or "ok"), ask them to type "yes".
3. **Env files.** Run blocks with bash. `~/nkp-site.env` holds the site values and the secrets. `~/nkp-<cluster>.env` holds the values of one cluster. Its first line is `source ~/nkp-site.env 2>/dev/null`. Line 2 of a block is `source ~/nkp-<cluster>.env 2>/dev/null` when the block uses a cluster-file variable. Otherwise line 2 is `source ~/nkp-site.env 2>/dev/null`. Before you run a block, replace `<cluster>` in `~/nkp-<cluster>.env` with the cluster name. If the user has not named the cluster, keep `~/nkp-<cluster>.env` in the block and ask for the name. Do not take a name from an example or another conversation. After the cluster env file exists, use its real name (for example `~/nkp-dev-01.env`) in every block that you show. Commands use the variables as `"$VAR"`.
4. **Values.** When you know a value, append one line to its file: `echo "export VAR='value'" >> ~/nkp-site.env` (CHANGES). Write a line only after the user gives or confirms the value. Ask first, and write the line in a later reply, after the answer. If the user has not given the value, do not show the append block. Do not put an example or a guessed value in it. Never write an empty value or a placeholder such as `<ip>`. A shell value inside a block (for example `obj=''`) stays empty, with its `:?` guard, until the user gives it. Never put `<...>` text in it. To change a value, append a new line. The last line wins. Some skill files add a `| File | Site variables |` table with more variables. For a value with no variable in these tables, make an UPPER_SNAKE name and ask the user. If `~/nkp-site.env` does not exist, make it: `touch ~/nkp-site.env && chmod 600 ~/nkp-site.env` (CHANGES).
5. **Secrets.** The user types the secret lines into `~/nkp-site.env` with an editor. Do not repeat or use a secret from the chat, and do not write it into an example line. Tell the user to put it in the file and to change it. Check a secret only with `printenv VAR >/dev/null` or `[ -n "$(printenv VAR)" ]`. Never print an env file, `env`, `set`, a kubeconfig, or Secret data.
6. **Unknowns.** Use only the UNKNOWN lines in the skills: `UNKNOWN (<id>): <what>. Find out with: <command>`. Run the check or ask the user. For a fact that is not in the skills, say "not in the skills" and give a READ-ONLY check. Never make up an ID or a fact.
7. **Offline.** Use only these skills, the bundle, `--help`, and the cluster. Read versions from the cluster or from `nkp version`.
8. **Tags.** `[live 2.19.0]` live cluster · `[pdf p.N]` NKP 2.19 guide · `[portal]` Nutanix portal · `[field]` not confirmed. Trust them in this order.

| File | Site variables |
|---|---|
| `~/nkp-site.env` | `MGMT_KUBECONFIG` `BUNDLE_DIR` `IMAGE_BUNDLES` `REGISTRY_URL` `REGISTRY_CA_FILE` `PC_ENDPOINT` `PC_CA_FILE` `PC_PROJECT` `PE_CLUSTER` `SUBNET` `STORAGE_CONTAINER` `VM_IMAGE` `SSH_PUBKEY_FILE` `NTP_SERVERS` `NKP_HTTP_PROXY` `NKP_HTTPS_PROXY` |
| `~/nkp-site.env` secrets | `NUTANIX_USER` `NUTANIX_PASSWORD` `REGISTRY_MIRROR_USERNAME` `REGISTRY_MIRROR_PASSWORD` `NUTANIX_REGISTRY_USERNAME` `NUTANIX_REGISTRY_TOKEN` |
| `~/nkp-<cluster>.env` | `CLUSTER_NAME` `CP_VIP` `LB_IP_RANGE` `WORKSPACE_NS` `CLUSTER_KUBECONFIG` `NO_PROXY_LIST` |
<!-- RULES:END -->

This skill owns metrics, alerts, dashboards, logs, and NKP Insights. You change these apps with values: the override steps are in skill `nkp-platform-apps-gitops` (file `overrides.md`, O3 for a workspace, O4 for one cluster). This skill gives the values and the checks. Read override values only with the `awk` mask of `overrides.md` O2.

## The parts [live 2.19.0]

| App ID (catalog version) | What it does | Tier | Default |
|---|---|---|---|
| `kube-prometheus-stack` (87.16.0) | Prometheus Operator, Prometheus v3.11.0, Alertmanager v0.31.1, Grafana 12.4.1, node-exporter, kube-state-metrics, the NKP alert rules and dashboards | Pro, Ultimate | on: management cluster and each attached cluster |
| `prometheus-adapter` (5.3.0) | Prometheus metrics in the custom metrics API (HPA) | Pro, Ultimate | on, with `kube-prometheus-stack` |
| `thanos` (17.3.2), `centralized-grafana` (87.16.0) | Thanos Query and a central Grafana on the management cluster. They read the Prometheus of every cluster. | Ultimate | on: management cluster |
| `karma` (2.0.10) | One page with the alerts of all Alertmanagers | Ultimate | on: management cluster |
| `logging-operator` (6.7.0) | Fluent Bit DaemonSet (pod logs) → Fluentd → outputs | Pro, Ultimate | management cluster only |
| `grafana-loki-v3` (3.6.7), `grafana-logging` (11.3.3) | Loki log store (on Rook Ceph by default) and its Grafana | Pro, Ultimate | management cluster only |
| `fluent-bit` (0.57.9) | Admin logs: Kubernetes audit, systemd journal, kernel. About 2 GB a day for each node in Loki. [pdf p.555, p.570] | Pro, Ultimate | off |
| `project-logging`, `project-grafana-loki-v3`, `project-grafana-logging` | Logs of one project, for the users of that project | Ultimate | off |
| NKP Insights: management part and engine (1.9.7) | Anomaly alerts, CVE scan (Trivy), CIS scan (kube-bench) | Ultimate | management part on; engine off |

- Starter has none of these apps, and no Prometheus Operator or Logging Operator API (CRDs). [live 2.19.0] On Starter, say so and stop. The tiers: skill `nkp`.
- The versions above are the catalog versions of the 2.19.0 cluster. Many guide examples use older versions (for example `logging-operator-6.4.0`, `fluent-bit-0.57.2`, `kube-prometheus-stack-82.13.6`). With such a name, `nkp create appdeployment` fails with `clusterapps ... not found`. [live 2.19.0] Always read the names in step 3.
- Logging is off on workload clusters by default. You enable it for each workspace. [pdf p.547]
- Rook Ceph (the default Loki bucket), COSI, and Velero: skill `nkp-storage-backup`. GPU dashboards and DCGM: skill `nkp-gpu-ai`. NDK alert rules: skill `nkp-ndk` (they need an event exporter that NKP 2.19 does not ship: D-54).

## Job → section

| Job | Where |
|---|---|
| Is monitoring or logging there, and healthy? | step 1 |
| Open Grafana, Alertmanager, Thanos, Karma, or the logging Grafana | step 2 |
| Enable monitoring, logging, Thanos, Karma, or Insights on a workspace or cluster | step 3 |
| Turn alert rules on or off, add an alert rule (`additionalPrometheusRulesMap`, `PrometheusRule`) | [references/monitoring.md](references/monitoring.md), M1-M2 |
| Scrape an app (`ServiceMonitor`) | [references/monitoring.md](references/monitoring.md), M3 |
| Send alerts to Slack, email, or another receiver (Alertmanager) | [references/monitoring.md](references/monitoring.md), M4 |
| Add or turn off Grafana dashboards | [references/monitoring.md](references/monitoring.md), M5 |
| Prometheus storage and resources; Prometheus PVC full | [references/monitoring.md](references/monitoring.md), M6 |
| Thanos stores, monitoring ID of a cluster, Karma limits | [references/monitoring.md](references/monitoring.md), M7 |
| Logging stack health, LoggingStack conditions, Loki v2 → v3 failure | [references/logging.md](references/logging.md), L1 and L9 |
| Collect logs only from some namespaces | [references/logging.md](references/logging.md), L2 |
| Loki retention; Loki on S3, Nutanix Objects, or Rook Ceph; TSDB index | [references/logging.md](references/logging.md), L3-L5 |
| Logging is slow, Fluentd buffer grows, scale Loki | [references/logging.md](references/logging.md), L6 |
| Audit, journal, and kernel logs (Fluent Bit app) | [references/logging.md](references/logging.md), L7 |
| Forward logs to syslog, Splunk, or Elasticsearch (`ClusterOutput`) | [references/logging.md](references/logging.md), L8 |
| Project (multi-tenant) logging | [references/logging.md](references/logging.md), L10 |
| NKP Insights: enable, storage, alerts to Slack, uninstall | [references/insights.md](references/insights.md) |
| Trivy CVE scan on, scan schedule, new Trivy DB image (air-gapped) | [references/insights.md](references/insights.md), I3 |
| Loki or Insights bucket full on Rook Ceph | skill `nkp-storage-backup` (file `object-storage.md`, O2) |

## Step 1: Read the state

Ask the user for the cluster. For the management cluster, `WORKSPACE_NS` is `kommander`.

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n kommander get licenses.kommander.mesosphere.io -o jsonpath='{.items[*].status.dkpLevel}{"\n"}'
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get appdeployments | grep -E 'NAME|prometheus|grafana|loki|logging|fluent|thanos|karma|insights|rook-ceph'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get helmreleases -A | grep -E 'NAME|prometheus|grafana|loki|logging|fluent|thanos|karma|insights|rook-ceph|object-bucket'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get prometheuses,alertmanagers -A
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get pods -A | grep -E 'prometheus|alertmanager|grafana|loki|fluent|thanos|karma|insights' | grep -v -E 'Running|Completed'
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get loggingstacks
```

- License `Starter`: no apps of this skill. `prometheuses` gives "the server doesn't have a resource type". [live 2.19.0] Stop.
- The HelmReleases are on the target cluster: in `kommander` on the management cluster, in the workspace namespace on a workload cluster. [pdf p.561-562]
- A healthy logging stack has these HelmReleases `True`: `logging-operator`, `logging-operator-logging`, `grafana-loki-v3`, `grafana-logging`, `rook-ceph`, `rook-ceph-cluster`, `object-bucket-claims`. [pdf p.562]
- The pods line prints only pods that are not `Running` or `Completed`. An empty result is healthy.
- A HelmRelease that is not `True`: skill `nkp-troubleshooting` (file `flux.md`). The LoggingStack conditions: [references/logging.md](references/logging.md), L1.

Done when: you know the tier, which apps of this skill run, and the first part that is not healthy.

## Step 2: Open the UIs

The UIs use the NKP login (SSO). The user gets the URL and the admin login with `nkp get dashboard` (USER-TERMINAL, skill `nkp-install`). Read the ingress address of each cluster:

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" get kommanderclusters -A -o custom-columns='NAMESPACE:.metadata.namespace,NAME:.metadata.name,ADDRESS:.status.ingress.address'
```

| UI | Path on the address of the cluster |
|---|---|
| Grafana of the cluster (metrics) | `https://<address>/dkp/grafana` [pdf p.633] |
| Alertmanager of the cluster (silence, mute) | `https://<address>/dkp/alertmanager` [pdf p.637] |
| Central Grafana (management cluster, Ultimate) | `https://<address>/dkp/kommander/monitoring/grafana` [pdf p.641] |
| Thanos Query, and its list of stores | `https://<address>/dkp/kommander/monitoring/query/`, `.../query/stores` [pdf p.641] |
| Karma (management cluster, Ultimate) | `https://<address>/dkp/kommander/monitoring/karma` [pdf p.641] |

The logging Grafana has its own ingress on the target cluster. Its path ends in `/explore`; choose the data source Loki. [pdf p.563]

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$WORKSPACE_NS" get ingress grafana-logging -o go-template='https://{{with index .status.loadBalancer.ingress 0}}{{or .hostname .ip}}{{end}}{{with index .spec.rules 0}}{{with index .http.paths 0}}{{.path}}{{end}}{{end}}/explore{{"\n"}}'
```

Done when: you gave the user the URL. The UI does not load: Traefik and cert-manager must run on that cluster [pdf p.563] (skill `nkp-networking`).

## Step 3: Enable the apps

Use skill `nkp-platform-apps-gitops`, step 2 (dry run, plan, "yes", create). This step gives the app names and the order. First read the exact ClusterApp names:

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" get clusterapps | grep -E 'NAME|prometheus|grafana|loki|logging|fluent|thanos|karma|insights|rook-ceph|cloudnative-pg'
```

| Goal | App IDs, in this order | Before you start |
|---|---|---|
| Metrics and alerts | `kube-prometheus-stack`, then `prometheus-adapter` | A default StorageClass on the target cluster (Prometheus PVC). |
| Workspace logging | `rook-ceph`, `rook-ceph-cluster`, `logging-operator`, `grafana-loki-v3`, `grafana-logging` [pdf p.558-559] | Traefik and cert-manager on the target; a default StorageClass. [pdf p.557] Rook Ceph size and nodes: skill `nkp-storage-backup`. |
| Admin logs (audit, journal, kernel) | `fluent-bit` | Workspace logging, and more Ceph space first: [references/logging.md](references/logging.md), L7. |
| Project logging | [references/logging.md](references/logging.md), L10 | Workspace logging. |
| NKP Insights | [references/insights.md](references/insights.md), I1 | Ultimate. |

- `thanos`, `karma`, and `centralized-grafana` are management cluster apps of Ultimate. NKP installs them. Do not create them by hand.
- The API accepts an AppDeployment of a Pro app on a Starter cluster. [live 2.19.0] Check the tier first (step 1).
- Done when: step 1 shows the HelmReleases of the new apps `True` on each target cluster.

## Common failures

| Symptom | Cause and fix |
|---|---|
| `the server doesn't have a resource type "prometheusrules"` (or `servicemonitors`, `clusteroutputs`) | Starter, or the app is not enabled on this cluster. Step 1. [live 2.19.0] |
| `clusterapps.apps.kommander.d2iq.io "<app>-<version>" not found` | A version from the guide. Use the name from step 3. [live 2.19.0] |
| An app `ServiceMonitor` is not scraped | [references/monitoring.md](references/monitoring.md), M3 |
| Alerts fire in Alertmanager, but no message comes | [references/monitoring.md](references/monitoring.md), M4 |
| Karma: `Get https://placeholder.invalid/api/v2/status ... no such host` | Normal when no cluster is attached. It goes away after an attach. [pdf p.641] |
| Silence from the Karma UI does not work | Not supported. Silence in the Alertmanager UI of that cluster (step 2). [pdf p.641] |
| The central view has no metrics of a cluster, also no old metrics | That cluster is down. Thanos reads each Prometheus remotely; NKP does not keep a copy. [pdf p.641] Use M7 to check the stores. |
| Prometheus PVC full, Prometheus restarts | [references/monitoring.md](references/monitoring.md), M6 |
| Loki stops taking logs; bucket full | Rook Ceph bucket cap: skill `nkp-storage-backup` (file `object-storage.md`, O2). Loki side: [references/logging.md](references/logging.md), L3-L4. |
| LoggingStack `GrafanaLokiV3Deployed=False`, reason `Failed`, after an upgrade | [references/logging.md](references/logging.md), L9. Reason `GrafanaLokiV2NotDeployed` was seen when no Loki v2 was ever installed. [live 2.19.0] |
| Logs come late; Fluentd buffer grows | [references/logging.md](references/logging.md), L6 |
| Loki or Prometheus pods `Pending` with a PVC | skill `nkp-storage-backup`, step 2 |
| Grafana or Loki images do not pull (air-gapped) | skill `nkp-airgap` |
| Trivy finds no new CVEs on an air-gapped site | The bundle DB is old. [references/insights.md](references/insights.md), I3. |
| A HelmRelease of these apps is not Ready, `exhausted`, or a values error | skill `nkp-troubleshooting` (file `flux.md`), then skill `nkp-platform-apps-gitops` (`overrides.md`, O5) |

## Related skills

App enable, disable, and the override steps: skill `nkp-platform-apps-gitops`. Rook Ceph, COSI, Velero: skill `nkp-storage-backup`. Images and bundles in an air gap, the Trivy DB bundle: skill `nkp-airgap` (file `prestage.md`, P4). The debug ladder: skill `nkp-troubleshooting`. Workspaces, projects, and roles for Grafana users: skill `nkp-identity-security`.
