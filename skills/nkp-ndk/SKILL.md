---
name: nkp-ndk
description: >
  NDK (Nutanix Data Services for Kubernetes) on NKP: install the ndk catalog app, application snapshots,
  restore and cross-namespace restore (ReferenceGrant), StorageCluster, Remote and ReplicationTarget,
  protection plans and schedules, async, sync, and NearSync replication, failover and failback, ndkcli,
  NDK alerts, NDK support logs.
metadata:
  nkp_versions: "2.19"
  last_verified: "2026-11-03"
  sources: "live 2.19.0 (bundle and chart), pdf 2.19, portal NDK 2.3, field"
---

# NKP NDK (Nutanix Data Services for Kubernetes)

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

## The NDK parts

| Part | What it is |
|---|---|
| Catalog app `ndk` | NDK 2.3.0, the only version in the 2.19.0 bundle (`nkp-nutanix-product-catalog-image-bundle-2.19.tar`). Pro and Ultimate. It needs cert-manager ≥ 1.13 and Nutanix CSI ≥ 3.7.1 (read both in step 1). NKP versions `>=2.18.0 <2.20.0`. Scope: workspace. [live 2.19.0] Nutanix infrastructure only. [pdf p.337] |
| HelmRelease `ndk` | In the workspace namespace of the target cluster (`kommander` on the management cluster). It installs into `ntnx-system`. `valuesFrom` has only the defaults ConfigMap; a workspace override adds slot 3 (skill `nkp-platform-apps-gitops`, `overrides.md` O1). [live 2.19.0] |
| Catalog defaults | Server TLS **off**, PC credentials from the CSI Secret `nutanix-csi-credentials`, images `docker.io/nutanix/*`, metrics off. [live 2.19.0] |
| Pods | Deployment `ndk-controller-manager` in `ntnx-system` (containers `manager`, `infra-manager`, `kube-rbac-proxy`, `job-scheduler`). Optional UI Deployment (`ui.enable`). [live 2.19.0] |
| `ndk-intercom-service` | Service `LoadBalancer`, TCP **2021**. It takes one IP from the MetalLB pool. Every `Remote` on the peer cluster points to this IP. [live 2.19.0] |
| CRDs | `dataservices.nutanix.com` and `scheduler.nutanix.com` (`JobScheduler`), all `v1alpha1`. Helm keeps them after an uninstall. [live 2.19.0][portal] |
| Not in the NKP bundle | `ndkcli`, the async failover recipes (jobs and image `ndk/recipes:2.3.0`), the KB-16326 support script, the alert rules. [live 2.19.0] See skill `nkp-airgap`, its file `prestage.md` (P6, P7). |

- One NDK instance on each cluster (management or workload). Each cluster has its own install. [pdf p.340]
- `ntnx-system` is for Nutanix parts only. Never put application objects or protection objects there. [portal]
- Use the full name `applications.dataservices.nutanix.com` with kubectl: `app` and `apps` are also Kommander kinds.

| File | Site variables |
|---|---|
| `~/nkp-site.env` secrets | `NDK_PULL_USERNAME` `NDK_PULL_TOKEN` |

`NDK_PULL_USERNAME` and `NDK_PULL_TOKEN` are the Nutanix Docker Hub login for NDK images (the token comes from the Nutanix Support Portal; an organization can have two tokens). [pdf p.338] Only a connected site needs them (step 3).

## Job → section

| Job | Where |
|---|---|
| Read the NDK state of a cluster | step 1 |
| Check the prerequisites (license, CSI, AOS, PC, iSCSI, MetalLB IP) | step 2 |
| Install NDK from the catalog (connected or air-gapped); TLS values | step 3 |
| Register the storage (`StorageCluster`) | step 4 |
| Write, dry run, and apply any NDK object | step 5 |
| Define an application, snapshot, restore, cross-namespace restore, local schedule | [references/protect.md](references/protect.md) |
| `ndkcli` | [references/protect.md](references/protect.md), P7 |
| Pair two clusters (`Remote`, `ReplicationTarget`), replicate, async, sync, NearSync | [references/replication.md](references/replication.md) |
| Failover, failback, delete a protected application | [references/replication.md](references/replication.md), R6-R9 |
| NDK alerts, metrics, NDK UI, support logs, upgrade, uninstall | [references/operations.md](references/operations.md) |
| NDK failures | "Common failures", then [references/operations.md](references/operations.md), X5 |

## Step 1: Read the NDK state

Ask the user for the cluster. For the management cluster, `WORKSPACE_NS` is `kommander`.

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n kommander get licenses.kommander.mesosphere.io -o jsonpath='{.items[*].status.dkpLevel}{"\n"}'
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get apps,appdeployments | grep -E 'NAME|ndk'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get csidrivers csi.nutanix.com --show-labels
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get crd referencegrants.gateway.networking.k8s.io
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get crd | grep -E 'dataservices.nutanix.com|scheduler.nutanix.com'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get helmreleases -A | grep -E 'NAME|ndk|cert-manager'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n ntnx-system get deploy,svc | grep -E 'NAME|ndk'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get storageclusters,remotes
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get applications.dataservices.nutanix.com,replicationtargets,appprotectionplans -A
```

How to read it:
- Tier `Starter`: NDK is not available. [live 2.19.0]
- `get apps` shows the catalog app (for example `ndk-2.3.0`) when the product catalog is in the workspace. No line: step 3, item 1.
- The CSIDriver labels show the CSI version. The NDK chart checks these labels before the install. [live 2.19.0] The `cert-manager` line shows the cert-manager version.
- `referencegrants` is there on 2.19.0 (Helm release `gateway-api-crds`). Cross-namespace restore needs it. No download. [live 2.19.0]
- No `dataservices.nutanix.com` CRDs and no `ndk-controller-manager`: NDK is not installed.
- `ndk-intercom-service` must show an `EXTERNAL-IP`. `<pending>`: the MetalLB pool has no free IP (skill `nkp-networking`).

Done when: you know the tier, the CSI version, whether NDK runs, and the `StorageCluster`, `Remote`, and application objects.

## Step 2: Check the prerequisites

| Need | Check |
|---|---|
| NKP Pro, Ultimate, or NKP Full Stack license [pdf p.338] | step 1 |
| Nutanix CSI ≥ 3.7.1; ≥ 3.8 for the NDK UI [pdf p.338] | step 1 |
| AOS 7.5 or later and pc.7.5 or later; 7.5.1 for NearSync and multi-namespace applications [pdf p.338][portal] | the user reads it in Prism |
| The Prism Central user is an admin (or has the Prism Admin role). NDK uses the CSI credentials. [pdf p.338][live 2.19.0] | the user confirms |
| A virtual IP on each Prism Element cluster for iSCSI Data Services; the Prism Central VIP on a scale-out Prism Central [pdf p.338] | the user reads it in Prism |
| `iscsi-initiator-utils` on each worker node [pdf p.338] | block below (Rocky and RHEL nodes) |
| One free MetalLB IP on each cluster [pdf p.338] | skill `nkp-networking` (MetalLB pool) |
| Replication only: the same StorageClass names and the same storage container names on both sites [portal] | skill `nkp-storage-backup`, step 1, on both clusters |

```bash
# USER-TERMINAL  (on each worker node, over SSH)
rpm -q iscsi-initiator-utils
```

Ubuntu nodes: the package check is not in the skills. The Kubernetes versions that NDK supports and the NDK scale limits (applications, snapshots, targets) are not in the skills (open item D-03, no check command).

Done when: each row passes, or the user accepts a gap.

## Step 3: Install NDK (catalog app)

Do this on each cluster that gets NDK. For two clusters that replicate, install the replication cluster first, then the primary, with the same TLS mode. [portal]

1. **Catalog.** Step 1 shows the `ndk` App: go to item 2. Else, in the workspace `kommander-workspace` (the catalog then goes to all workspaces [pdf p.340]):
   - Air-gapped: push `container-images/nkp-nutanix-product-catalog-image-bundle-2.19.tar` (skill `nkp-airgap`, step 4, "extra bundle"). Then create the catalog with skill `nkp-airgap`, its file `catalogs.md`, C1 step 3, with `repo` `nutanix-cloud-native/nkp-nutanix-product-catalog/collection` and `tag` `2.19`. The bundle has the chart, the images, and the catalog for NDK 2.3.0. [live 2.19.0] The guide way (`git clone`, `docker login`, `nkp create catalog-bundle`) is needed only for another NDK version. [pdf p.340]
   - Connected: skill `nkp-platform-apps-gitops`, its file `catalogs.md`, K2, with the URL `oci://ghcr.io/nutanix-cloud-native/nkp-nutanix-product-catalog/collection` and the tag `2.19`. [field] This public tag can change and can list more apps than NDK: enable only `ndk`.
   UNKNOWN (D-51): whether a connected Pro or Ultimate cluster has the product catalog already. Find out with: `source ~/nkp-<cluster>.env 2>/dev/null && kubectl --kubeconfig "$MGMT_KUBECONFIG" get ocirepositories -A | grep -i product-catalog`.
   Air-gapped with a site registry: after the push, check that the registry has the catalog artifact. `200`: it is there. `404`: not pushed, or the push did not keep the path (A-07). `401`: a wrong pull account, or a registry that wants a token login (curl sends basic auth only); the user checks the repository in the registry UI. `000`: no connection or a CA error.

```bash
# READ-ONLY  (HEAD request for the NDK catalog artifact with the pull account on stdin; prints only the HTTP code)
source ~/nkp-site.env 2>/dev/null
h="${REGISTRY_URL#*://}"; : "${h:?REGISTRY_URL is empty}"; p=''; case "$h" in */*) p="${h#*/}/" ;; esac
u=$(printenv REGISTRY_MIRROR_USERNAME); w=$(printenv REGISTRY_MIRROR_PASSWORD); w=${w//\\/\\\\}; w=${w//\"/\\\"}; { [ -n "$u" ] && printf 'user = "%s:%s"\n' "$u" "$w"; } | curl -K - -s -I -o /dev/null -w '%{http_code}\n' --cacert "$REGISTRY_CA_FILE" -H 'Accept: application/vnd.oci.image.index.v1+json, application/vnd.oci.image.manifest.v1+json' "https://${h%%/*}/v2/${p}nutanix-cloud-native/nkp-nutanix-product-catalog/collection/manifests/2.19"
```

2. **Image pull.** Air-gapped with the NKP registry mirror: the nodes pull `docker.io/nutanix/*` through the mirror. Do not set `imageCredentials`. [field]
   UNKNOWN (D-50): whether the NDK pods start in an air gap with no pull Secret (the Deployment always names `ndk-image-pull-secret`). Find out with: `source ~/nkp-<cluster>.env 2>/dev/null && kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n ntnx-system get events --field-selector reason=Failed`.
   Connected: the user puts `NDK_PULL_USERNAME` and `NDK_PULL_TOKEN` in `~/nkp-site.env` with an editor (rule 5). Then make the Secret with the chart default name on **each** target cluster (the Secret does not go to other clusters [pdf p.339]). Show the plan, stop for "yes":

```bash
# CHANGES  (creates or replaces the Secret ntnx-system/ndk-image-pull-secret)
source ~/nkp-<cluster>.env 2>/dev/null
k=$(printenv NDK_PULL_USERNAME >/dev/null && printenv NDK_PULL_TOKEN >/dev/null && echo ok); : "${k:?NDK_PULL_USERNAME or NDK_PULL_TOKEN MISSING}"
printf '{"auths":{"https://index.docker.io/v1/":{"auth":"%s"}}}' "$(printf '%s:%s' "$(printenv NDK_PULL_USERNAME)" "$(printenv NDK_PULL_TOKEN)" | base64 | tr -d '\n')" | kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n ntnx-system create secret generic ndk-image-pull-secret --type=kubernetes.io/dockerconfigjson --from-file=.dockerconfigjson=/dev/stdin --dry-run=client -o yaml | kubectl --kubeconfig "$CLUSTER_KUBECONFIG" apply -f -
```

3. **TLS.** Ask the user for the mode. The catalog default is no TLS: use it only for a test. [live 2.19.0][portal]

| Mode | Values | Facts |
|---|---|---|
| none | no values file | Replication traffic is not encrypted. [live 2.19.0] |
| `SELF_SIGNED` | `enable`, `mode`, `clusterName` | cert-manager makes the certificate. Not for production. [portal] |
| `ISSUER` | plus `issuer.issuerName` (an Issuer in `ntnx-system`) | [pdf p.341] |
| `SECRET` | `enable`, `mode`, `secretName` (a TLS Secret in `ntnx-system`; ask the user for its name and the certificate files, never propose a name), **no** `clusterName` | The chart fails when `clusterName` is set; it uses the certificate SAN. [live 2.19.0] The guide example sets both. [pdf p.341] |
| mTLS | add `enableMTLS: true` | The same CA signs the certificates of both clusters; the Secret also has `ca.crt`. [pdf p.341][portal] |

- `clusterName` must be different on each paired cluster, and it must be the DNS name in the certificate. The peer `Remote` uses it. [portal] A workspace override gives the same value to every cluster of the workspace. So use `SECRET` mode (one Secret on each cluster), or a cluster override (Ultimate; skill `nkp-platform-apps-gitops`, `overrides.md` O4), or one workspace for each cluster.
- Write the values file. Set only the values that the user gives: `tls_name` (the `clusterName`), `issuer`, `secret`, `mtls=true`, `metrics=true`. `metrics=true` adds the NDK ServiceMonitor with the guide label `prometheus.kommander.d2iq.io/select` [pdf p.645]; check the label with skill `nkp-observability`, `monitoring.md` M0. The chart needs the top-level `serviceMonitor` key with `prometheus.enable`. [live 2.19.0] Show the file and the plan, stop for "yes":

```bash
# CHANGES  (writes the NDK values file on the operator host; changes no cluster)
source ~/nkp-<cluster>.env 2>/dev/null
mode=''; tls_name=''; issuer=''; secret=''; mtls=''; metrics=''
case "$mode" in SELF_SIGNED|ISSUER|SECRET) ok=1 ;; *) ok='' ;; esac; : "${ok:?set mode to SELF_SIGNED, ISSUER, or SECRET}"
[ "$mode" = SECRET ] && : "${secret:?}" || : "${tls_name:?}"; [ "$mode" = ISSUER ] && : "${issuer:?}"
f="$HOME/$CLUSTER_NAME-ndk-values.yaml"
{ printf 'tls:\n  server:\n    enable: true\n    mode: %s\n' "$mode"
  case "$mode" in
    SELF_SIGNED) printf '    clusterName: %s\n' "$tls_name" ;;
    ISSUER) printf '    issuer:\n      issuerName: %s\n    clusterName: %s\n' "$issuer" "$tls_name" ;;
    SECRET) printf '    secretName: %s\n' "$secret" ;;
  esac
  if [ "$mtls" = true ]; then printf '    enableMTLS: true\n'; fi
  if [ "$metrics" = true ]; then printf 'prometheus:\n  enable: true\nserviceMonitor:\n  customLabels:\n    prometheus.kommander.d2iq.io/select: "true"\n'; fi
} > "$f" && cat "$f"
```

- Own load balancer for the intercom service: `intercomService.loadBalancerClass` and `loadBalancerIP`, both or none. With none, MetalLB gives a free pool IP. [pdf p.341-342] Add the two keys to the file by hand only when the user asks.
- The NDK UI values: [references/operations.md](references/operations.md), X3.

4. **Enable.** Use skill `nkp-platform-apps-gitops`, step 2, with `name` `ndk` and `app` the App name from step 1. With a values file, the file above is the `overrides.md` O3 file for `APP_ID` `ndk`. Do O3 items 2-4 there, and add `--config-overrides` with the same ConfigMap name. Some clusters only (`--clusters`): Ultimate. [pdf p.321]
5. **Check.** Run step 1. The HelmRelease `ndk` is READY `True`, `ndk-controller-manager` is `1/1` (one pod with 4 containers), and `ndk-intercom-service` has an `EXTERNAL-IP`. Then read the TLS mode (READ-ONLY): `kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n ntnx-system get configmap ndk-manager-config -o yaml | grep -E 'enableTLS|enableMTLS|clusterName|port:'`.

Done when: item 5 passes on each target cluster. Then do step 4.

## Step 4: Register the storage (StorageCluster)

Make one `StorageCluster` on each NDK cluster. It names the Prism Element cluster and the Prism Central of that cluster. [portal] The user reads the two UUIDs (`Cluster UUID`) and gives them:

```bash
# USER-TERMINAL  (once on a CVM of the Prism Element cluster, once on the Prism Central VM, over SSH)
ncli cluster info | grep -i 'cluster uuid'
```

Ask for a name (lowercase, for example the Prism Element name in DNS form). Set the three values. Show the plan, stop for "yes". Then write the file, and do step 5:

```bash
# CHANGES  (writes the StorageCluster file on the operator host; changes no cluster)
source ~/nkp-<cluster>.env 2>/dev/null
name=''; pe_uuid=''; pc_uuid=''
: "${name:?}" "${pe_uuid:?}" "${pc_uuid:?}"
f="$HOME/$CLUSTER_NAME-ndk-storagecluster.yaml"
printf 'apiVersion: dataservices.nutanix.com/v1alpha1\nkind: StorageCluster\nmetadata:\n  name: %s\nspec:\n  storageServerUuid: %s\n  managementServerUuid: %s\n' "$name" "$pe_uuid" "$pc_uuid" > "$f" && cat "$f"
```

Done when: `kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get storageclusters` shows AVAILABLE `true`. [live 2.19.0 CRD column]

## Step 5: Write, dry run, and apply an NDK object

Each write block is CHANGES. Before you run it, show the values and the file path, and stop for "yes" (rule 2). Then do the dry run, show the plan again, and stop for "yes" before the apply. Every NDK object in this skill goes the same way: (1) a CHANGES block writes a file on the operator host, (2) a server dry run, (3) the plan, "yes", and the apply. The NDK webhooks have `sideEffects: None`, so the dry run is safe. [live 2.19.0] Set `f` to the file that the write block printed.

```bash
# READ-ONLY  (server dry run: changes nothing)
source ~/nkp-<cluster>.env 2>/dev/null
f=''; : "${f:?}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" apply --dry-run=server -f "$f"
```

```bash
# CHANGES  (creates or changes the NDK objects in the file f)
source ~/nkp-<cluster>.env 2>/dev/null
f=''; : "${f:?}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" apply -f "$f"
```

- These cannot change after the create [live 2.19.0 CRD]: the spec of `StorageCluster`, `Remote`, `ReplicationTarget`, `ProtectionPlan`, and `ApplicationSnapshotRestore`; all of `ApplicationSnapshotReplication`; `AppProtectionPlan.spec.applicationName`; `expiresAfter` and `rpo`. To change one, delete it and make a new one (CHANGES, plan, "yes"; the user decides).

Done when: the apply prints `created` or `configured`, and the object shows `AVAILABLE` or `READY` `True` (each section names its check).

## Common failures

| Symptom | Cause | Fix |
|---|---|---|
| HelmRelease `ndk` fails: `CSIDriver csi.nutanix.com/com.nutanix.csi not detected` or `version may be incompatible` | CSI is missing or older than 3.7.1. [live 2.19.0] | skill `nkp-storage-backup`, step 1. |
| `Secret '...' not found in namespace 'ntnx-system'` | `config.secret.name` names a Secret that is not there. The catalog default is `nutanix-csi-credentials`. [live 2.19.0] | Remove `config.secret` from the override. |
| `.Values.tls.server.clusterName is required.` | `SELF_SIGNED` or `ISSUER` without `clusterName`. [live 2.19.0] | step 3, item 3. |
| `For NDK installation in mode 'SECRET', clusterName cannot be provided` | `SECRET` with `clusterName`. [live 2.19.0] | Remove `clusterName`. |
| `nil pointer evaluating interface {}.customLabels` | `prometheus.enable` without the top-level `serviceMonitor` key. [live 2.19.0] | Use the `metrics=true` lines of step 3. |
| NDK pods `ImagePullBackOff` | Connected: no or old pull Secret (token expired). Air-gapped: the product catalog bundle is not pushed. | step 3, item 2 or item 1. |
| `ndk-intercom-service` `EXTERNAL-IP` `<pending>` | No free MetalLB IP, or only one of `loadBalancerClass` and `loadBalancerIP`. [pdf p.342] | skill `nkp-networking`. |
| HelmRelease not Ready for another reason | | skill `nkp-troubleshooting` (file `flux.md`); a values error: skill `nkp-platform-apps-gitops`, `overrides.md` O5. |
| `Remote`, snapshot, replication, or failover errors | | [references/operations.md](references/operations.md), X5 |

## Related skills

Catalogs, AppDeployments, and overrides: skill `nkp-platform-apps-gitops`. Bundle push, catalog bundles, and the files from outside (P6, P7): skill `nkp-airgap`. CSI, StorageClasses, `VolumeSnapshot`, and Velero backups: skill `nkp-storage-backup`. MetalLB: skill `nkp-networking`. Prometheus rules and labels: skill `nkp-observability`. Debug ladder: skill `nkp-troubleshooting`.
