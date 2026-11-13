# Logging: Logging Operator, Loki, Fluent Bit, log forwarding

Use this file from skill `nkp-observability`. The logging apps are Pro and Ultimate. On Starter, stop. [live 2.19.0]

| File | Site variables |
|---|---|
| `~/nkp-<cluster>.env` | `LOKI_S3_URL` |
| `~/nkp-site.env` secrets | `LOKI_S3_ACCESS_KEY` `LOKI_S3_SECRET_KEY` `LOG_SPLUNK_HEC_TOKEN` `LOG_ES_PASSWORD` |

- `LOKI_S3_URL`: the bucket URL for Loki of this cluster, `http(s)://<host>:<port>/<bucket>`. Each cluster needs its own bucket. Ask the user. Append it with rule 4 only after the answer.
- The secret lines: the user types them into `~/nkp-site.env` with an editor (rule 5).

## Facts

- Write path: Fluent Bit (DaemonSet, pod logs) → Fluentd (StatefulSet) → Loki gateway → distributor → ingester → object store. Read path: Grafana → Loki gateway → query frontend → querier. [pdf p.556-557]
- The Logging Operator makes Fluent Bit and Fluentd from a `Logging` object. The HelmRelease `logging-operator-logging` (chart `logging-operator-logging` 4.2.2) holds the NKP `Logging`, the `ClusterFlow` `cluster-containers`, and the `ClusterOutput` `loki`. [pdf p.560, p.275][live 2.19.0]
- Loki runs in microservice mode. Default store: a Rook Ceph bucket (HelmRelease `object-bucket-claims`). Default index: `boltdb-shipper`. Default retention: one week (compactor), minimum 24 hours. [pdf p.551, p.560]
- The guide calls the Loki override ConfigMaps `grafana-loki-v3-overrides` and `grafana-loki-v3-custom-overrides`. [pdf p.550, p.561] Loki takes **one** workspace override: put retention, storage, and scale values in one values file. Apply it with skill `nkp-platform-apps-gitops` (file `overrides.md`, O3 or O4), `APP_ID=grafana-loki-v3`. Use the name rule of O3 item 3.
- Lists in values replace the default list (for example `clusterFlows`, `clusterOutputs`, `schemaConfig.configs`). Copy the full default list and change it. [pdf p.276][live 2.19.0]

## L1. Health of the logging stack

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get helmreleases -A | grep -E 'NAME|logging|loki|fluent|rook-ceph|object-bucket'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get loggings -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}controlNamespace={.spec.controlNamespace}{"\n"}{end}'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get clusterflows,clusteroutputs -A
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get pods -A | grep -E 'NAME|fluentbit|fluentd|loki|logging-operator'
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get loggingstacks -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{range .status.conditions[*]}  {.type}={.status} {.reason}: {.message}{"\n"}{end}{end}'
```

- `controlNamespace`: the namespace of Fluentd and of the `ClusterOutput` objects (L8). Write it down.
- `clusteroutputs` shows ACTIVE and PROBLEMS columns. A problem count above 0: `kubectl describe clusteroutput` in the control namespace.
- **LoggingStack** (`loggingstack.nkp.nutanix.com`): one for each cluster, on the management cluster, owned by the KommanderCluster. For the management cluster it is in `kommander`. [live 2.19.0] For a workload cluster, look in its `WORKSPACE_NS` (the namespace of its KommanderCluster). [field] NKP uses it to deploy the logging apps and to move Loki v2 to v3. [live 2.19.0][pdf p.552] Seen on 2.19.0 when no Loki v2 was ever installed (a cluster with no logging apps) [live 2.19.0]:

```text
LoggingStackVersionReconciled=True ReconciliationSucceeded
GrafanaLokiV3Deployed=False GrafanaLokiV2NotDeployed      (normal: no Loki v2 was there)
LoggingStackAppDeploymentsUpdated=True Succeeded
GrafanaLokiV2Removed=False GrafanaLokiV2NotDeployed        (normal)
```

`GrafanaLokiV3Deployed=False` with reason `Failed`: L9. The reason `GrafanaLokiV2NotDeployed` with Loki v3 running is not tested. [field]

- Fluentd buffer grows, logs come late: L6. No logs at all from one namespace: L2 (an exclude rule).
Done when: all logging HelmReleases are `True`, the pods run, and the LoggingStack shows no reason `Failed`.

## L2. Collect logs only from some namespaces (or not from some)

The guide changes the `cluster-containers` ClusterFlow with an exclude list. [pdf p.559-560] Values:

```yaml
clusterFlows:
  - name: cluster-containers
    spec:
      globalOutputRefs:
        - loki
      match:
        - exclude:
            namespaces:
              - noisy-namespace-1
              - noisy-namespace-2
```

Where the values go: the HelmRelease `logging-operator-logging` reads the defaults, then a ConfigMap named exactly `logging-operator-logging-overrides` (`optional: true`) in its own namespace. The `logging-operator` HelmRelease reads only its defaults. [live 2.19.0, app tree `logging-operator` 6.7.0] So make that ConfigMap directly on the **target** cluster, in the HelmRelease namespace, one for each cluster. [pdf p.274, p.574] Do not patch an AppDeployment. The guide way with `configOverrides` of the `logging-operator` AppDeployment (p.560) works only on the management cluster, because there the namespace is `kommander`. Check the FROM list first:

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get helmreleases -A -o custom-columns='NS:.metadata.namespace,NAME:.metadata.name,FROM:.spec.valuesFrom[*].name' | grep -E 'NS|logging-operator'
```

- Make the ConfigMap `logging-operator-logging-overrides` on the target cluster in the namespace of `logging-operator-logging`, with the same steps as gitops `overrides.md` O3 items 1-3, but with `CLUSTER_KUBECONFIG` and that namespace. This name is the exception to the O3 name rule: the HelmRelease reads only this name.
- The `clusterFlows` list replaces the default list. Keep `cluster-containers` with `globalOutputRefs: [loki]`, or Loki gets no pod logs. [field]

Done when: after some minutes, Grafana Explore (Loki) shows no new logs from the excluded namespaces, and logs from the other namespaces still come. [pdf p.560]

## L3. Loki retention

Values (in the one Loki values file) [pdf p.560-561]:

```yaml
loki:
  structuredConfig:
    limits_config:
      retention_period: 360h
```

- Default 168h (one week). Minimum 24h. [pdf p.560]
- More retention needs more bucket space. On Rook Ceph, raise the Loki bucket cap and the Ceph capacity: skill `nkp-storage-backup` (file `object-storage.md`, O2). Admin logs add about 2 GB a day for each node. [pdf p.570]

Done when: gitops `overrides.md` O6 passes.

## L4. Loki object storage: Rook Ceph, AWS S3, Nutanix Objects

| Store | How |
|---|---|
| Rook Ceph (default) | Nothing to do. Bucket cap and Ceph size: skill `nkp-storage-backup` (file `object-storage.md`, O2). Your own Ceph (BYOS): the same file, O4. |
| AWS S3 | Secret + values below; `s3: s3://<region>/<bucket>` [pdf p.549-551] |
| S3-compatible, Nutanix Objects | Secret + values below; `s3: http(s)://<host>:<port>/<bucket>` [pdf p.660-661][field] |

The bucket exists first: the S3 or Objects admin makes it, one for each cluster. Before the install of Kommander, the guide puts the values in the installer file (skill `nkp-install`). [pdf p.551, p.660]

1. The user puts `LOKI_S3_ACCESS_KEY` and `LOKI_S3_SECRET_KEY` in `~/nkp-site.env` (rule 5). Ask for `LOKI_S3_URL` (rule 4).
2. The defaults load the Secret `dkp-loki` in seven Loki components (`ingester`, `distributor`, `querier`, `queryFrontend`, `indexGateway`, `compactor`, `ruler`) and set the Reloader annotation to `dkp-loki`. `dkp-loki` is the Secret that Rook makes for the ObjectBucketClaim `dkp-loki` (the default Ceph bucket). [live 2.19.0, app tree `grafana-loki-v3` 3.6.7] **Never write to `dkp-loki`**: the bucket provisioner owns it, and the Ceph bucket can lose its credentials. The guide name `nkp-loki` (p.660-661) is from its own-Ceph example, not the default. Check the defaults on the target cluster:

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
ns=''; : "${ns:?}"
cm=$(kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" get cm -o name | grep 'grafana-loki-v3-.*-config-defaults'); : "${cm:?}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" get "$cm" -o jsonpath='{.data.values\.yaml}' | grep -n -E 'secretRef:|name: dkp-loki|reloader|s3:'
```

`ns` is the namespace of the `grafana-loki-v3` HelmRelease (L1): the defaults ConfigMap is next to it. [live 2.19.0]

3. Make a **new** Secret on the **target** cluster, in the namespace of the Loki HelmRelease (`kommander` on the management cluster). Ask the user for its name (for example `loki-s3-creds`; rule 4). Never use `dkp-loki`. Show the plan. After "yes":

```bash
# CHANGES  (creates or updates the new S3 credentials Secret for Loki; never dkp-loki)
source ~/nkp-<cluster>.env 2>/dev/null
ns=''; secret=''; : "${ns:?}"
[ "$secret" = dkp-loki ] && secret=''; : "${secret:?set a new Secret name, not dkp-loki}"
k=$(printenv LOKI_S3_ACCESS_KEY >/dev/null && printenv LOKI_S3_SECRET_KEY >/dev/null && echo ok); : "${k:?LOKI_S3_ACCESS_KEY or LOKI_S3_SECRET_KEY is not set}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" create secret generic "$secret" --from-file=AWS_ACCESS_KEY_ID=<(printf %s "$(printenv LOKI_S3_ACCESS_KEY)") --from-file=AWS_SECRET_ACCESS_KEY=<(printf %s "$(printenv LOKI_S3_SECRET_KEY)") --dry-run=client -o yaml | kubectl --kubeconfig "$CLUSTER_KUBECONFIG" apply -f - -o name
```

4. Values for the one Loki values file. `secret` is the name from item 3. `ann` is the key of the Reloader line in the item 2 output (the text before the `:`). Both stay empty with their guards until the user confirms them (rule 4). `LOKI_S3_URL` is the confirmed bucket URL (for AWS: `s3://<region>/<bucket>`). Show the file text in the plan. After "yes" [pdf p.550, p.660-661][live 2.19.0, app tree]:

```bash
# CHANGES  (writes the Loki values file on the operator host; changes no cluster)
source ~/nkp-<cluster>.env 2>/dev/null
secret=''; ann=''
[ "$secret" = dkp-loki ] && secret=''; : "${secret:?set a new Secret name, not dkp-loki}" "${ann:?}" "${LOKI_S3_URL:?}"
f="$HOME/$CLUSTER_NAME-grafana-loki-v3-values.yaml"
(umask 077 && cat > "$f" <<VALUES
loki:
  annotations:
    "$ann": $secret
  structuredConfig:
    storage_config:
      aws:
        s3: "$LOKI_S3_URL"
ingester: {extraEnvFrom: [{secretRef: {name: $secret}}]}
distributor: {extraEnvFrom: [{secretRef: {name: $secret}}]}
querier: {extraEnvFrom: [{secretRef: {name: $secret}}]}
queryFrontend: {extraEnvFrom: [{secretRef: {name: $secret}}]}
indexGateway: {extraEnvFrom: [{secretRef: {name: $secret}}]}
compactor: {extraEnvFrom: [{secretRef: {name: $secret}}]}
ruler: {extraEnvFrom: [{secretRef: {name: $secret}}]}
VALUES
)
```

If an override already exists (gitops `overrides.md` O2), add its values to this file before the apply: the apply replaces the whole ConfigMap. For Nutanix Objects, add the lines of the next paragraph under `aws:` in the same file. This is the file name of gitops O3 for `APP_ID` `grafana-loki-v3`.

The `extraEnvFrom` lists replace the default lists, so no component loads `dkp-loki` after this. With the Reloader annotation set to the new Secret, the Loki pods restart when that Secret changes. [pdf p.550]

**Nutanix Objects** (D-05, from a field run, not in the guide): add `region: us-east-1` under `aws:` [field] (the guide uses `us-east-1` for Nutanix Objects with NKP Insights [pdf p.1098]). The Objects host name must resolve in the cluster. [pdf p.511] A field run with a private CA set `http_config: {insecure_skip_verify: true}` under `aws:` [field]: that turns off the TLS check; the user decides. A field run also made the bucket with COSI (`BucketClaim` class `cosi-nutanix-nkp`); COSI: skill `nkp-storage-backup` (file `object-storage.md`, O5).

UNKNOWN (D-05): the full Loki values for Nutanix Objects (path-style access, a custom CA without `insecure_skip_verify`). Find out with: `source ~/nkp-<cluster>.env 2>/dev/null && kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get pods -A | grep -E 'loki.*(ingester|compactor)'`, then read the log of a `compactor` pod for S3 errors after the change.

UNKNOWN (D-33): whether `grafana-loki-v3` runs without `rook-ceph-cluster` when it uses an external store (the ClusterApp lists `rook-ceph-cluster` as a dependency [live 2.19.0]). Find out with: `source ~/nkp-site.env 2>/dev/null && kubectl --kubeconfig "$MGMT_KUBECONFIG" get clusterapps -o custom-columns='NAME:.metadata.name,NEEDS:.metadata.annotations.apps\.kommander\.d2iq\.io/dependencies' | grep loki`. Do not disable Rook Ceph for Loki without a lab test.

5. Apply with gitops `overrides.md` O3 (O4 for one cluster). Old logs stay in the old bucket; Loki does not copy them. [field]

Done when: O6 passes, and the `compactor` and `ingester` logs show no `S3` or `AccessDenied` errors.

## L5. Move the Loki index to TSDB

The guide adds a new period to `loki.schemaConfig.configs` with a future date. The move starts at 00:00:00 UTC of that date. You must add a new period; do not change the old one. [pdf p.551-552]

1. Read the current `schemaConfig` and `storage_config` in the defaults (L4 item 2 block, with the pattern `schemaConfig|boltdb|period|store:`). Copy the full old period entry: the list replaces the default list.
2. Values (the old entry first, then the new one) [pdf p.551-552]:

```yaml
loki:
  schemaConfig:
    configs:
      - from: "2020-09-07"           # copy the full old entry from the defaults
        store: boltdb-shipper
        schema: v11
      - from: "2027-01-01"           # a future date (UTC)
        store: tsdb
        object_store: s3             # the same store as the old entry
        schema: v13
        index:
          prefix: loki_index_
          period: 24h
  storage_config:
    tsdb_shipper:
      active_index_directory: /data/tsdb-index
      cache_location: /data/tsdb-cache
```

The guide puts `storage_config` under `loki`, but the S3 values (L4) use `loki.structuredConfig.storage_config`. Use the path that the defaults use (item 1).

3. Apply with gitops `overrides.md` O3. Done when: O6 passes. On the date, check the `ingester` log for `tsdb`.

## L6. Scale the logging stack

- Fluentd is usually the bottleneck. Sign: the Fluentd buffer grows for longer than `timekey + timekey_wait`. With `kube-prometheus-stack`, the Logging Operator dashboard in Grafana shows it. [pdf p.548-549]
- Loki: scale the ingesters first. Scale the distributors only when they use much CPU. Keep far fewer distributors than ingesters. [pdf p.549]
- Turn off the buffer of the `loki` ClusterOutput for more Fluentd throughput. [pdf p.549]

The guide example for 50 workers and 1.4 MB/s of logs. Logging Operator values (L2 says where they go) [pdf p.275]:

```yaml
fluentbit:
  inputTail:
    Mem_Buf_Limit: 512MB
fluentd:
  bufferStorageVolume:
    emptyDir:
      medium: Memory
  disablePvc: true
  scaling:
    replicas: 10
  resources:
    requests:
      memory: 1000Mi
      cpu: 1000m
    limits:
      memory: 2000Mi
      cpu: 1000m
```

Loki values: `ingester.replicas: 10`, `distributor.replicas: 2`. [pdf p.275] The guide example also sets a full `clusterOutputs` list with the `loki` output. Copy that output from the cluster first (L8 item 1 block), because the list replaces the default.

Done when: the Fluentd buffer stops growing, and the HelmReleases are `True`.

## L7. Admin logs: Kubernetes audit, journal, kernel (Fluent Bit app)

- The `fluent-bit` app sends audit, systemd journal, and kernel logs straight to the workspace Loki. Tenants cannot see them. Label in Loki: `log_source=kubernetes_host`. [pdf p.555, p.574]
- Cost: about 2 GB a day for each node, and 3-4 times more traffic into the logging stack. 10 nodes and 7 days of retention need 140 GB more. Grow the Ceph bucket first (skill `nkp-storage-backup`, file `object-storage.md`, O2). [pdf p.555, p.570]
- The API server audit policy and its log settings are set at cluster create. They cannot change later. [pdf p.570] Create flags: skill `nkp-install`.

Enable: skill `nkp-observability` step 3 (`fluent-bit`).

**Journal in `/run/log/journal`** (volatile journald). The default path is `/var/log/journal`. [pdf p.570] Override `fluent-bit` (gitops O3, `APP_ID=fluent-bit`):
1. Read the defaults ConfigMap `fluent-bit-<version>-config-defaults` with the gitops `overrides.md` O2 read block (`ns` = the namespace of the `fluent-bit` HelmRelease, `cm` = that name). [pdf p.570]
2. Keep only `extraVolumes`, `extraVolumeMounts`, and `config.inputs`. Add a volume `kubernetes-host` (`hostPath`, `path: /run/log/journal`, `type: Directory`) and its mount (`mountPath: /run/log/journal`). In `config.inputs`, add the line `Path /run/log/journal` to the `[INPUT]` with `Name systemd` and `Alias kubernetes_host`. [pdf p.571-573]

Done when: Grafana Explore (Loki) shows logs with `log_source=kubernetes_host`. [pdf p.574]

## L8. Forward logs to syslog, Splunk, or Elasticsearch (ClusterOutput)

The guide has no forward recipe. These are from field runs and the upstream Logging Operator docs. [field] D-06 stays open until a lab test.

- Way A (use this): a new `ClusterOutput` and a new `ClusterFlow` in the control namespace (L1). The NKP flow to Loki stays. Both flows get all pod logs.
- Way B (not recommended): `clusterOutputs` and `clusterFlows` lists in the Logging Operator values. The lists replace the NKP lists. A field run lost Loki this way. [field]
- A `ClusterOutput` is read only in the control namespace. Its Secrets must be in the same namespace. [field]
- On an air-gapped site, the target (syslog, Splunk, Elasticsearch) must be inside the site, and Fluentd pods need network access to it.

1. Read the API group, the control namespace, and the NKP `loki` output:

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" explain clusteroutputs | sed -n 's/^GROUP: *//p'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get loggings -o jsonpath='{range .items[*]}{.spec.controlNamespace}{"\n"}{end}'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get clusteroutputs -A -o jsonpath='{range .items[*]}{.metadata.namespace}/{.metadata.name}: {.spec.loki.url}{"\n"}{end}'
```

2. Ask the user for the type, the host, the port, and the TLS setting. For Splunk, the user puts `LOG_SPLUNK_HEC_TOKEN` in `~/nkp-site.env`; for Elasticsearch, `LOG_ES_PASSWORD` (rule 5). Write the file (CHANGES, operator host only). Set `out` to the output spec of the type (below), as one line of YAML flow text that the user confirmed:

```bash
# CHANGES  (writes the ClusterOutput and ClusterFlow file on the operator host; changes no cluster)
source ~/nkp-<cluster>.env 2>/dev/null
ns=''; name=''; out=''; : "${ns:?}" "${name:?}" "${out:?}"
grp=$(kubectl --kubeconfig "$CLUSTER_KUBECONFIG" explain clusteroutputs | sed -n 's/^GROUP: *//p'); : "${grp:?}"
cat > "$HOME/$CLUSTER_NAME-logout-$name.yaml" <<EOF
apiVersion: $grp/v1beta1
kind: ClusterOutput
metadata:
  name: $name
  namespace: $ns
spec: $out
---
apiVersion: $grp/v1beta1
kind: ClusterFlow
metadata:
  name: $name-all
  namespace: $ns
spec:
  globalOutputRefs:
    - $name
EOF
```

The output spec for each type (one line each; put the user's values in place of the host and port):

| Type | `out` |
|---|---|
| syslog (UDP) [field] | `{"syslog":{"host":"syslog.example.local","port":514,"transport":"udp","insecure":true,"format":{"app_name_field":"kubernetes.pod_name","log_field":"message"},"buffer":{"timekey":"1m","timekey_wait":"30s","timekey_use_utc":true}}}` |
| syslog (TLS) [field] | the same, with `"transport":"tls","port":6514,"insecure":false` |
| Splunk HEC [field] | `{"splunkHec":{"hec_host":"splunk.example.local","hec_port":8088,"protocol":"https","insecure_ssl":false,"index":"main","hec_token":{"valueFrom":{"secretKeyRef":{"name":"log-splunk","key":"hec_token"}}}}}` |
| Elasticsearch [field] | `{"elasticsearch":{"host":"es.example.local","port":9200,"scheme":"https","ssl_verify":true,"user":"elastic","logstash_format":true,"password":{"valueFrom":{"secretKeyRef":{"name":"log-es","key":"password"}}}}}` |

3. Splunk and Elasticsearch only: make the Secret in the control namespace. Show the plan. After "yes" (Elasticsearch: `log-es`, key `password`, from `LOG_ES_PASSWORD`):

```bash
# CHANGES  (creates the Splunk HEC token Secret in the control namespace)
source ~/nkp-<cluster>.env 2>/dev/null
ns=''; : "${ns:?}"
k=$(printenv LOG_SPLUNK_HEC_TOKEN >/dev/null && echo ok); : "${k:?LOG_SPLUNK_HEC_TOKEN is not set}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" create secret generic log-splunk --from-file=hec_token=<(printf %s "$(printenv LOG_SPLUNK_HEC_TOKEN)") --dry-run=client -o yaml | kubectl --kubeconfig "$CLUSTER_KUBECONFIG" apply -f - -o name
```

4. Preview (server dry run), then show the plan and apply after "yes":

```bash
# READ-ONLY  (server dry run: changes nothing)
source ~/nkp-<cluster>.env 2>/dev/null
name=''; : "${name:?}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" apply --dry-run=server -f "$HOME/$CLUSTER_NAME-logout-$name.yaml"
```

```bash
# CHANGES  (creates the ClusterOutput and ClusterFlow; Fluentd sends all pod logs to the new target too)
source ~/nkp-<cluster>.env 2>/dev/null
name=''; : "${name:?}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" apply -f "$HOME/$CLUSTER_NAME-logout-$name.yaml"
```

5. Check: `kubectl get clusteroutputs,clusterflows -A` shows ACTIVE `true` and no PROBLEMS. A field run had to restart the Fluentd pod before logs went out. [field] Ask the user before a restart (CHANGES).

UNKNOWN (D-06): whether these recipes work unchanged on NKP 2.19 (Fluentd 6.7.0 image plugins, TLS options). Find out with: `source ~/nkp-<cluster>.env 2>/dev/null && kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get clusteroutputs -A` (ACTIVE and PROBLEMS), then the target shows new log lines.

Done when: the target receives logs, and Grafana Explore (Loki) still gets logs.

## L9. Loki v2 → v3 move failed after an upgrade

In a platform upgrade, the LoggingStack controller moves Loki v2 to v3 and converts the old Loki override ConfigMaps. If a conversion fails, it stops. [pdf p.552]

1. Read the condition (L1, last command). Reason `Failed`, with a message like `Failed to convert Loki v2 overrides configurations to v3 format for: workspace '...', project '...', cluster '...' in workspace '...'`. Each name is one override that failed: a workspace override, a project override, or a cluster override of the Loki AppDeployment. [pdf p.552-553]

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get events --field-selector reason=GrafanaLokiV3Deployed
```

2. For each failed scope, write new values for the Loki v3 chart (only the settings of that scope). They are Helm values of the Loki chart, not the Loki server config file. [pdf p.553] Apply them: a workspace scope with gitops `overrides.md` O3, a cluster scope with O4, a project scope with L10 item 3. [pdf p.553]
3. Ask the controller to try again. Set `ls` to the LoggingStack name from L1. Show the plan. After "yes":

```bash
# CHANGES  (asks the LoggingStack controller to reconcile again)
source ~/nkp-<cluster>.env 2>/dev/null
ls=''; : "${ls:?}"
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" annotate loggingstack "$ls" reconcile.loggingstack.nkp.nutanix.com/requestedAt="$(date -u +%Y-%m-%dT%H:%M:%SZ)" --overwrite
```
The annotate passes a server dry run. [live 2.19.0]

Done when: `GrafanaLokiV3Deployed=True`, reason `Succeeded`, message `Loki v3 deployment completed`. [pdf p.554]

## L10. Project logging (multi-tenant, Ultimate)

Each project namespace gets its own Loki, Grafana, and a `Flow` for its pods. Users see only the logs of their projects. Workspace logging is needed first. [pdf p.563-564]

1. Read the project namespace (PROJECT NAMESPACE column; it can differ from the display name) [pdf p.566]:

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get projects
```

2. Enable `project-grafana-loki-v3`, `project-grafana-logging`, and `project-logging` with skill `nkp-platform-apps-gitops` step 2, with `--project <project name>`. [pdf p.566] Check: `kubectl get helmreleases -n <project namespace>` on the target shows `project-grafana-logging`, `project-grafana-loki-v3`, `project-loki-v3-object-bucket-claims` `True`. [pdf p.568]
3. Project Loki values: retention (as L3) and the bucket cap. The cap key on 2.19.0 is `dkp.project-grafana-loki-v3.additionalConfig.maxSize` (default `"5G"`). The guide writes `nkp.project-grafana-loki.maxSize` (p.554); 2.19.0 does not use that key. [live 2.19.0, app tree `project-grafana-loki-v3` 3.6.7] Two HelmReleases read the values [live 2.19.0, app tree]:
   - `project-grafana-loki-v3` (Loki) reads its defaults and the AppDeployment override (`configOverrides`).
   - `project-loki-v3-object-bucket-claims` (the bucket) reads its defaults and a ConfigMap named exactly `project-grafana-loki-v3-overrides` (`optional: true`), not the AppDeployment override.

   So retention goes through `configOverrides` (below). **The cap path is not confirmed:** tell the user that the cap can stay at 5G, and that project logs stop when the bucket is full.

UNKNOWN (D-34): whether the project Loki bucket cap must be in a ConfigMap named exactly `project-grafana-loki-v3-overrides` in the project namespace on the target cluster. Find out with: `source ~/nkp-<cluster>.env 2>/dev/null && kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get helmreleases -A -o custom-columns='NS:.metadata.namespace,NAME:.metadata.name,FROM:.spec.valuesFrom[*].name' | grep -E 'NS|project-loki-v3-object-bucket-claims'` on the target cluster, then the bucket size after a change.

   The ConfigMap for `configOverrides` goes on the management cluster, in the namespace of the `project-grafana-loki-v3` AppDeployment. The guide makes the ConfigMap in the project namespace, but its AppDeployment example shows the workspace namespace. [pdf p.567] Read the real namespace with `kubectl --kubeconfig "$MGMT_KUBECONFIG" get appdeployments -A | grep project-grafana-loki-v3` (READ-ONLY) and set `pns` to it. Write the values file and check it as in gitops `overrides.md` O3 items 1-2 (`APP_ID=project-grafana-loki-v3`). Use a new ConfigMap name. Show the plan. After "yes":

```bash
# CHANGES  (creates the project Loki override ConfigMap and sets it on the project AppDeployment)
source ~/nkp-<cluster>.env 2>/dev/null
pns=''; cm=''; : "${pns:?}" "${cm:?}"
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$pns" create configmap "$cm" --from-file=values.yaml="$HOME/$CLUSTER_NAME-project-grafana-loki-v3-values.yaml" --dry-run=client -o yaml | kubectl --kubeconfig "$MGMT_KUBECONFIG" apply -f -
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$pns" patch appdeployment project-grafana-loki-v3 --type merge -p "{\"spec\":{\"configOverrides\":{\"name\":\"$cm\"}}}"
```

4. The project Grafana URL (on the target cluster) [pdf p.569]:

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
pns=''; : "${pns:?}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$pns" get ingress "$pns-project-grafana-logging" -o go-template='https://{{with index .status.loadBalancer.ingress 0}}{{or .hostname .ip}}{{end}}{{with index .spec.rules 0}}{{with index .http.paths 0}}{{.path}}{{end}}{{end}}/explore{{"\n"}}'
```

- Each project Grafana has its own URL on each cluster. Give each group access with a role binding for each Grafana: skill `nkp-identity-security`. [pdf p.569]

Done when: a project user sees the logs of the project namespace, and not of other namespaces.
