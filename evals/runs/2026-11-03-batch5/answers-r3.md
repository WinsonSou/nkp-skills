# Batch 5 re-run answers (r3)

## nkp-ndk K1

**Answer from the agent, first reply.**

### Skill files I read for this reply

| File | Why |
|---|---|
| `skills/nkp/SKILL.md` | Router: names, layers, license tiers, env variables, the rules pointer. |
| `skills/_shared/RULES.md` | Master copy of the rules block (marks, approval, env files, values, secrets, unknowns). |
| `skills/nkp-ndk/SKILL.md` | The job: parts, step 1 state, step 2 prerequisites, step 3 install, step 4 `StorageCluster`, step 5 write/dry run/apply, common failures. |
| `skills/nkp-ndk/references/operations.md` | NDK settings, UI values, alerts, support logs (X1-X3). |
| `skills/nkp-platform-apps-gitops/SKILL.md` | Step 2 (enable an app: `nkp create appdeployment`), step 1 (read the apps), step 4 (`KommanderCluster` joined). |
| `skills/nkp-platform-apps-gitops/references/overrides.md` | O1-O6: how the values merge, the ConfigMap name, the workspace override, the cluster override. |
| `skills/nkp-airgap/SKILL.md` | Step 3 (registry mode), step 4A (extra bundle push), step 5 (node registry check). |
| `skills/nkp-airgap/references/catalogs.md` | C1: the catalog bundle in the 2.19.0 bundle, the catalog repositories, `nkp create catalog-app`. |
| `skills/nkp-airgap/references/prestage.md` | P6, P7: the NDK files that the bundle does not have (`ndkcli`, recipes, alert rules). |
| `skills/nkp-storage-backup/SKILL.md` | Step 1: the Nutanix CSI version and the default StorageClass (NDK needs CSI 3.7.1 or later). |
| `skills/nkp-networking/references/metallb.md` | M1: a free MetalLB IP for `ndk-intercom-service`. |

One skill answered the job: `nkp-ndk`. The others are its pointers.

### What your message gives me, and what is still open

| Fact | Value | Source |
|---|---|---|
| License tier | Ultimate. NDK needs Pro or Ultimate. I verify it in block B. | you, to confirm |
| Site | Dark site. The Harbor mirror has the 2.19.0 bundle. Air-gapped install. No Docker Hub token. No pull Secret for the images. | you |
| Cluster | `prod-01`, workload cluster, on AHV. Nutanix infrastructure only: NDK fits. | you |
| Workspace | Name `prod`. I read its namespace. A workspace name and its namespace are not the same. | you |
| NKP version | 2.19.0. NDK 2.3.0 is the only NDK version in that bundle, and it supports NKP `>=2.18.0 <2.20.0`. | bundle |
| Production | TLS is on. The default (no TLS) is for a test only. You have a CA. | you |
| TLS mode | **open**: `ISSUER` (your CA as a cert-manager Issuer in `ntnx-system`) or `SECRET` (a TLS Secret that you make in `ntnx-system`). I propose no value. | question 1 |
| Replication | **open**: this cluster alone, or a pair. This changes mTLS and the install order. | question 2 |
| Target scope | **open**: `prod-01` only, or every cluster in workspace `prod`. | question 3 |
| Cluster access | **open**: `CLUSTER_KUBECONFIG` and the workspace namespace. | question 4 |

### Questions I ask first (one `ask_user_question` call)

```text
ask_user_question({
  questions: [
    {
      header: "TLS mode",
      question: "NDK intercom TLS on prod-01: which mode? The catalog default is no TLS, and that is for a test only.",
      options: [
        "SECRET (Recommended) - you make a TLS Secret in ntnx-system from the certificate that your CA signs. No clusterName value. One Secret on the cluster, so the workspace scope cannot give a wrong name to another cluster.",
        "ISSUER - you put an Issuer in ntnx-system from your CA, and NDK asks cert-manager for the certificate. Needs clusterName = the DNS name in the certificate.",
        "SELF_SIGNED - cert-manager makes its own certificate. Not for production.",
        "I do not know yet - show me the two files I must have first, then I decide."
      ]
    },
    {
      header: "Replication",
      question: "Do you plan NDK replication from prod-01 to a second site or cluster?",
      options: [
        "No - prod-01 only for now (Recommended)",
        "Yes - a pair is planned. Add mTLS (enableMTLS: true), and one CA signs both clusters.",
        "Yes - already planned for later. Install without mTLS now, add it at the pair step."
      ]
    },
    {
      header: "Target scope",
      question: "Workspace prod may hold more than one cluster. Which clusters get NDK? (--clusters is Ultimate only, so both answers are possible.)",
      options: [
        "prod-01 only (Recommended) - use --clusters prod-01.",
        "Every cluster in workspace prod - no --clusters flag.",
        "I tell you after block B shows the clusters of the workspace."
      ]
    },
    {
      header: "Cluster access",
      question: "How do I reach prod-01? Blocks that use CLUSTER_KUBECONFIG read ~/nkp-prod-01.env.",
      options: [
        "I give you the kubeconfig path and the workspace namespace now - you write ~/nkp-prod-01.env after I confirm (Recommended)",
        "~/nkp-prod-01.env exists already with CLUSTER_NAME, WORKSPACE_NS, CLUSTER_KUBECONFIG",
        "The kubeconfig is not on this host yet - tell me what to copy"
      ]
    }
  ]
})
```

Second round, after these answers: the `StorageCluster` name and the two UUIDs (step 4), the NDK UI (on or off), the NDK metrics (`metrics=true` or not).

### Values I must get from you (no options, no guesses)

| Ask | Why | Where it goes |
|---|---|---|
| AOS and Prism Central version (7.5 or later; 7.5.1 for NearSync and multi-namespace apps) | NDK prerequisite. Only you can read it in Prism. | your answer |
| Is the Prism Central user of the CSI credentials a Prism admin? | NDK uses the CSI Secret `nutanix-csi-credentials`. | your answer |
| An iSCSI Data Services virtual IP on each Prism Element cluster, and the PC VIP on a scale-out PC | NDK prerequisite. I do not ask you to paste the IP in the chat; put it in Prism, and confirm. | your answer |
| `clusterName` (only if you choose `ISSUER` or `SELF_SIGNED`) | Must be the DNS name in the certificate, and different on each paired cluster. I do not propose a name. | NDK values file |
| The TLS Secret name (only if you choose `SECRET`) | A TLS Secret in `ntnx-system` that you make. The chart fails if `clusterName` is also set. I do not propose a name. | NDK values file |
| `StorageCluster` name, Prism Element UUID, Prism Central UUID | Step 4. Lowercase name. UUIDs from `ncli cluster info`. | `StorageCluster` file |

Do not put a secret in this chat. You type the secret lines into `~/nkp-site.env` with an editor (rule 5). An air-gapped site needs no `NDK_PULL_USERNAME` / `NDK_PULL_TOKEN` and no image pull Secret.

### Blocks I show now

All are READ-ONLY, or USER-TERMINAL for the node check. They use no value that I do not have. Nothing changes.

**A. Which site values exist.** Prints `set` or `MISSING`. Never prints a value.

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
for v in MGMT_KUBECONFIG BUNDLE_DIR REGISTRY_URL REGISTRY_CA_FILE; do if [ -n "$(printenv "$v")" ]; then echo "set: $v"; else echo "MISSING: $v"; fi; done
for v in REGISTRY_MIRROR_USERNAME REGISTRY_MIRROR_PASSWORD; do printenv "$v" >/dev/null && echo "set: $v" || echo "MISSING: $v"; done
```

If `~/nkp-site.env` does not exist, tell me. I show the `touch` block (CHANGES, mode 600) after your yes.

**B. License, workspace namespace, clusters, catalog app, NDK state on the management cluster.** The management cluster is enough for these. No cluster file yet.

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n kommander get licenses.kommander.mesosphere.io -o jsonpath='{.items[*].status.dkpLevel}{"\n"}'
kubectl --kubeconfig "$MGMT_KUBECONFIG" get workspaces -o custom-columns='NAME:.metadata.name,NS:.status.namespaceRef.name'
kubectl --kubeconfig "$MGMT_KUBECONFIG" get kommanderclusters -A
kubectl --kubeconfig "$MGMT_KUBECONFIG" get apps -A | grep -E 'NAME|ndk'
kubectl --kubeconfig "$MGMT_KUBECONFIG" get clusterapps | grep -E 'NAME|ndk'
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n kommander get ocirepositories
```

How I read it:
- Line 1 is the tier. `Starter`: NDK is not available. Stop.
- Line 2 gives the namespace of workspace `prod`. I ask you to confirm it before I write it as `WORKSPACE_NS`.
- Line 4: an `ndk` App line means the product catalog is in the workspace (step 1 of `nkp-ndk`). No line: the catalog is missing, and I do the catalog gate.
- Line 6 answers UNKNOWN (D-51) for this site: is the product catalog there already?

**C. Is the NDK catalog artifact in the Harbor mirror?** Prints only the HTTP code. `200` it is there · `404` not pushed, or the push changed the path (A-07) · `401` wrong pull account · `000` no connection or a CA error.

```bash
# READ-ONLY  (HEAD request for the NDK catalog artifact with the pull account on stdin; prints only the HTTP code)
source ~/nkp-site.env 2>/dev/null
h="${REGISTRY_URL#*://}"; : "${h:?REGISTRY_URL is empty}"; p=''; case "$h" in */*) p="${h#*/}/" ;; esac
u=$(printenv REGISTRY_MIRROR_USERNAME); w=$(printenv REGISTRY_MIRROR_PASSWORD); w=${w//\\/\\\\}; w=${w//\"/\\\"}; { [ -n "$u" ] && printf 'user = "%s:%s"\n' "$u" "$w"; } | curl -K - -s -I -o /dev/null -w '%{http_code}\n' --cacert "$REGISTRY_CA_FILE" -H 'Accept: application/vnd.oci.image.index.v1+json, application/vnd.oci.image.manifest.v1+json' "https://${h%%/*}/v2/${p}nutanix-cloud-native/nkp-nutanix-product-catalog/collection/manifests/2.19"
```

**D. The catalog repositories in the 2.19.0 bundle.** Sets `repo` and `tag` for the catalog create from a real line. Skip it if the bundle tar is not on this host; then I use block C only.

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
for b in "$BUNDLE_DIR"/container-images/*catalog*.tar; do echo "== $b"; tar -tf "$b" | sed -n 's#^docker/registry/v2/repositories/\(.*-catalog/[^/]*\)/_manifests/tags/\([^/]*\)/current/link$#\1:\2#p' | sort -u; done
```

**E. Node package check.** On each worker node of `prod-01`, in your own terminal. I do not run it.

```bash
# USER-TERMINAL  (on each worker node of prod-01, over SSH)
rpm -q iscsi-initiator-utils
```

Not in the skills: the package check for Ubuntu nodes, and the NDK scale limits (open item D-03, no check command).

### Blocks I hold until the answers arrive

These use `$CLUSTER_KUBECONFIG` and `$WORKSPACE_NS` from `~/nkp-prod-01.env`, and that file does not exist yet. I show each one with its plan, and I run it only after your "yes" to that plan.

```text
Gate list for prod-01 (each gate stops for "yes"):

G1  CHANGES  operator host  create ~/nkp-prod-01.env (mode 600, first line sources ~/nkp-site.env)
             with CLUSTER_NAME=prod-01, WORKSPACE_NS (the namespace from block B), CLUSTER_KUBECONFIG (from Q4)
G2  READ-ONLY                 full state block of nkp-ndk step 1 on prod-01: tier, ndk App, CSI labels,
                              referencegrants CRD, dataservices CRDs, helmreleases, ntnx-system deploy+svc,
                              storageclusters, remotes, applications
G3  READ-ONLY                 MetalLB: free IP for ndk-intercom-service (metallb.md M1)
G4  CHANGES  management       catalog only when block B/C/D show it is missing: push the catalog bundle
             (extra bundle, airgap step 4A) and nkp create catalog-app in workspace kommander-workspace
G5  CHANGES  operator host    write ~/prod-01-ndk-values.yaml (TLS mode from Q1, mTLS from Q2, metrics if you ask)
G6  READ-ONLY                 YAML syntax check of the values file
G7  CHANGES  management       values ConfigMap ndk-overrides-ws in the workspace namespace + AppDeployment
                              "ndk" with --clusters prod-01 (Q3) and --config-overrides ndk-overrides-ws
G8  READ-ONLY                 HelmRelease ndk READY True, ndk-controller-manager 1/1,
                              ndk-intercom-service EXTERNAL-IP, then the TLS settings in ndk-manager-config
G9  CHANGES  prod-01          StorageCluster file (name, PE UUID, PC UUID), dry run, apply
```

Why `ndk-overrides-ws` and not `ndk-overrides`: the HelmRelease reads a ConfigMap named `ndk-overrides` by its own name. On the management cluster the workspace namespace and the HelmRelease namespace can be the same one, so that name would fill two value slots, and a later removal would not remove it. `overrides.md` O1 gives this rule.

The catalog create (G4), for when it is needed. Your Harbor mirror is the site registry, so the push keeps the repository path under `REGISTRY_URL`. `repo` and `tag` come from block D, or from the 2.19.0 bundle facts.

```bash
# CHANGES  (creates an OCIRepository catalog in the kommander-workspace; it goes to all workspaces)
source ~/nkp-site.env 2>/dev/null
repo='nutanix-cloud-native/nkp-nutanix-product-catalog/collection'; tag='2.19'; : "${REGISTRY_URL:?REGISTRY_URL is empty, see A-07}"
nkp create catalog-app --url "oci://${REGISTRY_URL#*://}/$repo" --tag "$tag" --workspace kommander-workspace --kubeconfig "$MGMT_KUBECONFIG"
```

The values file (G5), exact text. The values stay empty, with their `:?` guards, until you give them. Nothing here is a proposal.

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

The `StorageCluster` file (G9), exact text. The three values stay empty until you give them.

```bash
# CHANGES  (writes the StorageCluster file on the operator host; changes no cluster)
source ~/nkp-prod-01.env 2>/dev/null
name=''; pe_uuid=''; pc_uuid=''
: "${name:?}" "${pe_uuid:?}" "${pc_uuid:?}"
f="$HOME/$CLUSTER_NAME-ndk-storagecluster.yaml"
printf 'apiVersion: dataservices.nutanix.com/v1alpha1\nkind: StorageCluster\nmetadata:\n  name: %s\nspec:\n  storageServerUuid: %s\n  managementServerUuid: %s\n' "$name" "$pe_uuid" "$pc_uuid" > "$f" && cat "$f"
```

And the two UUIDs, from your own terminal:

```bash
# USER-TERMINAL  (once on a CVM of the Prism Element cluster, once on the Prism Central VM, over SSH)
ncli cluster info | grep -i 'cluster uuid'
```

### Plan for `prod-01`, in order

1. Block A, B, C, D (read-only) and block E (your terminal).
2. You answer the four questions and the value asks.
3. G1: I write `~/nkp-prod-01.env` after you confirm its three lines.
4. G2: full state of `prod-01`. NDK needs: tier Pro or Ultimate, CSI 3.7.1 or later (3.8 for the NDK UI), a default StorageClass, `referencegrants` CRD (it is there on 2.19.0), and one free MetalLB IP.
5. G4 only if the catalog is missing. Otherwise the `ndk` App from block B goes straight to G7.
6. G5, G6, G7, G8. Then G9, dry run first, then apply.
7. Then the `StorageCluster` reads AVAILABLE `true`, and NDK is installed. No `ndkcli`, no recipes, and no alert rules: those are not in the 2.19.0 bundle (P6, P7). Ask me for them when you plan replication or alerts.

### Risks I tell you now

- **Air gap and the pull Secret.** The Deployment always names `ndk-image-pull-secret`, and an air-gapped site makes none. UNKNOWN (D-50) in the skill. If the pods show `ImagePullBackOff`, we read the events: `kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n ntnx-system get events --field-selector reason=Failed`. The check comes after G1.
- **A workspace override goes to every cluster of the workspace.** If workspace `prod` holds more than one cluster and we use `ISSUER`, all of them get the same `clusterName`. That is why I recommend `SECRET` here, or `--clusters prod-01`.
- **NDK alert rules never fire on 2.19.0.** No event exporter app (D-54). Do not plan around them.
- **`ndk-intercom-service` needs a free MetalLB IP.** `<pending>` blocks every `Remote`.
- **immutable fields.** The `StorageCluster` spec, the protection objects, `rpo`, and `expiresAfter` cannot change after the create. We get the UUIDs and the name right before the apply.
- **iSCSI.** Without the Prism Element iSCSI Data Services VIP and `iscsi-initiator-utils` on each worker, the first snapshot fails, not the install.

Nothing was run. No cluster, registry, or file was changed.
