# NDK operations: alerts, UI, support logs, failures, upgrade, uninstall

Use this file from skill `nkp-ndk`. NDK must be installed (SKILL.md step 3).

## X1. NDK alert rules

The NDK guide gives a `PrometheusRule` file (`ndk-alert-config.yaml`). [portal] The fixed copy for an air-gapped site is the asset `ndk-alert-config.yaml` of skill `nkp-airgap` (P6 in its file `prestage.md`). Do not copy it into another place.

Facts about that file [live 2.19.0 asset]:
- `PrometheusRule` `ndk-event-rules` in `ntnx-system`, labels `prometheus: k8s` and `role: alert-rules`, 12 rules (snapshot, replication, retention, remote cluster, Prism Central authentication).
- Every rule reads the metric `kube_event_unique_events_total` with `container="prometheus-k8s-events-exporter"`. That metric comes from a Kubernetes event exporter. The guide installs the Prometheus Operator and that exporter first. [portal] NKP 2.19.0 has no event exporter app. [live 2.19.0]

UNKNOWN (D-54): an event exporter that gives `kube_event_unique_events_total` on NKP 2.19 (not in the bundle, not a ClusterApp). Find out with: `source ~/nkp-<cluster>.env 2>/dev/null && kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get pods -A | grep -i event`.

Tell the user: without that exporter, the rules load but never fire. Then, if the user wants them:

1. Check the asset SHA-256 (skill `nkp-airgap`, its file `prestage.md`, "Use an asset"). Set `dir` to that nkp-airgap folder.
2. Read the Prometheus `ruleSelector` and `ruleNamespaceSelector` (skill `nkp-observability`, `monitoring.md` M0). The rule must have those labels and be in a selected namespace. The asset labels `prometheus: k8s` and `role: alert-rules` are the upstream ones, not NKP ones. [live 2.19.0 asset]
3. Make a copy with the M0 labels. Set `lkey` and `lval` to one label of `ruleSelector` (from M0). Show the plan, stop for "yes":

```bash
# CHANGES  (writes a copy of the NDK alert rules with the NKP rule label on the operator host; changes no cluster)
source ~/nkp-<cluster>.env 2>/dev/null
dir=''; lkey=''; lval=''
: "${dir:?}" "${lkey:?}" "${lval:?}"
f="$HOME/$CLUSTER_NAME-ndk-alert-config.yaml"
awk -v k="$lkey" -v v="$lval" '{print} /^  labels:$/ && !d {print "    " k ": \"" v "\""; d=1}' "$dir/assets/ndk-alert-config.yaml" > "$f" && grep -v '^# ' "$f" | head -10
```

4. `ntnx-system` must be selected by `ruleNamespaceSelector` (M0). If it is not, stop: tell the user. Then do SKILL.md step 5 with `f`.

Done when: the Prometheus UI (skill `nkp-observability`) lists the group `ndk-snapshot-failure-rules`.

NDK controller metrics (a ServiceMonitor): SKILL.md step 3, `metrics=true`.

## X2. Read the NDK settings

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n ntnx-system get configmap ndk-manager-config -o yaml | grep -E 'enableTLS|enableMTLS|clusterName|issuerName|secretName|port:'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n ntnx-system get deploy ndk-controller-manager -o jsonpath='{range .spec.template.spec.containers[*]}{.name}{"\t"}{.image}{"\n"}{end}'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n ntnx-system get svc ndk-intercom-service
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n ntnx-system get certificates,issuers
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get helmreleases -A -o custom-columns='NS:.metadata.namespace,NAME:.metadata.name,FROM:.spec.valuesFrom[*].name' | grep -E 'NS|ndk'
```

To read the override values, use skill `nkp-platform-apps-gitops`, `overrides.md` O2 (with its `awk` mask), with `APP_ID` `ndk`.

## X3. NDK UI (optional)

The UI is off by default. It needs CSI 3.8 or later (read the version in SKILL.md step 1). [pdf p.338] It uses local users (roles `ADMIN`, `VIEWER`), not NKP single sign-on. Files-backed apps are not supported in the UI. [pdf p.342] Facts from the guide only; no lab run.

1. Ask the user: the host name (it must resolve to the ingress IP), the ingress class (`kommander-traefik` on NKP [pdf p.343]), and the TLS mode (`SECRET` with a TLS Secret `ndk-ui-tls` in `ntnx-system`, `ISSUER` with a ClusterIssuer, or `SELF_SIGNED` for a test).
2. The user makes a bcrypt hash for each user (password of 12 or more characters) in their own terminal. `htpasswd` asks for the password, so it is not in the shell history. (The guide puts the password in the command with `-b`.) [pdf p.342]

```bash
# USER-TERMINAL  (operator host; htpasswd asks for the password; the hash goes into the values file with an editor)
htpasswd -nBC 10 "" | tr -d ':\n'
```

3. Write the UI values into the NDK values file of SKILL.md step 3 (`$CLUSTER_NAME-ndk-values.yaml`), without the users. One app has one override file, so the block appends when the file exists. The step 3 block replaces the file: after it, do items 3 and 4 again. Set the values from item 1 (`issuer` only for `ISSUER`). Show the plan, stop for "yes":

```bash
# CHANGES  (adds the NDK UI values to the NDK values file on the operator host; changes no cluster)
source ~/nkp-<cluster>.env 2>/dev/null
host=''; class=''; uimode=''; issuer=''
: "${host:?}" "${class:?}" "${uimode:?SECRET, ISSUER, or SELF_SIGNED}"
f="$HOME/$CLUSTER_NAME-ndk-values.yaml"
if grep -qE '^(ui|config|deployment):' "$f" 2>/dev/null; then echo "UI values are already in $f: edit the file"; exit 1; fi
(umask 077 && touch "$f" && chmod 600 "$f" && { printf 'ui:\n  enable: true\ndeployment:\n  ui:\n    ndkUIService:\n      type: ClusterIP\nconfig:\n  uiConfig:\n    security:\n      publicScheme: https\n      headers:\n        hsts: false\n    secrets:\n      create: true\n      jwtSecret: ""\n      usersConfig: |\n        []\n'
  printf '    ingress:\n      enabled: true\n      host: %s\n      className: %s\n      tls:\n        mode: %s\n' "$host" "$class" "$uimode"
  case "$uimode" in
    SECRET) printf '        secretName: ndk-ui-tls\n' ;;
    ISSUER) printf '        issuer:\n          name: %s\n          kind: ClusterIssuer\n' "${issuer:?}" ;;
  esac
} >> "$f") && cat "$f"
```

4. The user opens the file with an editor and replaces `[]` under `usersConfig` with the users list (keys `id`, `username`, `password` = the hash, `role`). [pdf p.342-343]

```bash
# USER-TERMINAL  (operator host; the user adds the users list)
source ~/nkp-<cluster>.env 2>/dev/null
vi "$HOME/$CLUSTER_NAME-ndk-values.yaml"
```

The hashes then go into an override ConfigMap: tell the user. Never print the file again after item 4.

5. Apply with skill `nkp-platform-apps-gitops`, `overrides.md` O3 items 2-4, `APP_ID` `ndk`. For `SECRET`, the user makes the TLS Secret `ndk-ui-tls` first (`kubectl create secret tls ndk-ui-tls --cert=... --key=... -n ntnx-system`; CHANGES, the user gives the file paths). [pdf p.342]

Done when: `https://` plus the host opens the UI login page, and the user can sign in.

## X4. Support logs

The NDK support script and its config are in KB-16326 (portal, login). The user gets them before the site is closed (skill `nkp-airgap`, its file `prestage.md`, P7). [portal] UNKNOWN (D-55): the KB-16326 script name, its flags, and whether it reads Secrets. Find out with: `ls` of the KB-16326 folder that the user moved in, then read its README with the user. Until then, do not run it; give it to the user.

What the agent can collect (READ-ONLY; it prints no Secret data):

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
for c in manager infra-manager job-scheduler kube-rbac-proxy; do echo "== $c"; kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n ntnx-system logs deploy/ndk-controller-manager -c "$c" --tail=200; done
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n ntnx-system get events --sort-by=.lastTimestamp | grep -i ndk | tail -40
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get storageclusters,remotes -o wide
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get applications.dataservices.nutanix.com,applicationsnapshots,applicationsnapshotreplications,applicationsnapshotrestores,replicationtargets,protectionplans,appprotectionplans -A
```

`nkp diagnose` (skill `nkp-troubleshooting`) collects the cluster too. It is CHANGES.

## X5. Failures

| Symptom | Cause | Fix |
|---|---|---|
| `Remote` AVAILABLE `False` | A wrong `ndkServiceIp` or port; `clusterName` is not the DNS name in the peer certificate; `caBundle` wrong or not Base64; mTLS with a missing or wrong client Secret; TLS on one site and off on the other. [portal] | replication.md R1-R2; X2 on both sites. |
| Remote is `True`, replication waits | TCP 2021 between the two intercom IPs is closed. [field] | Ask the network team; D-01 in replication.md R1. |
| `ReplicationTarget` not `True` | `remoteName` wrong, or `namespaceName` does not exist on the peer. [portal] | replication.md R3. |
| Snapshot not READY-TO-USE | The first condition that is not `True` (protect.md P6). Config bigger than 8 MB: the snapshot stops. [portal] A PVC that is not from Nutanix CSI. | protect.md P1, P6. |
| Application selects zero objects | The labels or kinds do not match. [portal] | protect.md P1, item 1. |
| `is immutable` | The object or field cannot change (SKILL.md step 5 has the list). [live 2.19.0 CRD] | Delete the object and make it again (CHANGES, plan, "yes"). |
| More than 15 copies expected on the replication cluster | It keeps at most 15. [portal] | A local plan on the replication cluster keeps fewer. |
| Sync: `Synchronized=False` | The PE ports (2030, 2036, 2073, 2090, 8740), RTT > 5 ms, or the peer is down. [portal] | replication.md R0. |
| Sync UPFO: PVs stay `Terminating` | CSI `usePEFallback: true`. The guide sets it to `false` in the CSI values. [portal] | Skill `nkp-storage-backup` (CSI); D-56 below the table. |
| NearSync: `Protected=True` on the primary only | The remote Prism Element has no VIP. [portal] | The user sets the VIP. |
| NearSync PFO refused | `Protected=True` (`RPOMet`) is needed on both sites. [portal] | Wait one RPO time. |
| PFO waits at the pre-failover snapshot, or `PreTerminationSnapshotFailed` | The snapshot on the primary fails. [portal] | The guide annotates the Application on the primary `dataservices.nutanix.com/skip-pre-termination-snapshot=true` (CHANGES; then the failover has no safety snapshot). |
| `multinamespace feature not enabled` | An Application with `includeNamespaces` and no `--enable-multins`. [portal] | protect.md P1. |
| NDK pods `ImagePullBackOff`, HelmRelease errors | | SKILL.md "Common failures". |

UNKNOWN (D-56): the key in the NKP CSI addon (`clusterConfig.addons.csi`) that sets `usePEFallback` on NKP 2.19. Find out with: `source ~/nkp-<cluster>.env 2>/dev/null && kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n ntnx-system get deploy nutanix-csi-controller -o yaml | grep -i fallback`.
