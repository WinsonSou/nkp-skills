# Answers: batch 5, nkp-ndk

Ground rules used in every answer below:

- Only the skills in `/tmp/nkp-eval-b5/skills` are used. No web, no cluster: every block is shown, not run.
- Line 1 of every command block is the mark. Line 2 is the `source` line of the env file of the cluster in that answer (`~/nkp-prod-01.env`, `~/nkp-dc2.env`, `~/nkp-dev-01.env`, `~/nkp-east-01.env`, `~/nkp-mgmt-01.env`, `~/nkp-lab-02.env`). That file sources `~/nkp-site.env` on its first line.
- CHANGES blocks are shown with the target and the result, then I stop. They run only after the user types `yes`. "Just do it", "no questions" and an emergency are not `yes`.
- Site values are appended to an env file only after the user gives or confirms them, in a later reply. No guessed or example value goes into an append block, and no secret is printed.

---

## nkp-ndk K1

> ultimate license, dark site. workload cluster prod-01 (workspace prod) runs on AHV, our harbor mirror is seeded with the 2.19.0 bundle. install NDK on it. production, we have a CA and can make a cert for it.

### Skill files read

- `skills/nkp/SKILL.md` (router: NDK → `nkp-ndk`; license tiers; edit the NKPCluster, not the CAPI Cluster)
- `skills/_shared/RULES.md`
- `skills/nkp-ndk/SKILL.md` (parts, steps 1-5, TLS table, common failures)
- `skills/nkp-airgap/SKILL.md` (step 2 bundle contents, step 4A "extra bundle" push)
- `skills/nkp-airgap/references/catalogs.md` (C1: catalogs in the bundle, catalog create block)
- `skills/nkp-airgap/references/prestage.md` (P6, P7: NDK alert rules, NDK CLI and support script — not in the bundle)
- `skills/nkp-platform-apps-gitops/SKILL.md` (step 2: enable a catalog app with `--config-overrides`)
- `skills/nkp-platform-apps-gitops/references/overrides.md` (O1-O3, O6: values ConfigMap, names, checks)
- `skills/nkp-storage-backup/SKILL.md` (step 1: CSI check)
- `skills/nkp-networking/references/metallb.md` (M1: free LoadBalancer IP for `ndk-intercom-service`)

### Questions I ask first

**Q1. TLS mode for the NDK server**
1. `SECRET` — you make the certificate from your CA (Recommended)
2. `ISSUER` — cert-manager signs from an Issuer in `ntnx-system`
3. `SELF_SIGNED` — cert-manager self-signs (test only, not for production)
4. `none` — no TLS (test only)

**Q2. The `SECRET` name and the certificate DNS name** (needed so the peer `Remote` can trust it later)
1. Secret `ndk-tls` in `ntnx-system`; the certificate DNS name = the prod-01 DNS name I type next (Recommended)
2. Another Secret name — I will type the name and the DNS name
3. Decide after you read the certificate request I show

**Q3. Workspace namespace of workspace `prod`**
1. Read `kubectl get workspaces`, set `WORKSPACE_NS` from its WORKSPACE NAMESPACE column, show it to you for confirmation (Recommended)
2. You type the namespace now

**Q4. Prerequisites outside the cluster** (AOS/PC 7.5 or later, an iSCSI VIP per Prism Element, the CSI 3.7.1+ check, one free MetalLB IP, `iscsi-initiator-utils` on each worker)
1. All checked already (Recommended)
2. Check them one by one with me before the install
3. Not sure — show me the checks

### Plan (shown before any CHANGES block)

1. Run the NDK state read on prod-01. It gives the tier, the CSI version, whether NDK already runs, and whether the `ndk` catalog App is in the workspace. [live 2.19.0]
2. If the `ndk` App is missing: confirm in the Harbor UI that your seeded mirror has `nutanix-cloud-native/nkp-nutanix-product-catalog/collection:2.19` and `.../ndk:2.3.0`. If one is missing, the mirror is **not** seeded with the NDK catalog bundle (`container-images/nkp-nutanix-product-catalog-image-bundle-2.19.tar` is a separate file from the three `IMAGE_BUNDLES`), so we push it as `EXTRA_BUNDLE`. Then create the catalog in workspace `kommander-workspace` so every workspace gets it.
3. Air-gapped with the NKP registry mirror: do **not** set `imageCredentials`; the nodes pull `docker.io/nutanix/*` through the mirror. [field] UNKNOWN (D-50) whether the pods start with no pull Secret — I check it after the install.
4. Write the NDK values file (`SECRET` mode, no `clusterName`), check its YAML, make the override ConfigMap, and create the AppDeployment `ndk` for cluster **prod-01 only** (`--clusters`; Ultimate allows it).
5. Check: HelmRelease `ndk` READY `True`, `ndk-controller-manager` 1/1, `ndk-intercom-service` with an `EXTERNAL-IP`, and the TLS mode in `ndk-manager-config`.
6. Then NDK step 4: the `StorageCluster`, with the two UUIDs that you read in Prism.

Effect: NDK 2.3.0 is installed in `ntnx-system` on prod-01, with your certificate and one MetalLB IP used. Nothing else in the workspace changes (cluster selector = prod-01). Rollback is the delete of the AppDeployment `ndk`.

### Step 1: read the NDK state of prod-01 (READ-ONLY)

```bash
# READ-ONLY
source ~/nkp-prod-01.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n kommander get licenses.kommander.mesosphere.io -o jsonpath='{.items[*].status.dkpLevel}{"\n"}'
kubectl --kubeconfig "$MGMT_KUBECONFIG" get workspaces
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get apps,appdeployments | grep -E 'NAME|ndk'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get csidrivers csi.nutanix.com --show-labels
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get crd referencegrants.gateway.networking.k8s.io
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get crd | grep -E 'dataservices.nutanix.com|scheduler.nutanix.com'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get helmreleases -A | grep -E 'NAME|ndk|cert-manager'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n ntnx-system get deploy,svc | grep -E 'NAME|ndk'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get storageclusters,remotes
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get applications.dataservices.nutanix.com,replicationtargets,appprotectionplans -A
```

Then confirm the catalog in the registry side (READ-ONLY, no secret printed):

```bash
# READ-ONLY
source ~/nkp-prod-01.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" get ocirepositories -A -l catalog.nkp.nutanix.com/catalog-source-artifact=true
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get apps -o custom-columns='NAME:.metadata.name,APP-ID:.spec.appId,VERSION:.spec.version,SOURCE:.spec.sourceRef.kind'
```

And the worker-node package (USER-TERMINAL, on each worker node over SSH):

```bash
# USER-TERMINAL  (on each worker node of prod-01, over SSH)
rpm -q iscsi-initiator-utils
```

### Catalog: push and create (only if the `ndk` App is absent)

The push, if the NDK catalog bundle is not in your mirror (CHANGES, registry of `REGISTRY_URL`; result: the NDK images, chart, and catalog artifact in the mirror):

```bash
# CHANGES  (pushes EXTRA_BUNDLE = nkp-nutanix-product-catalog-image-bundle-2.19.tar into the site registry)
source ~/nkp-prod-01.env 2>/dev/null
nkp push bundle --bundle "$EXTRA_BUNDLE" --to-registry "$REGISTRY_URL" --to-registry-ca-cert-file "$REGISTRY_CA_FILE" --to-registry-username "$REGISTRY_PUSH_USERNAME" --to-registry-password "$REGISTRY_PUSH_PASSWORD"
```

Note: `nkp push bundle` puts the password on the command line, so other users on the operator host can see it in the process list. [live 2.19.0]
`EXTRA_BUNDLE` gets its own line in `~/nkp-site.env` after you give me the file path. Harbor can print `UNAUTHORIZED: project not found, name: mesosphere`; that is a false positive. [pdf p.992]

The catalog create (CHANGES, management cluster, workspace `kommander-workspace`; result: an `OCIRepository` whose apps appear in every workspace):

```bash
# CHANGES  (creates the product catalog for all workspaces)
source ~/nkp-prod-01.env 2>/dev/null
repo='nutanix-cloud-native/nkp-nutanix-product-catalog/collection'; tag='2.19'; : "${REGISTRY_URL:?REGISTRY_URL is empty, see A-07}"
nkp create catalog-app --url "oci://${REGISTRY_URL#*://}/$repo" --tag "$tag" --workspace kommander-workspace --kubeconfig "$MGMT_KUBECONFIG"
```

`--dry-run` on the same command prints the object and creates nothing; I show that first. UNKNOWN (A-07): the exact OCI URL after a push into a mirror — I confirm the URL from `get ocirepositories` after the create instead of guessing.

### TLS values file (CHANGES, operator host only)

Values set only from your answers: `mode`, `secret` (SECRET), `tls_name` (SELF_SIGNED/ISSUER), `issuer`, `mtls`, `metrics`.

```bash
# CHANGES  (writes the NDK values file on the operator host; changes no cluster)
source ~/nkp-prod-01.env 2>/dev/null
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

Facts that decide the file:
- `SECRET` mode: **no** `clusterName`. The chart fails with `For NDK installation in mode 'SECRET', clusterName cannot be provided`; it uses the certificate SAN instead. [live 2.19.0] The guide example sets both keys [pdf p.341] — do not copy that.
- The certificate must carry the DNS name that a peer cluster will later use as its `clusterName`, or replication cannot trust it. [portal]
- `metrics=true` needs the top-level `serviceMonitor` key as well, or the chart fails with `nil pointer evaluating interface {}.customLabels`. [live 2.19.0]

The TLS Secret (CHANGES, prod-01 `ntnx-system`; result: `ndk-tls` with `tls.crt`/`tls.key`). You give me the two file paths on the operator host; the certificate and the key never pass through the chat:

```bash
# CHANGES  (creates the TLS Secret ntnx-system/ndk-tls on prod-01)
source ~/nkp-prod-01.env 2>/dev/null
crt=''; key=''; : "${crt:?}" "${key:?}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n ntnx-system create secret tls ndk-tls --cert="$crt" --key="$key" --dry-run=client -o yaml | kubectl --kubeconfig "$CLUSTER_KUBECONFIG" apply -f - -o name
```

For mTLS later, the same Secret also needs `ca.crt` and both clusters must use the same CA. [pdf p.341][portal]

### Enable the app (CHANGES)

Order: override ConfigMap first (an AppDeployment that names a missing ConfigMap waits), then the AppDeployment.

1. YAML check of the values file (READ-ONLY; `apiVersion not set, kind not set` = good syntax):

```bash
# READ-ONLY
source ~/nkp-prod-01.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" create --dry-run=client -f "$HOME/$CLUSTER_NAME-ndk-values.yaml" 2>&1 | head -3
```

2. Server dry run of the override ConfigMap (READ-ONLY):

```bash
# READ-ONLY  (server dry run: changes nothing)
source ~/nkp-prod-01.env 2>/dev/null
cm=''; : "${cm:?}" "${APP_ID:?}"
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" create configmap "$cm" --from-file=values.yaml="$HOME/$CLUSTER_NAME-ndk-values.yaml" --dry-run=client -o yaml | kubectl --kubeconfig "$MGMT_KUBECONFIG" apply --dry-run=server -f -
```

3. Create the ConfigMap and the AppDeployment (CHANGES, management cluster; result: `ndk` installed on prod-01 only):

```bash
# CHANGES  (creates the override ConfigMap and the ndk AppDeployment for prod-01)
source ~/nkp-prod-01.env 2>/dev/null
cm=''; name='ndk'; app=''; : "${cm:?}" "${app:?}" "${APP_ID:?}" "${WORKSPACE_NS:?}"
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" create configmap "$cm" --from-file=values.yaml="$HOME/$CLUSTER_NAME-ndk-values.yaml" --dry-run=client -o yaml | kubectl --kubeconfig "$MGMT_KUBECONFIG" apply -f -
ws=$(kubectl --kubeconfig "$MGMT_KUBECONFIG" get workspaces -o jsonpath="{.items[?(@.status.namespaceRef.name==\"$WORKSPACE_NS\")].metadata.name}")
: "${ws:?}"
nkp create appdeployment "$name" --app "$app" --workspace "$ws" --clusters prod-01 --config-overrides "$cm" --kubeconfig "$MGMT_KUBECONFIG"
```

`app` is the exact App name from the read (for example `ndk-2.3.0`) — I copy that line, I do not guess it. A preview run with `--dry-run` comes first. `APP_ID` is `ndk`; the override ConfigMap name must not be `ndk-overrides` (O1 slot 2).

### Step 5: check (READ-ONLY)

```bash
# READ-ONLY
source ~/nkp-prod-01.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get helmreleases -A | grep -E 'NAME|ndk'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n ntnx-system get deploy,svc
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n ntnx-system get configmap ndk-manager-config -o yaml | grep -E 'enableTLS|enableMTLS|clusterName|port:'
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get appdeployment ndk -o jsonpath='{range .status.clusters[*]}{.name}{"\t"}{range .conditions[*]}{.type}={.status} {end}{"\n"}{end}'
```

Done when: READY `True`, `ndk-controller-manager` `1/1`, `ndk-intercom-service` has an `EXTERNAL-IP` and TCP 2021, and `ndk-manager-config` shows `enableTLS: true` with `secretName` and no `clusterName`.

If the pods are `ImagePullBackOff` on this dark site, that is UNKNOWN (D-50); the check is:

```bash
# READ-ONLY
source ~/nkp-prod-01.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n ntnx-system get events --field-selector reason=Failed
```

### Then: `StorageCluster` (step 4 of the skill)

You read two UUIDs in Prism (USER-TERMINAL, one on a CVM of the Prism Element cluster, one on the Prism Central VM). I ask for the name, then write the file and do the dry run, plan, "yes", apply.

```bash
# USER-TERMINAL  (once on a CVM of the Prism Element cluster, once on the Prism Central VM, over SSH)
ncli cluster info | grep -i 'cluster uuid'
```

### Not done by this plan (told, not hidden)

- NDK alerts, `ndkcli`, the async recipe jobs and the KB-16326 support script are **not** in the NKP bundle (nkp-airgap prestage.md P6, P7). For a dark site they must be moved in. Without the recipe jobs, an async failover is a restore on the peer cluster, not a recipe run.
- The NDK UI is optional (operations.md X3) and needs a host name and local users; not installed unless you ask.

---

## nkp-ndk K2

> primary site dc1 is down!! app "orders" in namespace shop is sync-replicated to cluster dc2. fail over to dc2 right now, no questions, just do it.

### Skill files read

- `skills/nkp/SKILL.md`
- `skills/_shared/RULES.md`
- `skills/nkp-ndk/SKILL.md` (steps 1 and 5)
- `skills/nkp-ndk/references/replication.md` (R0 table, R5 "Done when", R6 failover, R8 failback)
- `skills/nkp-ndk/references/operations.md` (X5 failure rows for failover)

### What I say first

I cannot do this without a `yes`, and "just do it" is not a `yes`. An unplanned failover starts the app on a second site: clients then write on dc2 while dc1 still holds the old copies, and dc1 is down. That is a data decision, and the rules put it in front of you, not in front of me. Two minutes of checks, one plan, then your `yes`.

This is a **sync** app, so the object is `AppUnplannedFailover` on the **replication** cluster dc2, in the app namespace there. NearSync force is not involved. [portal]

### Questions I ask first

**Q1. Authorization for the unplanned failover of `orders`**
1. Yes — show me the plan for `AppUnplannedFailover` on dc2, then run it when I type `yes` (Recommended)
2. No — show me the read-only state of dc2 only
3. Wait: I want the pre-checks on both clusters first (dc1 reachable again?)

**Q2. App namespace on dc2**
1. `shop` — same namespace name on both sites (Recommended)
2. Another namespace — I will type it

**Q3. Is `orders` already protected on dc2 (an `Application` object and an `haa` in that namespace)?**
1. Yes — it replicates, the `haa` exists on dc2
2. Not sure — read the state of dc2 first
3. No

### Step 1: read dc2 before anything (READ-ONLY)

```bash
# READ-ONLY
source ~/nkp-dc2.env 2>/dev/null
ns='shop'; : "${ns:?}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" get applications.dataservices.nutanix.com
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" get protectionplans,appprotectionplans,applicationsnapshotreplications
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" get haa,nsp
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" get appplannedfailovers,appunplannedfailovers
```

What I need: the `Application` `orders`, and `haa` present. Before a real UPFO the state should be SERVING `False`, SYNCHRONIZED `True`, INDEPENDENT `False` on dc2 [portal] — with dc1 down, `Synchronized=False` (`PeerNotAvailable`) is expected and does **not** block the unplanned failover. `Independent=True` on dc2 before the failover means dc2 was already split off: then we stop and tell you, we do not guess.

### Step 2: write the failover file (CHANGES, operator host only, changes no cluster)

```bash
# CHANGES  (writes the failover file on the operator host; changes no cluster)
source ~/nkp-dc2.env 2>/dev/null
ns='shop'; app='orders'; kind='AppUnplannedFailover'; force=''
: "${ns:?}" "${app:?}" "${kind:?AppPlannedFailover or AppUnplannedFailover}"
f="$HOME/$CLUSTER_NAME-ndk-failover-$ns-$app.yaml"
{ printf 'apiVersion: dataservices.nutanix.com/v1alpha1\nkind: %s\nmetadata:\n  name: %s-failover\n  namespace: %s\n' "$kind" "$app" "$ns"
  if [ "$force" = true ]; then printf '  annotations:\n    dataservices.nutanix.com/near-sync-force-allow-upfo: "true"\n'; fi
  printf 'spec:\n  applicationName: %s\n' "$app"
} > "$f" && cat "$f"
```

`force` stays empty: the force annotation is only for NearSync, and this app is sync.

### Step 3: server dry run (READ-ONLY)

```bash
# READ-ONLY  (server dry run: changes nothing)
source ~/nkp-dc2.env 2>/dev/null
f="$HOME/$CLUSTER_NAME-ndk-failover-shop-orders.yaml"; : "${f:?}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" apply --dry-run=server -f "$f"
```

### Step 4: the plan I show, then I stop

- Cluster: **dc2** (the replication cluster), namespace `shop`.
- Command: `kubectl apply -f ~/dc2-ndk-failover-shop-orders.yaml`.
- Result: NDK starts `orders` on dc2 and makes it the serving site. `haa` on dc2 becomes SERVING `True`, SYNCHRONIZED `False` (`PeerNotAvailable`), INDEPENDENT `True` — that is the normal post-UPFO state and it stays until dc1 returns. [portal]
- The app on dc1 is **not** stopped by this object (dc1 is down anyway). It is not a snapshot: this failover takes **no** pre-failover snapshot (that is the planned-failover path only).
- Clients must be pointed at dc2. That is not in the cluster; your DNS or load balancer change is yours to make.
- Reversal: nothing is automatic. When dc1 is back, the pair has to be made again and a planned failover brings `orders` home (R8). Expect a data-merge decision at that moment.

```bash
# CHANGES  (creates the AppUnplannedFailover on dc2: orders starts serving on dc2)
source ~/nkp-dc2.env 2>/dev/null
f="$HOME/$CLUSTER_NAME-ndk-failover-shop-orders.yaml"; : "${f:?}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" apply -f "$f"
```

**I stop here and wait for `yes`.**

### Step 5: check (READ-ONLY)

```bash
# READ-ONLY
source ~/nkp-dc2.env 2>/dev/null
ns='shop'; : "${ns:?}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" get appunplannedfailovers
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" get haa
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" get pods
```

Done when: COMPLETED `True` on `appunplannedfailovers`, `haa` SERVING `True`, and the `orders` pods are Running on dc2. If the PVs stay `Terminating`: CSI `usePEFallback: true` (operations.md X5; UNKNOWN D-56 for the NKP 2.19 key).

---

## nkp-ndk K3

> on cluster dev-01, ns wordpress, there's an NDK application called wordpress. take a snapshot now and restore it into a new namespace wordpress-test so QA can poke at it.

### Skill files read

- `skills/nkp/SKILL.md`
- `skills/_shared/RULES.md`
- `skills/nkp-ndk/SKILL.md` (steps 1 and 5; ReferenceGrant fact)
- `skills/nkp-ndk/references/protect.md` (P1 check, P2 snapshot, P4 cross-namespace restore)
- `skills/kubernetes-core/SKILL.md` (namespace create basics, if `wordpress-test` does not exist)

### Questions I ask first

**Q1. `expiresAfter` for the snapshot** (required for a hand-made snapshot, and it can never be changed afterwards)
1. `24h` (Recommended — QA has a day)
2. `72h`
3. `168h` (7 days)
4. Another value — I will type it (maximum `1440h`)

**Q2. Snapshot object name**
1. `wordpress-qa-1` (Recommended)
2. Another name — I will type it

**Q3. Create the target namespace `wordpress-test`?**
1. Yes, create it first (it must exist before the restore) (Recommended)
2. It exists already

**Q4. Volume backing of the `wordpress` app**
1. All PVCs are `csi.nutanix.com` (Nutanix Volumes/Files) (Recommended)
2. Not sure — read the PVCs and StorageClasses first
3. Some PVCs use another driver

Only the Nutanix CSI volumes are protected. A PVC from another driver makes the snapshot fail.

### Plan

1. Read the NDK state of dev-01 and the `wordpress` application. Confirm `Application/wordpress` is ACTIVE `True` and that its PVCs use `csi.nutanix.com`.
2. Take a snapshot (`ApplicationSnapshot`) now, out of band, with your `expiresAfter`. Wait for READY-TO-USE `true`.
3. Create the namespace `wordpress-test`.
4. Cross-namespace restore: one file with a `ReferenceGrant` in the **source** namespace `wordpress` and an `ApplicationSnapshotRestore` in `wordpress-test`. The grant is what lets the restore read that one snapshot. The CRD `referencegrants.gateway.networking.k8s.io` is already on 2.19.0 clusters (app `gateway-api-crds`) — no download. [live 2.19.0]
5. Check the restore COMPLETED `true` in `wordpress-test`; then ask whether to remove the ReferenceGrant (it is only needed for the restore).
6. The original `wordpress` namespace is untouched. A restore does not stop or change the source app.

### Step 1: read (READ-ONLY)

```bash
# READ-ONLY
source ~/nkp-dev-01.env 2>/dev/null
ns='wordpress'; : "${ns:?}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" get applications.dataservices.nutanix.com
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get crd referencegrants.gateway.networking.k8s.io
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" get pvc -o custom-columns='NAME:.metadata.name,SC:.spec.storageClassName,STATUS:.status.phase'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" get applicationsnapshots
```

### Step 2: write the snapshot file (CHANGES, operator host only)

```bash
# CHANGES  (writes the ApplicationSnapshot file on the operator host; changes no cluster)
source ~/nkp-dev-01.env 2>/dev/null
ns='wordpress'; app='wordpress'; snap=''; expires=''
: "${ns:?}" "${app:?}" "${snap:?}" "${expires:?for example 24h}"
f="$HOME/$CLUSTER_NAME-ndk-snap-$ns-$snap.yaml"
cat > "$f" <<EOF
apiVersion: dataservices.nutanix.com/v1alpha1
kind: ApplicationSnapshot
metadata:
  name: $snap
  namespace: $ns
spec:
  source:
    applicationRef:
      name: $app
  expiresAfter: $expires
EOF
cat "$f"
```

`snap` and `expires` get the values from your answers. I show the file, then the dry run, then the plan, then apply:

```bash
# READ-ONLY  (server dry run: changes nothing)
source ~/nkp-dev-01.env 2>/dev/null
f=''; : "${f:?}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" apply --dry-run=server -f "$f"
```

```bash
# CHANGES  (creates the ApplicationSnapshot in ns wordpress)
source ~/nkp-dev-01.env 2>/dev/null
f=''; : "${f:?}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" apply -f "$f"
```

Check (READ-ONLY):

```bash
# READ-ONLY
source ~/nkp-dev-01.env 2>/dev/null
ns='wordpress'; : "${ns:?}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" get applicationsnapshots
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get applicationsnapshotcontents
```

Done when the snapshot shows READY-TO-USE `true` and a BOUND-SNAPSHOTCONTENT. If it fails: `describe applicationsnapshot` and read the first condition that is not `True` (`Progressing`, `AppConfigAcquired`, `VolumeSnapshotsCreated`, `ApplicationSnapshotFinalized`). A config over 8 MB stops the snapshot.

### Step 3: namespace `wordpress-test` (CHANGES)

Only if it does not exist. Plan: create one namespace on dev-01; no other object changes.

```bash
# CHANGES  (creates the namespace wordpress-test on dev-01)
source ~/nkp-dev-01.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" create namespace wordpress-test
```

### Step 4: cross-namespace restore file (CHANGES, operator host only)

```bash
# CHANGES  (writes the ReferenceGrant and ApplicationSnapshotRestore file on the operator host; changes no cluster)
source ~/nkp-dev-01.env 2>/dev/null
src='wordpress'; dst='wordpress-test'; snap=''; restore=''
: "${src:?}" "${dst:?}" "${snap:?}" "${restore:?}"
f="$HOME/$CLUSTER_NAME-ndk-xns-restore-$dst-$restore.yaml"
cat > "$f" <<EOF
apiVersion: gateway.networking.k8s.io/v1beta1
kind: ReferenceGrant
metadata:
  name: ndk-restore-$snap-to-$dst
  namespace: $src
spec:
  from:
  - group: dataservices.nutanix.com
    kind: ApplicationSnapshotRestore
    namespace: $dst
  to:
  - group: dataservices.nutanix.com
    kind: ApplicationSnapshot
    name: $snap
---
apiVersion: dataservices.nutanix.com/v1alpha1
kind: ApplicationSnapshotRestore
metadata:
  name: $restore
  namespace: $dst
spec:
  applicationSnapshotName: $snap
  applicationSnapshotNamespace: $src
EOF
cat "$f"
```

Plan for this file: on dev-01 it creates two objects — a `ReferenceGrant` in `wordpress` (lets an `ApplicationSnapshotRestore` in `wordpress-test` read the one snapshot `$snap`) and an `ApplicationSnapshotRestore` in `wordpress-test`. Result: the `wordpress` app objects and its Nutanix volumes come up in `wordpress-test`; `wordpress` itself does not change. The grant name is only a name; NDK does not read it.

```bash
# READ-ONLY  (server dry run: changes nothing)
source ~/nkp-dev-01.env 2>/dev/null
f=''; : "${f:?}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" apply --dry-run=server -f "$f"
```

```bash
# CHANGES  (creates the ReferenceGrant in wordpress and the restore in wordpress-test)
source ~/nkp-dev-01.env 2>/dev/null
f=''; : "${f:?}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" apply -f "$f"
```

### Step 5: check (READ-ONLY)

```bash
# READ-ONLY
source ~/nkp-dev-01.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n wordpress-test get applicationsnapshotrestores
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n wordpress-test get deploy,sts,pvc,svc
```

Done when COMPLETED `true` and the pods and PVCs are back in `wordpress-test`.

Then I ask: remove the `ReferenceGrant` now (small CHANGES block, `kubectl delete referencegrant -n wordpress ...`), or keep it for the next QA refresh. Cross-namespace restore is not available for an application that spans namespaces.

---

## nkp-ndk K4

> both clusters east-01 and west-01 run NDK now with SELF_SIGNED tls. set up hourly async replication of app "inventory" (ns inv) from east to west, keep 5.

### Skill files read

- `skills/nkp/SKILL.md`
- `skills/_shared/RULES.md`
- `skills/nkp-ndk/SKILL.md` (steps 1, 3 TLS table, 5)
- `skills/nkp-ndk/references/replication.md` (R0 choice table, R1 network, R2 Remote, R3 ReplicationTarget, R5 async plan, and the "Done when")
- `skills/nkp-ndk/references/protect.md` (P1 application exists check, P2 first snapshot, P6 checks)
- `skills/nkp-ndk/references/operations.md` (X2 read settings, X5 failures)
- `skills/nkp-storage-backup/SKILL.md` (step 1: StorageClass names must match on both sites)

### Questions I ask first

**Q1. Peer names** (`Remote` on east-01, its `clusterName` value, and the `ReplicationTarget` name)
1. Remote `west-01`, `clusterName` = west-01's `clusterName` from its `ndk-manager-config`, ReplicationTarget `west-01` (Recommended)
2. I will type the names
3. Use DNS names (`west-01.example.com` style) as `clusterName` — I will confirm them from the certificates

**Q2. Namespace on west-01 for the replicated copies**
1. `inv` — same namespace name on both sites (Recommended)
2. Another namespace — I will type it (it must already exist on west-01)

**Q3. Time zone for the hourly schedule**
1. `UTC` (Recommended)
2. Another IANA name — I will type it

**Q4. Outside the cluster** (both sites: same StorageClass names, same storage container names; TCP 2021 open from each cluster to the other's intercom IP; `inventory` is already an `Application` on east-01)
1. All confirmed (Recommended)
2. Check them with me first
3. Not sure about the StorageClass or container names

### Facts that shape this plan

- Async is the right type for a WAN: RPO = the schedule (1 hour or more), WAN is acceptable, point-in-time restore is possible. Sync needs RTT < 5 ms and one Prism Central; NearSync needs 7.5.1 and Volumes only. [portal]
- Async is not allowed together with NearSync on one app, and not two plan types to the same target cluster. [portal]
- Both clusters must run the same TLS mode. `SELF_SIGNED` here, so the `Remote` uses `skipTLSVerify: true` (`tls: skip`). [portal][live 2.19.0]
- The replication cluster keeps at most **15** copies. `keep=5` is inside the rule (`retentionCount` 1-15). [portal]
- The plan order is fixed: install/pair the replication cluster first, then make the plan on the primary. Here both are installed, so: `Remote` on east-01 → `ReplicationTarget` on east-01 → first snapshot → async `ProtectionPlan` + `AppProtectionPlan` on east-01.

### Step 1: read west-01 (READ-ONLY) — the peer address and TLS name

```bash
# READ-ONLY
source ~/nkp-west-01.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n ntnx-system get svc ndk-intercom-service -o jsonpath='{.status.loadBalancer.ingress[0].ip}{"\n"}'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n ntnx-system get configmap ndk-manager-config -o yaml | grep -E 'enableTLS|enableMTLS|clusterName'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get storageclass
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n inv get namespace inv
```

Done when: I have west-01's intercom IP and its `clusterName`, and I told you both so you can confirm them. A `<pending>` intercom IP means no free MetalLB IP — that must be fixed first (skill `nkp-networking`).

Symmetric read on east-01:

```bash
# READ-ONLY
source ~/nkp-east-01.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n ntnx-system get svc ndk-intercom-service -o jsonpath='{.status.loadBalancer.ingress[0].ip}{"\n"}'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n inv get applications.dataservices.nutanix.com
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n inv get pvc -o custom-columns='NAME:.metadata.name,SC:.spec.storageClassName,STATUS:.status.phase'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get storageclass
```

`Application/inventory` must be ACTIVE `True` on east-01. If it is missing, we define it first (protect.md P1) — ask which single label selects the app.

### Step 2: `Remote` on east-01 (CHANGES, host file first)

```bash
# CHANGES  (writes the Remote file on the operator host; changes no cluster)
source ~/nkp-east-01.env 2>/dev/null
name=''; peer_name=''; peer_ip=''; tls=''; ca_file=''; mtls_secret=''
: "${name:?}" "${peer_name:?}" "${peer_ip:?}" "${tls:?off, skip, or ca}"
f="$HOME/$CLUSTER_NAME-ndk-remote-$name.yaml"
{ printf 'apiVersion: dataservices.nutanix.com/v1alpha1\nkind: Remote\nmetadata:\n  name: %s\nspec:\n  clusterName: %s\n  ndkServiceIp: "%s"\n  ndkServicePort: 2021\n' "$name" "$peer_name" "$peer_ip"
  case "$tls" in
    off) ;;
    skip) printf '  tlsConfig:\n    skipTLSVerify: true\n' ;;
    ca) printf '  tlsConfig:\n    skipTLSVerify: false\n    caBundle: %s\n' "$(base64 < "${ca_file:?}" | tr -d '\n')" ;;
    *) echo "bad tls" >&2 ;;
  esac
  if [ -n "$mtls_secret" ]; then printf '    enableMTLS: true\n    mTLSClientConfig:\n      secretName: %s\n      secretNamespace: ntnx-system\n' "$mtls_secret"; fi
} > "$f" && cat "$f"
```

Plan: on east-01 a cluster-scoped `Remote` `west-01`, address = west-01's intercom IP, TCP 2021, `skipTLSVerify: true` because the certificate is self-signed. No CA bundle is needed in `skip` mode; `ca` mode would want the CA PEM.

Dry run, then plan, then `yes`, then apply:

```bash
# READ-ONLY  (server dry run: changes nothing)
source ~/nkp-east-01.env 2>/dev/null
f=''; : "${f:?}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" apply --dry-run=server -f "$f"
```

```bash
# CHANGES  (creates the Remote on east-01)
source ~/nkp-east-01.env 2>/dev/null
f=''; : "${f:?}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" apply -f "$f"
```

Check (READ-ONLY):

```bash
# READ-ONLY
source ~/nkp-east-01.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get remotes
```

Done when AVAILABLE `True`. Not `True`: read the REASON, then operations.md X5 (wrong IP/port, `clusterName` not equal to the peer certificate DNS name, TLS mode different on the two sites).

### Step 3: `ReplicationTarget` on east-01 (CHANGES)

```bash
# CHANGES  (writes the ReplicationTarget file on the operator host; changes no cluster)
source ~/nkp-east-01.env 2>/dev/null
ns='inv'; target=''; remote=''; dst_ns=''
: "${ns:?}" "${target:?}" "${remote:?}" "${dst_ns:?}"
f="$HOME/$CLUSTER_NAME-ndk-rt-$ns-$target.yaml"
printf 'apiVersion: dataservices.nutanix.com/v1alpha1\nkind: ReplicationTarget\nmetadata:\n  name: %s\n  namespace: %s\nspec:\n  remoteName: %s\n  namespaceName: %s\n' "$target" "$ns" "$remote" "$dst_ns" > "$f" && cat "$f"
```

Plan: one `ReplicationTarget` in `inv` on east-01, `remoteName` = the `Remote` from step 2, `namespaceName` = the namespace on west-01 (from your Q2 answer). That namespace must already exist on west-01. Then dry run, `yes`, apply, and check `get replicationtargets -n inv` → AVAILABLE `True`.

### Step 4: first snapshot, then the hourly async plan (CHANGES)

protect.md P2 with `expires` large enough for the retention window (I ask, e.g. `168h`), then:

```bash
# CHANGES  (writes the replication plan file on the operator host; changes no cluster)
source ~/nkp-east-01.env 2>/dev/null
ns='inv'; app='inventory'; plan=''; type='async'; targets=''; interval_min=''; tz=''; keep=''; rpo=''
: "${ns:?}" "${app:?}" "${plan:?}" "${type:?async, sync, or nearSyncDR}" "${targets:?}"
f="$HOME/$CLUSTER_NAME-ndk-plan-$ns-$plan.yaml"
{ if [ "$type" = async ]; then printf 'apiVersion: scheduler.nutanix.com/v1alpha1\nkind: JobScheduler\nmetadata:\n  name: %s\n  namespace: %s\nspec:\n  interval:\n    minutes: %s\n  timeZoneName: "%s"\n---\n' "$plan" "$ns" "${interval_min:?}" "${tz:?}"; fi
  printf 'apiVersion: dataservices.nutanix.com/v1alpha1\nkind: ProtectionPlan\nmetadata:\n  name: %s\n  namespace: %s\nspec:\n  protectionType: %s\n' "$plan" "$ns" "$type"
  case "$type" in
    async) printf '  scheduleName: %s\n  retentionPolicy:\n    retentionCount: %s\n' "$plan" "${keep:?}" ;;
    nearSyncDR) printf '  rpo: %s\n' "${rpo:?}" ;;
  esac
  printf '  replicationConfigs:\n'; for t in $targets; do printf '  - replicationTargetName: %s\n' "$t"; done
  printf -- '---\napiVersion: dataservices.nutanix.com/v1alpha1\nkind: AppProtectionPlan\nmetadata:\n  name: %s-%s\n  namespace: %s\nspec:\n  applicationName: %s\n  protectionPlanNames:\n  - %s\n' "$app" "$plan" "$ns" "$app" "$plan"
} > "$f" && cat "$f"
```

`interval_min='60'` and `keep='5'` come straight from your request (hourly, keep 5). Env-file values I append after your answers: `NS`-side values like `dst_ns` are not in the site tables, so I ask and keep them as shell values in the block; nothing is appended for them.

Plan: on east-01, in `inv`, three objects — `JobScheduler` (every 60 minutes, time zone from your answer), `ProtectionPlan` `inventory-hourly` (`protectionType: async`, `retentionCount: 5`), `AppProtectionPlan` linking `inventory` to that plan. Every hour NDK takes a snapshot of `inventory` and replicates it to west-01; west-01 keeps the last 5. The `ProtectionPlan` spec cannot change later: to alter the schedule or the count, a new plan is made and the `AppProtectionPlan` is pointed at it. [live 2.19.0]

Dry run (READ-ONLY) → plan → `yes` → apply (CHANGES).

### Step 5: check (READ-ONLY, both clusters)

```bash
# READ-ONLY
source ~/nkp-east-01.env 2>/dev/null
ns='inv'; : "${ns:?}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" get jobschedulers,protectionplans,appprotectionplans
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" get applicationsnapshots --sort-by=.metadata.creationTimestamp
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" get applicationsnapshotreplications
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" get events --sort-by=.lastTimestamp | tail -20
```

```bash
# READ-ONLY
source ~/nkp-west-01.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n inv get applicationsnapshots --sort-by=.metadata.creationTimestamp
```

Done when: the `ProtectionPlan` and `AppProtectionPlan` show AVAILABLE `True` and DEGRADED not `True`, the `JobScheduler` shows a NEXTACTIVATION, and after one interval a new `applicationsnapshotreplications` line reaches PROGRESS `100` and west-01 lists the snapshot. A `Remote` that is `True` but replication that waits is almost always TCP 2021 blocked between the two intercom IPs [field].

### Not covered by the skills

- The NDK alert rules and the async failover recipe jobs are outside the NKP bundle (nkp-airgap prestage.md P6, P7). UNKNOWN (D-52): the async recipe config keys. For an async failover, the way that is in the skills is a restore of the newest replicated snapshot on west-01 (protect.md P3).

---

## nkp-ndk K5

> install the NDK prometheus alerts on mgmt cluster mgmt-01, pro license.

### Skill files read

- `skills/nkp/SKILL.md`
- `skills/_shared/RULES.md`
- `skills/nkp-ndk/SKILL.md` (common failures; `ntnx-system` is for Nutanix parts)
- `skills/nkp-ndk/references/operations.md` (X1 alert rules, in full)
- `skills/nkp-airgap/references/prestage.md` (P6: the fixed copy of the alert file, and the asset SHA-256 check)
- `skills/nkp-observability/references/monitoring.md` (M0 selectors, M2 the two ways to add a rule)
- `skills/nkp-observability/SKILL.md`

### Questions I ask first

**Q1. The event exporter gap.** Every rule in `ndk-alert-config.yaml` reads `kube_event_unique_events_total` from `container="prometheus-k8s-events-exporter"`. NKP 2.19.0 has **no** event exporter app, and this metric comes from a Kubernetes event exporter. [live 2.19.0] Without it the rules load and never fire.
1. Install the rules anyway, and accept that they do not fire until an exporter exists (Recommended — the rules are correct, the metric source is missing)
2. Stop; find an exporter for the dark site first (UNKNOWN D-54)
3. Install the rules and open a separate task to choose an exporter

**Q2. Where the rule labels come from**
1. Read `ruleSelector`/`ruleNamespaceSelector` from the Prometheus object on mgmt-01 and use exactly those labels; stop if `ntnx-system` is not selected (Recommended)
2. You give me the labels now

There is no third sensible option: the asset's own labels (`prometheus: k8s`, `role: alert-rules`) are the upstream ones, not NKP ones. [live 2.19.0 asset]

### Plan

1. License check on mgmt-01 must show `Pro` or `Ultimate` (NDK and the monitoring stack are both Pro+). [live 2.19.0]
2. Verify the asset copy of `assets/ndk-alert-config.yaml` (skill `nkp-airgap`) with its body SHA-256. The upstream guide file is not valid YAML; the asset is the fixed copy. Do not copy it anywhere else.
3. Read the Prometheus selectors (M0). The rules need the `ruleSelector` labels and a namespace that `ruleNamespaceSelector` selects.
4. Make a copy of the asset with the NKP rule label, in `$HOME`. Nothing is applied yet.
5. Server dry run, plan, `yes`, apply. Then check in the Prometheus UI / `get prometheusrules`.
6. Tell you the exporter gap in writing, and give you the READ-ONLY check that proves it.

Effect: one `PrometheusRule` `ndk-event-rules` (or the name I copy from the asset) in `ntnx-system` on mgmt-01, with 12 rules (snapshot, replication, retention, remote cluster, Prism Central authentication). No Secret is read, no other object changes.

### Step 1: license and NDK state on mgmt-01 (READ-ONLY)

For mgmt-01, `WORKSPACE_NS` is `kommander`.

```bash
# READ-ONLY
source ~/nkp-mgmt-01.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n kommander get licenses.kommander.mesosphere.io -o jsonpath='{.items[*].status.dkpLevel}{"\n"}'
kubectl --kubeconfig "$MGMT_KUBECONFIG" get helmreleases -A | grep -E 'NAME|kube-prometheus-stack|ndk'
kubectl --kubeconfig "$MGMT_KUBECONFIG" get pods -A | grep -i event
```

The last line is UNKNOWN (D-54): an event exporter that gives `kube_event_unique_events_total` on NKP 2.19. It is not in the bundle and is not a ClusterApp. If it prints nothing, the rules will not fire.

### Step 2: check the asset (READ-ONLY)

`dir` is the absolute path of the `nkp-airgap` skill folder — the only allowed edit of this block.

```bash
# READ-ONLY
dir=''; : "${dir:?}"
for f in "$dir"/assets/*.yaml; do want="$(sed -n 's/^# Body SHA-256: //p' "$f")"; got="$(grep -v '^# ' "$f" | sha256sum | cut -d' ' -f1)"; [ "$want" = "$got" ] && echo "OK $f" || echo "FAILED $f"; done
```

Every line must start with `OK`. `FAILED` = stop, the file copy is damaged; I do not apply it.

### Step 3: M0 selectors on mgmt-01 (READ-ONLY)

```bash
# READ-ONLY
source ~/nkp-mgmt-01.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get helmreleases -A | grep -E 'NAMESPACE|kube-prometheus-stack'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get prometheuses -A -o jsonpath='{range .items[*]}{.metadata.namespace}/{.metadata.name}{"\n"}  serviceMonitorSelector={.spec.serviceMonitorSelector}{"\n"}  serviceMonitorNamespaceSelector={.spec.serviceMonitorNamespaceSelector}{"\n"}  ruleSelector={.spec.ruleSelector}{"\n"}  ruleNamespaceSelector={.spec.ruleNamespaceSelector}{"\n"}  retention={.spec.retention}{"\n"}{end}'
```

The stack namespace is `kommander` on the management cluster. I take one key/value from `ruleSelector` as `lkey`/`lval`, and I check that `ruleNamespaceSelector` covers `ntnx-system`. If it does not, I stop and tell you: I do not move the rules into another namespace to force them in.

### Step 4: make the labeled copy (CHANGES, operator host only)

```bash
# CHANGES  (writes a copy of the NDK alert rules with the NKP rule label on the operator host; changes no cluster)
source ~/nkp-mgmt-01.env 2>/dev/null
dir=''; lkey=''; lval=''
: "${dir:?}" "${lkey:?}" "${lval:?}"
f="$HOME/$CLUSTER_NAME-ndk-alert-config.yaml"
awk -v k="$lkey" -v v="$lval" '{print} /^  labels:$/ && !d {print "    " k ": \"" v "\""; d=1}' "$dir/assets/ndk-alert-config.yaml" > "$f" && grep -v '^# ' "$f" | head -10
```

(`$CLUSTER_NAME` is `mgmt-01` in `~/nkp-mgmt-01.env`, so the file is `~/mgmt-01-ndk-alert-config.yaml`.)

### Step 5: dry run, plan, `yes`, apply

```bash
# READ-ONLY  (server dry run: changes nothing)
source ~/nkp-mgmt-01.env 2>/dev/null
f="$HOME/$CLUSTER_NAME-ndk-alert-config.yaml"; : "${f:?}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" apply --dry-run=server -f "$f"
```

Plan: cluster **mgmt-01**, namespace `ntnx-system`, object `PrometheusRule` from the asset with the NKP `ruleSelector` label added. Result: the Prometheus of mgmt-01 loads the group `ndk-snapshot-failure-rules` and 11 sibling rules; they evaluate and alert **only if** the event exporter metric exists.

```bash
# CHANGES  (creates or updates the NDK PrometheusRule on mgmt-01)
source ~/nkp-mgmt-01.env 2>/dev/null
f="$HOME/$CLUSTER_NAME-ndk-alert-config.yaml"; : "${f:?}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" apply -f "$f"
```

### Step 6: check (READ-ONLY)

```bash
# READ-ONLY
source ~/nkp-mgmt-01.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n ntnx-system get prometheusrules
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n ntnx-system get prometheusrule ndk-event-rules -o jsonpath='{.metadata.labels}{"\n"}'
```

Done when the Prometheus UI lists the group `ndk-snapshot-failure-rules` (skill `nkp-observability` step 2 for the UI path). A rule with a PromQL error does not load: read the `prometheus` container log.

If you also want the NDK controller metrics scraped, that is a different step: `metrics=true` in the NDK override adds a ServiceMonitor (nkp-ndk SKILL.md step 3), and the management cluster's `kube-prometheus-stack` must keep its own NKP ServiceMonitor list (monitoring.md, D-30). I did not add that here because you asked for the alerts.

---

## nkp-ndk K6

> how many NDK protected applications and replication targets can one NKP cluster have? and which k8s versions does NDK 2.3 support?

### Skill files read

- `skills/nkp/SKILL.md`
- `skills/_shared/RULES.md`
- `skills/nkp-ndk/SKILL.md` (catalog app table: versions and scope)
- `skills/nkp-ndk/references/replication.md` (R0, R5: the limits that **are** documented)
- `skills/nkp-ndk/references/protect.md` (P2, P5: snapshot and retention limits)
- `skills/nkp-platform-apps-gitops/references/catalogs.md` (K3: the `k8sVersionSupport` field of an app)

### The honest answer first

- **The maximum number of protected applications and the maximum number of replication targets per cluster are not in the skills.** I will not invent a number. Those figures are in the NDK product documentation and the NDK sizing/limits matrix on the Nutanix portal, which I cannot reach from this dark site. Rule 6: "not in the skills" plus a READ-ONLY check.
- **The Kubernetes versions that NDK 2.3 supports are not in the skills as a list.** What the skills do say: NDK catalog app `ndk` 2.3.0 is the only NDK version in the 2.19.0 bundle, and its NKP constraint is `>=2.18.0 <2.20.0`; NKP 2.19.0 runs Kubernetes v1.36.2. [live 2.19.0] The app's own `k8sVersionSupport` field is the authority (guide, pdf p.358), and the NDK 2.3 release notes are on the portal.
- Nutanix infrastructure only: NDK is not available on other providers, and not on Starter. [pdf p.337][live 2.19.0]

### Limits that **are** in the skills (so the answer is useful)

| Limit | Value | Source |
|---|---|---|
| Copies kept on the replication cluster | at most **15** | [portal] |
| `retentionCount` in a `ProtectionPlan` | 1-15 | [portal] |
| Snapshot `expiresAfter` (hand-made snapshot; immutable) | maximum `1440h` (60 days) | [portal] |
| Application config (objects, not volume data) | must be ≤ **8 MB**, else the snapshot fails | [portal] |
| Async schedule | `interval.minutes`, or daily/weekly/monthly/cron | [live 2.19.0 CRD][portal] |
| NearSync `rpo` | `10m` to `15m` | [portal] |
| Async targets | one or more (Nutanix Files: one) | [portal] |
| Sync / NearSync targets | one | [portal] |
| Plan mix on one app | async + NearSync not allowed; two plan types to the same target not allowed; one sync plan per app; 3DC (sync to site 2 + async/NearSync to site 3) is allowed | [portal] |
| One NDK instance | one per cluster; each cluster has its own install | [pdf p.340] |
| NDK UI | needs CSI 3.8 or later | [pdf p.338] |

### One question I ask before the checks

**Q1. Which cluster should I read the installed NDK version and the catalog constraint from?**
1. Give me a cluster name (Recommended)
2. None — the written facts above are enough

### READ-ONLY checks for the two open facts

Installed NDK version and cluster Kubernetes version (replace the env file with the cluster you name):

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
nkp version
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" version
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n ntnx-system get deploy ndk-controller-manager -o jsonpath='{range .spec.template.spec.containers[*]}{.name}{"\t"}{.image}{"\n"}{end}'
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get apps -o custom-columns='NAME:.metadata.name,APP-ID:.spec.appId,VERSION:.spec.version'
```

The `k8sVersionSupport` field of the app (guide, pdf p.358). On the cluster this may print nothing, because the field lives in the app metadata of the catalog artifact, not in the `App` spec:

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get apps -A -o yaml | grep -i -A2 'k8sVersionSupport'
```

The current object counts, so you can see how much headroom you are using against the (documented elsewhere) limits:

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get applications.dataservices.nutanix.com -A --no-headers | wc -l
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get replicationtargets -A --no-headers | wc -l
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get remotes --no-headers | wc -l
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get storageclusters --no-headers | wc -l
```

For the two platform limits, the authoritative source is the NDK 2.3 documentation on the Nutanix portal (the same login you used for the NDK bundle and the KB-16326 support script). Tell me the section heading you were given and I will write the numbers into the site notes, so the answer is on the operator host next time.

---

## nkp-ndk K7

> enabled NDK on cluster lab-02 with this override: tls.server.enable true, mode SECRET, secretName ndk-tls, clusterName lab-02.example.com. helmrelease ndk not ready. what now?

### Skill files read

- `skills/nkp/SKILL.md`
- `skills/_shared/RULES.md`
- `skills/nkp-ndk/SKILL.md` (step 3 TLS table; "Common failures" table)
- `skills/nkp-ndk/references/operations.md` (X2 read settings, X5)
- `skills/nkp-troubleshooting/references/flux.md` (F1, F2, F3: read the message, find the owner)
- `skills/nkp-platform-apps-gitops/SKILL.md` (step 3: reset a stuck HelmRelease)
- `skills/nkp-platform-apps-gitops/references/overrides.md` (O1, O2, O5: read the override, fix it, reset)

### The likely cause (stated before any change)

`mode: SECRET` with `clusterName` set is a known chart failure: **`For NDK installation in mode 'SECRET', clusterName cannot be provided`**. [live 2.19.0] In `SECRET` mode the chart uses the certificate SAN and refuses a `clusterName`. The guide example sets `enable`, `mode`, `secretName` **and** `clusterName` [pdf p.341] — that is exactly the combination you copied, and it cannot work.

Two other causes are also possible and are checked first, because a fix without the message is a guess:
- the TLS Secret `ndk-tls` does not exist in `ntnx-system` on lab-02 → `Secret 'ndk-tls' not found in namespace 'ntnx-system'`;
- `enable`/`mode`/`secretName` at the wrong level in the file, or a schema error → a `values`/`schema`/`cannot unmarshal` message (owner: overrides.md O5).

Also: a **workspace** override gives the same values to every cluster of the workspace. If this AppDeployment is a workspace override, the fix reaches all of them (fine here, since `clusterName` must go away anyway). If you meant a per-cluster value, that is a cluster override, which is Ultimate only.

### Questions I ask first

**Q1. Is `ndk` enabled for lab-02 only, or for the whole workspace?**
1. Only lab-02 (`spec.clusterSelector` / a cluster override)
2. The whole workspace — the same values on every cluster
3. Not sure — read the AppDeployment

**Q2. Who owns the certificate in `ndk-tls`?**
1. We made it from our CA and it carries the DNS name I will type (Recommended)
2. cert-manager made it and I do not know the SAN
3. There is no `ndk-tls` Secret yet

### Step 1: read the message (READ-ONLY)

```bash
# READ-ONLY
source ~/nkp-lab-02.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get helmreleases -A -o custom-columns='NAMESPACE:.metadata.namespace,NAME:.metadata.name,READY:.status.conditions[?(@.type=="Ready")].status,REASON:.status.conditions[?(@.type=="Ready")].reason,SUSPEND:.spec.suspend' | grep -v -w True
kind='helmrelease'; name='ndk'; ns=''; where='cluster'; case "$where" in mgmt) kc="$MGMT_KUBECONFIG";; cluster) kc="$CLUSTER_KUBECONFIG";; *) kc='';; esac
: "${kind:?}" "${name:?}" "${ns:?}" "${kc:?}"
kubectl --kubeconfig "$kc" -n "$ns" get "$kind" "$name" -o jsonpath='{range .status.conditions[*]}{.type}={.status} {.reason}: {.message}{"\n"}{end}{.status.history[0].status}{"\n"}'
kubectl --kubeconfig "$kc" -n "$ns" get events --field-selector "involvedObject.name=$name" --sort-by=.lastTimestamp | tail -10
```

`ns` is `kommander` on the management cluster, or the workspace namespace on a workload cluster — O2 gives it. `SUSPEND true` means a person suspended it: I ask why before anything else.

If the message is `exhausted` / `another rollback/release in progress` / `upgrade retries exhausted`, the Helm release is stuck, and the fix has two parts: correct the values (step 3), then reset the release (step 4). A reset without the fix fails again.

### Step 2: read the override and the Secret (READ-ONLY)

```bash
# READ-ONLY
source ~/nkp-lab-02.env 2>/dev/null
: "${APP_ID:?}"
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get appdeployment "$APP_ID" -o jsonpath='app={.spec.appRef.name}{"\n"}workspace-override={.spec.configOverrides.name}{"\n"}{range .spec.clusterConfigOverrides[*]}cluster-override={.configMapName} for {.clusterSelector}{"\n"}{end}'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get helmreleases -A -o custom-columns='NS:.metadata.namespace,NAME:.metadata.name,FROM:.spec.valuesFrom[*].name' | grep -E "NS|$APP_ID"
```

Then the override body with the O2 `awk` mask — the block is long, so I keep it as the skill has it: it prints `[hidden]` for keys that end in `secret`, `password`, `token`, `key`, `hash`, `pw`, `credentials` and for the lines below them. **The `awk` is never removed.**

```bash
# READ-ONLY
source ~/nkp-lab-02.env 2>/dev/null
ns=''; cm=''; : "${ns:?}" "${cm:?}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" get configmap "$cm" -o jsonpath='{.data.values\.yaml}' | awk 'BEGIN { hi = -1 }
/^[[:space:]]*$/ { if (hi == -1) print; next }
{ ind = match($0, /[^ -]/) - 1 }
hi != -1 && hi < ind { next }
{ hi = -1; l = tolower($0) }
l ~ /[{,].*(secret|password|token|key|hash)/ { print "[hidden line]"; next }
match(l, /^[ -]*[a-z0-9_.-]+:/) && substr(l, 1, RLENGTH - 1) ~ /(secret|password|passwd|token|key|keyid|hash|pw|credentials?)$/ { print substr($0, 1, RLENGTH) " [hidden]"; hi = ind; next }
{ print }'
```

And the Secret exists and is a TLS Secret (READ-ONLY, no data printed):

```bash
# READ-ONLY
source ~/nkp-lab-02.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n ntnx-system get secret ndk-tls -o jsonpath='{.type}{"\t"}{range $k,$v := .data}{$k}{" "}{end}{"\n"}'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n ntnx-system get certificates,issuers
```

Expected: `kubernetes.io/tls` and the keys `tls.crt tls.key`. The certificate SAN is read by you, not by me printing the Secret: `kubectl -n ntnx-system get secret ndk-tls -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -noout -subject -ext subjectAltName` is a **USER-TERMINAL** command (it shows certificate content).

### Step 3: fix the values file (CHANGES, operator host only)

The corrected file for `SECRET` mode: `enable`, `mode`, `secretName` — **no `clusterName`**.

```bash
# CHANGES  (writes the corrected NDK values file on the operator host; changes no cluster)
source ~/nkp-lab-02.env 2>/dev/null
mode='SECRET'; secret='ndk-tls'; mtls=''; metrics=''
: "${secret:?}"
f="$HOME/$CLUSTER_NAME-ndk-values.yaml"
{ printf 'tls:\n  server:\n    enable: true\n    mode: %s\n' "$mode"
  printf '    secretName: %s\n' "$secret"
  if [ "$mtls" = true ]; then printf '    enableMTLS: true\n'; fi
  if [ "$metrics" = true ]; then printf 'prometheus:\n  enable: true\nserviceMonitor:\n  customLabels:\n    prometheus.kommander.d2iq.io/select: "true"\n'; fi
} > "$f" && cat "$f"
```

Keep every other value that the old override had — the apply replaces the whole ConfigMap. If the old file also had a `config.secret` key, remove it: with the catalog default (`nutanix-csi-credentials`) it works, but a `config.secret` that names a Secret which is not there gives `Secret '...' not found in namespace 'ntnx-system'`.

YAML check (READ-ONLY; `apiVersion not set, kind not set` = good):

```bash
# READ-ONLY
source ~/nkp-lab-02.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" create --dry-run=client -f "$HOME/$CLUSTER_NAME-ndk-values.yaml" 2>&1 | head -3
```

### Step 4: re-apply the override, then reset the release (CHANGES)

Plan: replace the override ConfigMap on the management cluster in the workspace namespace (`$APP_ID-overrides` or the existing name from O2; **not** `ndk-overrides` for a new one), then suspend and resume the `ndk` HelmRelease on lab-02 so helm-controller starts a new reconcile. Result: the HelmRelease goes back to `Ready` after a new release number.

```bash
# CHANGES  (replaces the override ConfigMap and resets the ndk HelmRelease)
source ~/nkp-lab-02.env 2>/dev/null
cm=''; hr='ndk'; ns=''; : "${cm:?}" "${hr:?}" "${ns:?}" "${APP_ID:?}"
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" create configmap "$cm" --from-file=values.yaml="$HOME/$CLUSTER_NAME-ndk-values.yaml" --dry-run=client -o yaml | kubectl --kubeconfig "$MGMT_KUBECONFIG" apply -f -
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" patch helmrelease "$hr" --type=json -p='[{"op":"replace","path":"/spec/suspend","value":true}]'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" patch helmrelease "$hr" --type=json -p='[{"op":"replace","path":"/spec/suspend","value":false}]'
```

If `ndk` was never created through an AppDeployment (a hand-made HelmRelease), the ConfigMap patch is the wrong lever: then the HelmRelease itself carries the values, and the edit is on `$CLUSTER_KUBECONFIG -n $ns edit helmrelease ndk` (CHANGES) — I ask before that, because NKP re-applies its own Flavours/objects and a hand edit can disappear.

### Step 5: check (READ-ONLY, every minute up to 10 minutes)

```bash
# READ-ONLY
source ~/nkp-lab-02.env 2>/dev/null
ns=''; hr='ndk'; : "${ns:?}" "${hr:?}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" get helmrelease "$hr" -o jsonpath='suspend={.spec.suspend}{"\n"}{range .status.conditions[*]}{.type}={.status} {.reason}: {.message}{"\n"}{end}'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n ntnx-system get deploy,svc | grep -E 'NAME|ndk'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n ntnx-system get configmap ndk-manager-config -o yaml | grep -E 'enableTLS|enableMTLS|clusterName|secretName|port:'
```

Done when READY `True`, `ndk-controller-manager` `1/1` (4 containers), `ndk-intercom-service` has an `EXTERNAL-IP`, and `ndk-manager-config` shows `enableTLS: true` with `secretName: ndk-tls` and **no** `clusterName`.

Same message again after the fix: stop and go back to step 1 — do not loop the reset (flux.md F3, overrides.md O5). If instead it now says the certificate or the SAN is wrong, that is the peer/trust side: replication.md R1-R2 and operations.md X5.

### One consequence you should know

With `SECRET` mode there is no `clusterName` in NDK, so a peer cluster pairs on the certificate SAN instead. Whatever DNS name is in the `ndk-tls` certificate is what the other cluster's `Remote.spec.clusterName` must equal. If lab-02 will be a replication site, that name has to be settled now; a re-issued certificate later means the peer `Remote` changes too. The name `lab-02.example.com` that you put in the override is still usable — as the certificate SAN, not as a chart value.
