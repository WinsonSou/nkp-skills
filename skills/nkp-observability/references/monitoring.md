# Monitoring: alert rules, scrape targets, Alertmanager, Grafana, Thanos

Use this file from skill `nkp-observability`. All parts are in the platform app `kube-prometheus-stack` (Pro and Ultimate). On Starter, stop. [live 2.19.0]

| File | Site variables |
|---|---|
| `~/nkp-site.env` secrets | `ALERT_SLACK_WEBHOOK_URL` |

`ALERT_SLACK_WEBHOOK_URL` is the Slack incoming webhook URL. It is a secret: the user types it into `~/nkp-site.env` with an editor (rule 5).

## Facts

- **One override for the app.** Alert rules, dashboards, storage, and resources are values of `kube-prometheus-stack`. Put all of them in one values file and apply it with skill `nkp-platform-apps-gitops` (file `overrides.md`, O3 for a workspace, O4 for one cluster), `APP_ID=kube-prometheus-stack`. If the app already has an override (O2), keep its values in the file. [pdf p.272-273, p.635-636]
- The guide names the ConfigMap `kube-prometheus-stack-overrides`. This HelmRelease does not read that name directly (O2 shows `valuesFrom`). Use the name rule of `overrides.md` O3 item 3.
- **NKP override on the management cluster.** The ConfigMap `kommander/kube-prometheus-stack-mgmt-overrides` holds `prometheus.additionalServiceMonitors`: a list of 15 NKP ServiceMonitors (CSI, Dex, Thanos, Kommander, Karma, Loki, etcd, and others). Its own comment says: "arrays in values are replaced, not appended". [live 2.19.0] So an override that sets `prometheus.additionalServiceMonitors` must hold all of these entries too, or NKP stops scraping them. Use M3 (labels) for your apps.
- The HelmRelease reads the defaults, then `kube-prometheus-stack-mgmt-overrides` by name (`optional: true`). A new `configOverrides` adds its ConfigMap after it, so a user `prometheus.additionalServiceMonitors` replaces the NKP list. [live 2.19.0, app tree `kube-prometheus-stack` 87.16.0] Check on the cluster: `source ~/nkp-site.env 2>/dev/null && kubectl --kubeconfig "$MGMT_KUBECONFIG" get helmreleases -A -o custom-columns='NS:.metadata.namespace,NAME:.metadata.name,FROM:.spec.valuesFrom[*].name' | grep kube-prometheus-stack` (READ-ONLY). D-30 stays open until a Pro or Ultimate management cluster confirms it.
- The API groups of the Prometheus Operator are not in this text. The blocks read the group from the cluster with `kubectl explain`.

## M0. Read the Prometheus and Alertmanager settings

Run this first for M1-M4. It shows the namespace of the stack and the labels that Prometheus and Alertmanager select.

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get helmreleases -A | grep -E 'NAMESPACE|kube-prometheus-stack'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get prometheuses -A -o jsonpath='{range .items[*]}{.metadata.namespace}/{.metadata.name}{"\n"}  serviceMonitorSelector={.spec.serviceMonitorSelector}{"\n"}  serviceMonitorNamespaceSelector={.spec.serviceMonitorNamespaceSelector}{"\n"}  ruleSelector={.spec.ruleSelector}{"\n"}  ruleNamespaceSelector={.spec.ruleNamespaceSelector}{"\n"}  retention={.spec.retention}{"\n"}{end}'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get alertmanagers -A -o jsonpath='{range .items[*]}{.metadata.namespace}/{.metadata.name}{"\n"}  configSelector={.spec.alertmanagerConfigSelector}{"\n"}  configNamespaceSelector={.spec.alertmanagerConfigNamespaceSelector}{"\n"}  matcherStrategy={.spec.alertmanagerConfigMatcherStrategy}{"\n"}{end}'
```

- The namespace of the HelmRelease is the stack namespace: `kommander` on the management cluster, usually the workspace namespace on a workload cluster. [pdf p.639]
- An empty namespace selector means: only the namespace of the Prometheus object. `{}` means all namespaces. (Prometheus Operator behaviour.)

Done when: you know the stack namespace and the selector labels.

## M1. Turn NKP alert rules on or off

Values for the M-override [pdf p.635-636]:

```yaml
defaultRules:
  rules:
    node: false          # turn off one rule group (here: the node rules)
```

```yaml
defaultRules:
  create: false          # turn off all default rules
```

```yaml
mesosphereResources:
  rules:
    velero: true         # Velero rules are off by default; turn on only when the velero app runs
```

- Some default alerts: `CPUThrottlingHigh`, `TargetDown`, `KubeletNotReady`, `KubeAPIDown`, `CoreDNSDown`, `KubeVersionMismatch`. [pdf p.635]
- When you disable a platform app, turn off its rules too. Else the rules fire by mistake. [pdf p.636]
- The rule group names (`node`, and others) are keys under `defaultRules.rules` in the defaults ConfigMap (M6 item 1 shows how to read it).
- To mute one firing alert for some time, use a silence in the Alertmanager UI (skill `nkp-observability` step 2). [pdf p.637]

Done when: `overrides.md` O6 passes, and the Prometheus UI (Grafana Explore, or Thanos Query) no longer shows the rule group.

## M2. Add an alert rule

**Way A (the guide).** Add the rule to the M-override under `additionalPrometheusRulesMap`. [pdf p.636-637] Ask the user for the name, the PromQL expression, the time, and the severity. Example with the values that the user gives:

```yaml
additionalPrometheusRulesMap:
  my-rule-name:
    groups:
      - name: my_group
        rules:
          - alert: MyAppDown
            expr: up{job="my-app"} == 0
            for: 5m
            labels:
              severity: warning
            annotations:
              summary: my-app has no scrape target up
```

**Way B (a rule object in an app namespace).** Use it when an app team owns the rule. The `PrometheusRule` must have the labels of `ruleSelector`, in a namespace that `ruleNamespaceSelector` selects (M0). A field example uses the label `release: kube-prometheus-stack`. [field] Use the labels from M0, not the example.

1. Ask the user for the rule text. Write the file (CHANGES, operator host only). Put the labels from M0 under `labels`, and the confirmed rules in place of the comment line:

```bash
# CHANGES  (writes the PrometheusRule file on the operator host; changes no cluster)
source ~/nkp-<cluster>.env 2>/dev/null
ns=''; name=''; : "${ns:?}" "${name:?}"
grp=$(kubectl --kubeconfig "$CLUSTER_KUBECONFIG" explain prometheusrules | sed -n 's/^GROUP: *//p'); : "${grp:?}"
cat > "$HOME/$CLUSTER_NAME-rule-$name.yaml" <<EOF
apiVersion: $grp/v1
kind: PrometheusRule
metadata:
  name: $name
  namespace: $ns
  labels:
    # the labels from M0 ruleSelector go here
spec:
  groups:
    # the rule groups that the user confirmed go here
EOF
```

2. Preview, then show the plan and apply after "yes":

```bash
# READ-ONLY  (server dry run: changes nothing)
source ~/nkp-<cluster>.env 2>/dev/null
name=''; : "${name:?}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" apply --dry-run=server -f "$HOME/$CLUSTER_NAME-rule-$name.yaml"
```

```bash
# CHANGES  (creates or updates one PrometheusRule)
source ~/nkp-<cluster>.env 2>/dev/null
name=''; : "${name:?}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" apply -f "$HOME/$CLUSTER_NAME-rule-$name.yaml"
```

Done when: the Prometheus UI (Alerts page) lists the new alert. The rule loads in about one minute. A rule with a PromQL error is not loaded: read the log of the `prometheus` container in the Prometheus pod (stack namespace).

## M3. Scrape an app (ServiceMonitor)

The app needs an HTTP endpoint `/metrics` in the Prometheus format, and a Service with a named port. [pdf p.644-645] The guide adds the label `prometheus.kommander.d2iq.io/select: "true"` to the ServiceMonitor. [pdf p.645] Check it against `serviceMonitorSelector` in M0.

1. Ask the user for the namespace, the Service label (`app: my-app`), and the port name. Write the file (CHANGES):

```bash
# CHANGES  (writes the ServiceMonitor file on the operator host; changes no cluster)
source ~/nkp-<cluster>.env 2>/dev/null
ns=''; name=''; app=''; port=''; : "${ns:?}" "${name:?}" "${app:?}" "${port:?}"
grp=$(kubectl --kubeconfig "$CLUSTER_KUBECONFIG" explain servicemonitors | sed -n 's/^GROUP: *//p'); : "${grp:?}"
cat > "$HOME/$CLUSTER_NAME-sm-$name.yaml" <<EOF
apiVersion: $grp/v1
kind: ServiceMonitor
metadata:
  name: $name
  namespace: $ns
  labels:
    prometheus.kommander.d2iq.io/select: "true"
spec:
  selector:
    matchLabels:
      app: $app
  endpoints:
    - port: $port
      interval: 30s
EOF
```

2. Preview and apply as in M2 item 2, with the file `$HOME/$CLUSTER_NAME-sm-$name.yaml`.

- The guide also shows `prometheus.additionalServiceMonitors` in the override. [pdf p.645] On the management cluster that list replaces the NKP list (Facts, D-30). Use the label way.
- Not scraped after 2 minutes: the namespace is not in `serviceMonitorNamespaceSelector` (M0), the Service has no port with that name, or the Service selector does not match the pods (`kubectl get endpoints` in that namespace).

Done when: the Prometheus UI page Targets shows the app `UP`.

## M4. Send alerts to Slack, email, or another receiver

Two ways. Ask the user which one.

| Way | Use it for | Source |
|---|---|---|
| A. Replace the Alertmanager config Secret | all alerts of the cluster, one route tree | [pdf p.637-639] |
| B. `AlertmanagerConfig` object + a Secret | an added route (for example only Insights alerts) | [pdf p.1104-1107] |

**Way A.** The guide replaces the Secret `alertmanager-kube-prometheus-stack-alertmanager` in the stack namespace with a new `alertmanager.yaml` (and an optional `notification.tmpl`). [pdf p.638-639] The file holds the webhook URL or the SMTP password, so the user writes it.

**Helm owns this Secret.** The chart renders it from `alertmanager.config`, and the NKP defaults set that config (route to `"null"`). [live 2.19.0, chart 87.16.0 `templates/alertmanager/secret.yaml`, app tree] Each change of the app values (M1, M2, M5, M6, any other `kube-prometheus-stack` override) and each platform upgrade puts the NKP default back, and the receivers stop with no error. Tell the user this before way A. After each such change, do way A again, or use way B.


1. Give the user this block. Tell the user what the file must have: `route` (with a default `receiver`), `receivers` (for example `slack_configs` or `email_configs`), and a route that sends `Watchdog` and `InfoInhibitor` to a `"null"` receiver. [pdf p.637-639]

```bash
# USER-TERMINAL  (operator host; the user writes the Alertmanager config, it holds a secret)
umask 077
vi ~/alertmanager.yaml
```

2. Show the plan (cluster, namespace, the Secret is replaced, all notifications change). After "yes":

```bash
# CHANGES  (replaces the Alertmanager config Secret of the cluster)
source ~/nkp-<cluster>.env 2>/dev/null
ns=''; : "${ns:?}"
f=$(test -s "$HOME/alertmanager.yaml" && echo ok); : "${f:?no ~/alertmanager.yaml}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" create secret generic alertmanager-kube-prometheus-stack-alertmanager --from-file=alertmanager.yaml="$HOME/alertmanager.yaml" --dry-run=client --save-config -o yaml | kubectl --kubeconfig "$CLUSTER_KUBECONFIG" apply -f - -o name
```

With a template file, add `--from-file=notification.tmpl="$HOME/notification.tmpl"`, and set `templates: ['*.tmpl']` in the config. [pdf p.637-638]

3. Check that Alertmanager loaded it (the log has no secret):

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
ns=''; : "${ns:?}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" logs alertmanager-kube-prometheus-stack-alertmanager-0 -c alertmanager --since=10m | grep -iE 'config|error' | tail -5
```

A load error shows `error` with the line. The guide reads `/etc/alertmanager/config_out/alertmanager.env.yaml` in the pod. [pdf p.639] That file has the secrets: only the user reads it (USER-TERMINAL).

- UNKNOWN (D-31): whether `alertmanager.alertmanagerSpec.useExistingSecret: true` in the `kube-prometheus-stack` override keeps a user Secret on NKP 2.19 (then way A survives value changes). Find out with: `source ~/nkp-<cluster>.env 2>/dev/null && kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get secrets -A --show-labels | grep alertmanager-kube-prometheus-stack-alertmanager` after a values change (the label `app.kubernetes.io/managed-by=Helm` means that Helm still owns it). Do not set it without a lab test.

**Way B.** The Slack example of the guide [pdf p.1106-1107]:

1. The user puts `ALERT_SLACK_WEBHOOK_URL` in `~/nkp-site.env` (rule 5). Check: `printenv ALERT_SLACK_WEBHOOK_URL >/dev/null` after `source`.
2. Make the Secret and the `AlertmanagerConfig` in the stack namespace. The guide uses `kommander`. Ask the user for the channel and the matchers. Write the file (CHANGES), with the confirmed routes in place of the comment line:

```bash
# CHANGES  (writes the AlertmanagerConfig file on the operator host; changes no cluster)
source ~/nkp-<cluster>.env 2>/dev/null
ns=''; channel=''; : "${ns:?}" "${channel:?}"
grp=$(kubectl --kubeconfig "$CLUSTER_KUBECONFIG" explain alertmanagerconfigs | sed -n 's/^GROUP: *//p'); : "${grp:?}"
cat > "$HOME/$CLUSTER_NAME-amconfig-slack.yaml" <<EOF
apiVersion: $grp/v1alpha1
kind: AlertmanagerConfig
metadata:
  name: slack-config
  namespace: $ns
spec:
  route:
    groupBy: ['alertname']
    groupWait: 3m
    groupInterval: 15m
    repeatInterval: 1h
    receiver: slack
    # the routes and matchers that the user confirmed go here
  receivers:
    - name: slack
      slackConfigs:
        - apiURL:
            name: slack-webhook
            key: slack-webhook-url
          channel: '$channel'
          sendResolved: true
EOF
```

3. Preview with `kubectl apply --dry-run=server -f` (READ-ONLY, as M2). Show the plan. After "yes":

```bash
# CHANGES  (creates the webhook Secret and the AlertmanagerConfig)
source ~/nkp-<cluster>.env 2>/dev/null
ns=''; : "${ns:?}"
s=$(printenv ALERT_SLACK_WEBHOOK_URL >/dev/null && echo ok); : "${s:?ALERT_SLACK_WEBHOOK_URL is not set}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" create secret generic slack-webhook --from-file=slack-webhook-url=<(printf %s "$(printenv ALERT_SLACK_WEBHOOK_URL)") --dry-run=client -o yaml | kubectl --kubeconfig "$CLUSTER_KUBECONFIG" apply -f - -o name
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" apply -f "$HOME/$CLUSTER_NAME-amconfig-slack.yaml"
```

- The `AlertmanagerConfig` must match `configSelector` and `configNamespaceSelector` (M0). An empty selector selects nothing: then use Way A.
- `matcherStrategy` empty or `OnNamespace`: the Prometheus Operator adds `namespace=<namespace of the object>` to the route. Then only alerts with that `namespace` label match. [field] Way A has no such limit.
- Microsoft Teams needs an extra proxy chart and image from the internet. [pdf p.1108] It is not in the skills for an air-gapped site.

Done when: a test alert (or `Watchdog`, if routed) reaches the receiver. Alertmanager needs network access to the receiver (Slack, the SMTP server); on an air-gapped site, use an internal receiver.

## M5. Grafana dashboards

| Grafana | Where the ConfigMap goes | Label | Source |
|---|---|---|---|
| Grafana of each cluster (`/dkp/grafana`) | that cluster | `grafana_dashboard: "1"` | [pdf p.633] |
| Central Grafana (management cluster) | management cluster | `grafana_dashboard_kommander: "1"` | [pdf p.640] |

- Default dashboards: Kubernetes components, USE method, etcd, Prometheus, and the dashboards of the platform apps (Logging Operator, Loki, Ceph). [pdf p.632, p.549, p.554] To turn off all default dashboards, put `grafana.defaultDashboardsEnabled: false` in the M-override. [pdf p.632]
- The guide gives no namespace for the dashboard ConfigMap. Read where the Grafana sidecar looks (`NAMESPACE` env: `ALL`, a list, or empty for its own namespace [field]):

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get deploy -A -l app.kubernetes.io/name=grafana -o jsonpath='{range .items[*]}{.metadata.namespace}/{.metadata.name}{"\n"}{range .spec.template.spec.containers[*]}  {.name}: {range .env[?(@.name=="LABEL")]}LABEL={.value} {end}{range .env[?(@.name=="NAMESPACE")]}NAMESPACE={.value}{end}{"\n"}{end}{end}'
```

Ask the user for the dashboard JSON file path. Show the plan. After "yes" (for the central Grafana, use `MGMT_KUBECONFIG` and the label `grafana_dashboard_kommander`):

```bash
# CHANGES  (creates a dashboard ConfigMap; the Grafana sidecar imports it)
source ~/nkp-<cluster>.env 2>/dev/null
ns=''; cm=''; json=''; : "${ns:?}" "${cm:?}" "${json:?}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" create configmap "$cm" --from-file="$json"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" label configmap "$cm" grafana_dashboard=1
```

Done when: the dashboard is in Grafana (Dashboards, search its title) after about one minute.

## M6. Prometheus storage, retention, and resources

1. Read the current values. The defaults ConfigMap is in the stack namespace (M0):

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
ns=''; : "${ns:?}"
cm=$(kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" get cm -o name | grep 'kube-prometheus-stack-.*-config-defaults'); : "${cm:?}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" get "$cm" -o jsonpath='{.data.values\.yaml}' | grep -n -E '^ *(retention|retentionSize|storage|cpu|memory):'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" get pvc | grep -E 'NAME|prometheus'
```

2. Values for the M-override. The guide example for more storage [pdf p.273]:

```yaml
prometheus:
  prometheusSpec:
    storageSpec:
      volumeClaimTemplate:
        spec:
          resources:
            requests:
              storage: 150Gi
```

Size guide for Prometheus (tested by Nutanix) [pdf p.631]:

| Clusters | Pods | Requests (CPU, memory) | Limits (CPU, memory) | Storage |
|---|---|---|---|---|
| 10 | 1k | 100m, 500Mi | 500m, 2192Mi | 35Gi |
| 25 | 1k | 1, 3Gi | 2, 6Gi | 60Gi |
| 50 | 1.5k | 2, 8Gi | 7, 28Gi | 100Gi |
| 100 | 3k | 10, 48Gi | 12, 50Gi | 100Gi |
| 200 | 10k | 15, 50Gi | 20, 80Gi | 100Gi |
| 300 | 15k | 25, 120Gi | 35, 150Gi | 100Gi |

The resources go under `prometheus.prometheusSpec.resources`. The table shows the settings, not the exact value structure. [pdf p.630]

3. An existing PVC does not grow from the template alone. [field] Grow the PVC `db-prometheus-kube-prometheus-stack-prometheus-0` [pdf p.546] in the stack namespace with skill `nkp-storage-backup` (file `csi.md`, C4), to the same size as the override.

- Retention: the guide gives no value. The values key is `prometheus.prometheusSpec.retention` (upstream chart). [field] Read the current value in item 1.
- Velero backup and restore of the Prometheus volume: skill `nkp-storage-backup`.

Done when: `kubectl get pvc` shows the new capacity, and the Prometheus pod is `Running`.

## M7. Multi-cluster view: Thanos, central Grafana, Karma (Ultimate)

- Thanos Query on the management cluster reads each Prometheus through a Thanos sidecar. The central Grafana uses Thanos Query as its data source. [pdf p.640-641] For the details of one cluster, use the Grafana of that cluster. [pdf p.641]
- Each attached cluster runs `prometheus-thanos-traefik` and `karma-traefik` (with certificates from `kommander-cert-federation`). They expose Prometheus and Alertmanager to the management cluster. [live 2.19.0]
- The **monitoring ID** of a cluster is the UID of its `kube-system` namespace. Metrics and alerts carry it. [pdf p.639-640]

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get namespace kube-system -o jsonpath='{.metadata.uid}{"\n"}'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get helmreleases -A | grep -E 'NAME|thanos|karma|traefik-certs'
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n kommander get pods | grep -E 'thanos|karma|centralized-grafana'
```

- A cluster is missing in the central view: open `.../monitoring/query/stores` (skill `nkp-observability` step 2). The cluster must be in the list. If not, check on that cluster that the `prometheus-thanos-traefik` and `prometheus-traefik-certs` HelmReleases are `True`, and that the KommanderCluster is `Joined` (skill `nkp-platform-apps-gitops`, step 4).
- Karma shows alerts only. Silence alerts in the Alertmanager of the cluster. [pdf p.641]

Done when: the store list has one entry for each attached cluster, or you found the HelmRelease that is not `True`.
