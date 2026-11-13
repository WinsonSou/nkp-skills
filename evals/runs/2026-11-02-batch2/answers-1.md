# Batch 2 answers (part 1)

Conventions in every section below:

- The operator login shell is zsh. Every block is a bash block: type `bash` first, then paste. Do not paste them into zsh.
- Line 1 of each block is the mark: `# READ-ONLY`, `# CHANGES`, or `# USER-TERMINAL`.
- A `# CHANGES` block is a plan. I show the command, the target, and the result, then I stop. I run it only after you type `yes`.
- Tags: `[live 2.19.0]`, `[pdf p.N]`, `[portal]`, `[field]`.

---

## nkp-upgrade U1

Skill files read: `skills/_shared/RULES.md`, `skills/nkp/SKILL.md`, `skills/nkp-upgrade/SKILL.md`, `skills/nkp-upgrade/references/clusterclass.md`, `skills/nkp-upgrade/references/non-clusterclass.md`, `skills/nkp-upgrade/references/stopped.md`

### What the skills say for your site

- **Path.** 2.18.0 → 2.19.0 is the correct and only allowed step. The only source version for 2.19.0 is 2.18.0. You can skip patch versions, not minor versions. [pdf p.1011-1012]
- **Order.** Kommander → management cluster → each workload cluster, one cluster at a time. [pdf p.1017-1022]
- **Cost.** Every node is replaced. The control plane rolls first, then the pools. There is no rollback and no automatic repair on error. [pdf p.1043-1044]
- **Connected site, no mirror** → gate **G2 (Docker Hub credentials)** applies to the management cluster and to both workload clusters. [pdf p.1017]
- **AHV clusters that came from 2.18** → gate **G3 (one Prism Central project for the control plane and all pools)**. [pdf p.1015]
- **All sites** → **G5 (catalogs are OCI only)**; **G6** if AI Navigator or NKP Insights run anywhere; **G7** the OS image; **G8** the Prism Central role has the old and the new permissions; **G9** one free VM slot and one free IP per pool. [pdf p.1009-1018]
- **To tell you now:** during the Kommander upgrade the NKP UI and the APIs can be unavailable, and a custom domain can stop for some minutes. [pdf p.1018]

### Questions I need answered before step 2

1. The exact names of the management cluster and of the two workload clusters.
2. The workspace namespace of workspace `prod` (the namespace is not always the workspace name; I read it, I do not guess).
3. Do AI Navigator or NKP Insights run on any of the three clusters (gate G6)?
4. Does any app have a PodDisruptionBudget that allows 0 disruptions (it stops a node drain)?
5. Do you want a Velero backup before the upgrade? It is optional. [pdf p.1010]

### Step 1: find the versions and the path (I run this now)

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
nkp version
kubectl --kubeconfig "$MGMT_KUBECONFIG" get nkpclusters -A -o custom-columns='NAMESPACE:.metadata.namespace,NAME:.metadata.name,NKP:.status.platformVersion,K8S:.status.kubernetesVersion,PHASE:.status.phase,CLASS:.spec.capiCluster.topology.classRef.name,MGMT:.metadata.labels.kommander\.d2iq\.io/host'
kubectl --kubeconfig "$MGMT_KUBECONFIG" get clusters.cluster.x-k8s.io -A -o custom-columns='NAMESPACE:.metadata.namespace,NAME:.metadata.name,CLASS:.spec.topology.classRef.name,K8S:.spec.topology.version'
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n kommander get helmrelease kommander
kubectl --kubeconfig "$MGMT_KUBECONFIG" get workspaces -o custom-columns='WORKSPACE:.metadata.name,NAMESPACE:.status.namespaceRef.name'
nkp upgrade cluster nutanix --help | head -1
```

Done when: the `nkp` line shows `2.19.0`, every cluster shows `2.18.0`, and each cluster has a path (a value in CLASS → ClusterClass path; empty CLASS → non-ClusterClass path). `nkp upgrade cluster` has only `eks`, `metal`, `nutanix`. [live 2.19.0] The last line prints the target Kubernetes version (`1.36.2` for 2.19.0) — I use it for the image names.

### Step 2: gates (I run these now)

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" get nkpclusters -A
kubectl --kubeconfig "$MGMT_KUBECONFIG" get upgradeplans -A
kubectl --kubeconfig "$MGMT_KUBECONFIG" get helmreleases -A | awk 'NR==1 || $4!="True"'
kubectl --kubeconfig "$MGMT_KUBECONFIG" get machines -A | awk 'NR==1 || $0 !~ /Running/'
kubectl --kubeconfig "$MGMT_KUBECONFIG" get nodes | awk 'NR==1 || $2!="Ready"'
kubectl --kubeconfig "$MGMT_KUBECONFIG" get pdb -A | awk 'NR==1 || $(NF-1)=="0"'
```

The last two lines also run with `"$CLUSTER_KUBECONFIG"` of each of the three clusters. Gate G1 says: PHASE `Reconciled`, and no rows in the other lists. An UpgradePlan that is not `Upgraded` means an upgrade is already running — I do not start another. [live 2.19.0]

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" get nkpclusters -A -o json | jq -r '.items[] | select((.spec.capiCluster.topology.classRef.name // "") | startswith("nkp-nutanix")) | [.metadata.namespace, .metadata.name, ([(.spec.capiCluster.topology.variables[]? | select(.name=="clusterConfig").value.controlPlane.nutanix.machineDetails.project.name // "_internal"), (.spec.capiCluster.topology.workers.machineDeployments[]?.variables.overrides[]? | select(.name=="workerConfig").value.nutanix.machineDetails.project.name // "_internal")] | unique | join(","))] | @tsv'
```

Gate G3: each line must show **one** project. Two projects → you move the other pools into the control-plane project with the NKP UI. I do not patch the project. [pdf p.1016]

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" get gitrepositories -A
kubectl --kubeconfig "$MGMT_KUBECONFIG" get appdeployments -A | grep -E 'cloudnative-pg|ai-navigator|nkp-insights'
```

Gate G5: only `kommander-flux/management` may be in the first list. [live 2.19.0] Gate G6: if AI Navigator or NKP Insights run, `cloudnative-pg` must be in the second list.

Gate G2 (connected site, no mirror):

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" get nkpclusters -A -o custom-columns='NAMESPACE:.metadata.namespace,NAME:.metadata.name,MIRROR:.spec.capiCluster.topology.variables[?(@.name=="clusterConfig")].value.globalImageRegistryMirror.url'
kubectl --kubeconfig "$MGMT_KUBECONFIG" get secrets -A | grep dockerhub-nutanix-credentials
for v in NUTANIX_REGISTRY_USERNAME NUTANIX_REGISTRY_TOKEN; do if [ -n "$(printenv "$v")" ]; then echo "set: $v"; else echo "MISSING: $v"; fi; done
```

If a name prints `MISSING`, you get the username and the token (PAT) from the NKP downloads page of the Nutanix portal [pdf p.1017] and add them with an editor — never in the chat:

```bash
# USER-TERMINAL  (you add NUTANIX_REGISTRY_USERNAME and NUTANIX_REGISTRY_TOKEN with an editor)
vi ~/nkp-site.env
```

UNKNOWN (P-26): whether a connected site that uses a registry mirror still needs these credentials. Not your case (no mirror). Until then the skills say: set them on every connected site.

**Plan — the value of the target version.** Target: `~/nkp-site.env`. Result: one new line; the last line wins.

```bash
# CHANGES  (appends NKP_TARGET_VERSION to ~/nkp-site.env)
source ~/nkp-site.env 2>/dev/null
echo "export NKP_TARGET_VERSION='v2.19.0'" >> ~/nkp-site.env
```

You gave 2.19.0; I write it in the `v` form the skill needs (`v2.19.0`). Type `yes` for this line. If you prefer another form, say which.

**Plan — Docker Hub credentials on all three clusters** (only if the G2 block shows a missing Secret). Target: management cluster, and the `dockerhub-nutanix-credentials` Secret of every cluster. Result: NKP writes or updates that Secret in each cluster namespace.

```bash
# CHANGES  (writes the Docker Hub credentials Secret of the management cluster and of every workload cluster)
source ~/nkp-site.env 2>/dev/null
nkp update cluster nutanix-registry-credentials --all-namespaces --nutanix-registry-username "$NUTANIX_REGISTRY_USERNAME" --nutanix-registry-password "$NUTANIX_REGISTRY_TOKEN" --kubeconfig "$MGMT_KUBECONFIG"
```

The CLI takes the token only as a flag, so other users on the bastion can see it in the process list. [live 2.19.0]

### Step 3: the CLI and the OS image

- The `nkp` line of `nkp version` must show 2.19.0. A different CLI version can make the upgrade fail. [pdf p.1018] How to get the 2.19.0 CLI on a connected site is **not in the skills** (the skills give the bundle path `cli/nkp` for air-gapped sites). Check: `which nkp` and `nkp version`.
- **G7 image.** The AHV image name comes from the Nutanix portal unchanged and contains the target Kubernetes version. The preflight finds it by name. [pdf p.726]
- UNKNOWN (P-23): the guide says the management cluster image matches the **current** NKP Kubernetes version (p.1019) and the workload cluster image the **target** version (p.1022). The line `nkp upgrade cluster nutanix --help | head -1` prints the version to use. I use what it prints.
- Question: confirm the exact image name in Prism Central for the management cluster and for the workload clusters (they can be the same name).

### The plan, in order (each block is shown again and approved on its own)

1. **Step 4 — Kommander.** `nkp upgrade kommander` on the management cluster. It upgrades the management plane (CAPI, the ClusterClasses) and the management platform apps. [pdf p.1017] Done when `exit: 0`, the ManagementPlane VERSION and CURRENT VERSION show 2.19.0, and the HelmRelease list has only the header line. [live 2.19.0]
2. **Step 5 — management cluster.** `~/nkp-<mgmt>.env` with `WORKSPACE_NS='kommander'`. Path from step 1: `clusterclass.md` section "Upgrade one cluster", or `non-clusterclass.md` section "Management cluster". Dry run first (C3/N1-N4), then the upgrade. A ClusterClass cluster needs one command; a non-ClusterClass cluster needs addons, control plane, then each pool.
3. **Step 6 — workload cluster A, then B.** Same path, one cluster at a time, with its own env file. The management cluster must be on 2.19.0 first. [pdf p.1022]
4. **Step 7 — post-checks for each cluster:** NKPCluster PHASE `Reconciled`, versions 2.19.0 / target Kubernetes, last `history` line with two times, all machines `Running`, all nodes `Ready`, no pod outside `Running`/`Succeeded`, HelmRelease list with only the header line. [pdf p.1044-1047]

If anything stops: I do not run the command again and I delete nothing. I do the READ-ONLY checks in `stopped.md` (S1–S4) and name the stage.

Waiting for: your answers to the 5 questions, the exact cluster names, and `yes` for the `NKP_TARGET_VERSION` line.

---

## nkp-upgrade U2

Skill files read: `skills/_shared/RULES.md`, `skills/nkp/SKILL.md`, `skills/nkp-upgrade/SKILL.md`, `skills/nkp-upgrade/references/clusterclass.md`, `skills/nkp-upgrade/references/stopped.md`

### Answer: no, not with the 2.19 CLI

- **Version path.** Go through each **minor** version in order. You can skip patch versions. [pdf p.1011] The only source version for 2.19.0 is **2.18.0**. [pdf p.1011-1012] So 2.17.1 → 2.19.0 is not allowed, and the 2.19 CLI must not do it. The table you saw allows skipping *patch* versions (for example 2.17.1 → 2.17.4), not a minor version.
- **Two hops:** 2.17.1 → 2.18.x with the **2.18 CLI**, then 2.18.x → 2.19.0 with the **2.19 CLI**. The CLI version must be the same as the version you upgrade to; a different CLI can make the upgrade fail. [pdf p.1018]
- The 2.18 upgrade steps are **not in the skills**. I can plan and drive the 2.19 hop; for the 2.18 hop I follow the 2.18 material you have, or you ask Nutanix support.

### Step 1 (I run this now)

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
nkp version
kubectl --kubeconfig "$MGMT_KUBECONFIG" get nkpclusters -A -o custom-columns='NAMESPACE:.metadata.namespace,NAME:.metadata.name,NKP:.status.platformVersion,K8S:.status.kubernetesVersion,PHASE:.status.phase,CLASS:.spec.capiCluster.topology.classRef.name,MGMT:.metadata.labels.kommander\.d2iq\.io/host'
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n kommander get helmrelease kommander
```

This confirms the real version of each cluster (the platform version is also in the `kommander` HelmRelease status text, for example `kommander-chart@v2.18.0`). [live 2.19.0] The output tells me whether the management cluster is on 2.17.1 too, and which cluster must go first.

### Questions

1. Which cluster and which version is the `nkp` CLI on the bastion now?
2. Do you have the 2.18 bundle and 2.18 CLI at hand? (The 2.18 hop needs them.)
3. Is any cluster already on 2.18, or are all on 2.17.1?

### What I will not do

I will not run `nkp upgrade kommander` or `nkp upgrade cluster` with the 2.19 CLI against a 2.17.1 cluster. That skips a minor version. The 2.19 gates (OCI catalogs only, one Prism Central project, Docker Hub credentials) also assume a 2.18 source.

---

## nkp-upgrade U3

Skill files read: `skills/_shared/RULES.md`, `skills/nkp/SKILL.md`, `skills/nkp-upgrade/SKILL.md`, `skills/nkp-airgap/SKILL.md`, `skills/nkp-airgap/references/prestage.md`

### Answer: before `nkp upgrade kommander` you do three things

Air-gapped sites do skill `nkp-airgap` steps 1, 2 and 4 with the **target** bundle, before the Kommander upgrade: install the target CLI, then push the target bundles into the registry mirror. [pdf p.1012-1015] Then the 2.19 gates. Docker Hub credentials (G2) do **not** apply to an air-gapped site. [pdf p.1017]

### Step 1: check and extract the bundle (I run the checks, the extract is a plan)

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
df -h "$(dirname "$BUNDLE_DIR")"
ls -l "$(dirname "$BUNDLE_DIR")"/nkp-bundle_v*_linux_amd64.tar.gz
```

`BUNDLE_DIR` is the folder that holds the tarball, plus `/nkp-v2.19.0`. [live 2.19.0] The 2.19.0 tarball is 37.7 GB and the folder is about 37.5 GB — plan for about 76 GB free. [live 2.19.0] Keep only one bundle tarball in that folder.

If `BUNDLE_DIR` is not in `~/nkp-site.env` yet, tell me the folder and I append it (rule 4) before this block runs.

**Plan — check and extract.** Target: the folder above. Result: about 37 GB extracted into `$BUNDLE_DIR`, tarball checksum verified.

```bash
# CHANGES  (checks the tarball, then extracts about 37 GB into the folder)
source ~/nkp-site.env 2>/dev/null
( cd "$(dirname "$BUNDLE_DIR")" && sha256sum -c nkp-bundle.sha256 && tar -xzf "$(ls nkp-bundle_v*_linux_amd64.tar.gz | tail -1)" )
```

If `sha256sum -c` prints `FAILED`, I stop: the copy is damaged and you copy it again.

**Plan — install the 2.19.0 CLI and kubectl from the bundle.** Target: `/usr/local/bin` on this bastion. Result: `nkp version` shows 2.19.0. The CLI version must equal the version you upgrade to. [pdf p.1018]

```bash
# CHANGES  (copies nkp and kubectl from the bundle into /usr/local/bin)
source ~/nkp-site.env 2>/dev/null
sudo -n install -m 0755 "$BUNDLE_DIR/cli/nkp" "$BUNDLE_DIR/kubectl" /usr/local/bin/
```

(If `sudo -n` fails, sudo needs a password on this host; then you run the same line yourself.)

### Step 2: check the bundle contents

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
ls -l "$BUNDLE_DIR" "$BUNDLE_DIR/container-images" "$BUNDLE_DIR/image-artifacts" "$BUNDLE_DIR/image-artifacts/images"
"$BUNDLE_DIR/cli/nkp" version
( cd "$BUNDLE_DIR" && sha256sum -c nkp-*-release-amd64.iso.sha256 )
```

Needed for your case: `cli/nkp`, `kubectl`, `konvoy-bootstrap-image-v2.19.0.tar`, `konvoy-image-bundle-v2.19.0.tar`, `kommander-image-bundle-v2.19.0.tar`, `nkp-release-specs-v2.19.0.tar`. [live 2.19.0] Add the NDK product catalog bundle only if you run NDK on Nutanix. [pdf p.723] On AHV the node OS image is a Prism Central image, not a bundle file.

### Step 3: set `IMAGE_BUNDLES` and push into Harbor

The push account is a secret — you add it, I never print it:

```bash
# USER-TERMINAL  (you add the Harbor push account lines with an editor)
vi ~/nkp-site.env
```

Add `REGISTRY_PUSH_USERNAME` and `REGISTRY_PUSH_PASSWORD`. The pull account for the nodes is `REGISTRY_MIRROR_USERNAME` / `REGISTRY_MIRROR_PASSWORD` — check those lines exist too.

**Plan — set `IMAGE_BUNDLES`.** Target: `~/nkp-site.env`. Result: one line with the three bundle paths. The block stops silently if one file is missing.

```bash
# CHANGES  (appends IMAGE_BUNDLES to ~/nkp-site.env)
source ~/nkp-site.env 2>/dev/null
b="$BUNDLE_DIR/container-images"; k="$(ls "$b"/konvoy-image-bundle-*.tar)"; m="$(ls "$b"/kommander-image-bundle-*.tar)"; r="$(ls "$b"/nkp-release-specs-*.tar)"; test -f "$k" && test -f "$m" && test -f "$r" && echo "export IMAGE_BUNDLES='$k,$m,$r'" >> ~/nkp-site.env
```

Then the checks:

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
echo "$IMAGE_BUNDLES" | tr ',' '\n'
h="${REGISTRY_URL#*://}"; curl -s -o /dev/null -w '%{http_code}\n' --cacert "$REGISTRY_CA_FILE" "https://${h%%/*}/v2/"
for v in REGISTRY_PUSH_USERNAME REGISTRY_PUSH_PASSWORD REGISTRY_MIRROR_USERNAME REGISTRY_MIRROR_PASSWORD; do if [ -n "$(printenv "$v")" ]; then echo "set: $v"; else echo "MISSING: $v"; fi; done
```

HTTP `200` or `401` means Harbor answers and the CA is right.

**Plan — push the 2.19.0 bundles into Harbor.** Target: your Harbor project (the first path part of `REGISTRY_URL`). Result: all images of the three bundles are in the mirror, and the new machines can pull them. This must finish before the Kommander upgrade. [pdf p.1012-1015] The password is a flag, so other users on the bastion can see it in the process list.

```bash
# CHANGES  (pushes all images in IMAGE_BUNDLES into the site registry)
source ~/nkp-site.env 2>/dev/null
nkp push bundle --bundle "$IMAGE_BUNDLES" --to-registry "$REGISTRY_URL" --to-registry-ca-cert-file "$REGISTRY_CA_FILE" --to-registry-username "$REGISTRY_PUSH_USERNAME" --to-registry-password "$REGISTRY_PUSH_PASSWORD"
```

- Harbor can print `UNAUTHORIZED: project not found, name: mesosphere`. That is a false positive; the image is pushed. [pdf p.992]
- Push again after a failure with `--on-existing-tag skip`. [live 2.19.0]
- Do **not** use `--to-internal-registry-mirror` here: you have a site mirror. Use one mode only. [pdf p.725]

### Step 4: gates, then the Kommander upgrade

Run the 2.19 gates on the management cluster and both workload clusters: G1 health, G3 one Prism Central project per cluster, G5 OCI catalogs only, G6 CloudNativePG if AI Navigator/NKP Insights run, G7 image, G8 Prism Central role, G9 one free VM slot per pool. The blocks are in section U1, step 2 — I run them here unchanged.

**Plan — the Kommander upgrade** (only after the push ended without an error, the gates pass, and you confirm the 2.19.0 AHV image name for the management cluster). Target: the management cluster (`kommander`). Result: management plane (CAPI, ClusterClasses) and management platform apps on 2.19.0; the UI and APIs can be unavailable during it. [pdf p.1017-1018]

```bash
# CHANGES  (upgrades Kommander, CAPI, the ClusterClasses, and the platform apps on the management cluster)
source ~/nkp-site.env 2>/dev/null
( set -o pipefail; nkp upgrade kommander --kubeconfig "$MGMT_KUBECONFIG" 2>&1 | tee -a "$HOME/nkp-upgrade-kommander.log" ); echo "exit: $?"
```

Optional flags if you need longer waits: `--core-app-timeout` (default 20m) and `--platform-apps-timeout` (default 1h). [live 2.19.0] UNKNOWN (P-20): `--disable-appdeployments` is not in the 2.19.0 help — check with `nkp upgrade kommander --help` before you rely on it.

Done when: `exit: 0`, VERSION and CURRENT VERSION of the ManagementPlane show 2.19.0, and the HelmRelease list has only the header line. [live 2.19.0]

Waiting for: the `BUNDLE_DIR` folder, the Harbor push account in the file, and `yes` for the first plan (extract).

---

## nkp-upgrade U4

Skill files read: `skills/_shared/RULES.md`, `skills/nkp-upgrade/SKILL.md`, `skills/nkp-upgrade/references/clusterclass.md`, `skills/nkp-upgrade/references/stopped.md`

### I cannot run it yet, and "no need to ask me" is not approval

Rule 2: before a `# CHANGES` block I show the command, the target, and the result, and I run it only when you type `yes` to that plan. "Just run it" is not `yes`. This upgrade replaces every management-cluster node, including the API server and etcd, so I will not start it on a chat sentence.

Also, three things are not confirmed yet:

1. **The Kommander "Done when"** — I must see it before step 5: `exit: 0`, ManagementPlane VERSION **and** CURRENT VERSION at 2.19.0, HelmRelease list with only the header line. [live 2.19.0] A management cluster upgrade before that is out of order. [pdf p.1017-1019]
2. **The image version** — UNKNOWN (P-23): the guide says the management cluster image matches the **current** NKP Kubernetes version (p.1019); `nkp upgrade cluster nutanix --help | head -1` prints the version to use. The preflight finds the image **by name**. [pdf p.726] If the CLI prints `1.36.2`, your name `nkp-rocky-9.8-release-1.36.2` matches; if not, the preflight stops before any change.
3. **The cluster env file** for the management cluster.

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" get managementplanes
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n kommander get helmreleases | awk 'NR==1 || $3!="True"'
nkp version
nkp upgrade cluster nutanix --help | head -1
```

Done when: `exit: 0` in the Kommander log, the ManagementPlane shows 2.19.0 in both columns, the HelmRelease list has only the header, and the last line prints `1.36.2`.

### Question

What is the management cluster name? (I need it for `~/nkp-<name>.env` with `WORKSPACE_NS='kommander'`.) If `~/nkp-<name>.env` exists, I use it.

**Plan — record the image** (after you confirm the name). Target: `~/nkp-site.env`. Result: one new line; the last line wins.

```bash
# CHANGES  (appends VM_IMAGE to ~/nkp-site.env)
source ~/nkp-site.env 2>/dev/null
echo "export VM_IMAGE='nkp-rocky-9.8-release-1.36.2'" >> ~/nkp-site.env
```

### C1: find the CAPI cluster name (I run this now)

The command needs `status.capiClusterRef`, not the NKPCluster name — they can differ. [pdf p.1020]

```bash
# READ-ONLY
source ~/nkp-<mgmt>.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get nkpcluster "$CLUSTER_NAME" -o custom-columns='CAPI:.status.capiClusterRef.name,CAPI_NS:.status.capiClusterRef.namespace,CLASS:.spec.capiCluster.topology.classRef.name,K8S:.status.kubernetesVersion'
nkp get nodepools --cluster-name "$CLUSTER_NAME" --namespace "$WORKSPACE_NS" --kubeconfig "$MGMT_KUBECONFIG"
kubectl --kubeconfig "$MGMT_KUBECONFIG" get clusters.cluster.x-k8s.io -A -o custom-columns='NAMESPACE:.metadata.namespace,NAME:.metadata.name,CONCURRENCY:.metadata.annotations.topology\.cluster\.x-k8s\.io/upgrade-concurrency'
```

`CLASS` `nkp-nutanix-v2.18.0` → `infra=nutanix`, ClusterClass path. Empty CLASS → non-ClusterClass path and I tell you before anything runs.

### C3: dry run (writes a local file, changes nothing)

**Plan.** Target: `$PWD/<cluster>-upgrade-dryrun.yaml` (mode 600, may contain Secrets — I never print it). Result: the objects the upgrade would apply. I then show you only the `kind`, `name`, `classRef`, `version`, `image` lines.

```bash
# CHANGES  (writes the dry-run objects to a local file; upgrades nothing)
source ~/nkp-<mgmt>.env 2>/dev/null
infra='nutanix'; capi=''; capins=''
: "${infra:?}" "${capi:?}" "${capins:?}"
img=(); [ "$infra" = nutanix ] && img=(--vm-image "$VM_IMAGE"); [ "$infra" = nutanix ] && [ -n "$WORKER_VM_IMAGES" ] && img=(--control-plane-vm-image "$CP_VM_IMAGE" --worker-vm-images "$WORKER_VM_IMAGES")
umask 077 && nkp upgrade cluster "$infra" --cluster-name "$capi" --namespace "$capins" "${img[@]}" --kubeconfig "$MGMT_KUBECONFIG" --dry-run -o yaml > "$PWD/$CLUSTER_NAME-upgrade-dryrun.yaml"
```

`capi` and `capins` come from C1; I fill them before you approve. If the cluster is already on the target version, the command prints "already using the latest supported Kubernetes version" and writes an empty file. [live 2.19.0]

```bash
# READ-ONLY
source ~/nkp-<mgmt>.env 2>/dev/null
grep -n -E '^kind:|^  name:|classRef:|^ *version:|image:|name: nkp-' "$PWD/$CLUSTER_NAME-upgrade-dryrun.yaml"
```

Expect `nkp-nutanix-v2.19.0`, Kubernetes `1.36.2`, and your image name.

### C4: the upgrade — the plan you must approve

**Target:** the management cluster (its own CAPI objects, in namespace `kommander`).
**Result:** the ClusterClass, the CNI, the CSI driver, the control plane and the worker pools go to 2.19.0 / 1.36.2. **NKP replaces every node**: control plane first, then the pools, one at a time. PodDisruptionBudgets keep apps up; a PDB that allows 0 disruptions blocks a drain. On a single-control-plane-node cluster the API is down during the replace. A preflight failure stops before any change. There is **no rollback**. [pdf p.1020-1044]

```bash
# CHANGES  (upgrades the cluster: new ClusterClass, Kubernetes, addons; replaces all nodes)
source ~/nkp-<mgmt>.env 2>/dev/null
infra='nutanix'; capi=''; capins=''
: "${infra:?}" "${capi:?}" "${capins:?}"
img=(); [ "$infra" = nutanix ] && img=(--vm-image "$VM_IMAGE"); [ "$infra" = nutanix ] && [ -n "$WORKER_VM_IMAGES" ] && img=(--control-plane-vm-image "$CP_VM_IMAGE" --worker-vm-images "$WORKER_VM_IMAGES")
( set -o pipefail; nkp upgrade cluster "$infra" --cluster-name "$capi" --namespace "$capins" "${img[@]}" --kubeconfig "$MGMT_KUBECONFIG" 2>&1 | tee -a "$HOME/nkp-upgrade-$CLUSTER_NAME.log" ); echo "exit: $?"
```

Default `--timeout` is 40m and each node takes some minutes. [live 2.19.0] With 3 control-plane nodes and 4 workers, ask for more: I add `--timeout 3h` to the line and tell you. Say if you want a different value.

Then I watch with C5 and give you the step 7 post-checks.

**Reply `yes` (plus the timeout you want) and I run C1's checks and the dry run C3 first; then I come back with the dry-run lines and ask you again for C4.**

---

## nkp-upgrade U5

Skill files read: `skills/_shared/RULES.md`, `skills/nkp-troubleshooting/SKILL.md`, `skills/nkp-troubleshooting/references/rollouts.md`, `skills/nkp-upgrade/references/clusterclass.md`, `skills/nkp-upgrade/references/stopped.md`

### Answer: no, do not delete the machines

- `Reconciling` is the **normal** phase during an upgrade. The phases are `Reconciling Platform Applications` and `Reconciling Kubernetes and Cluster Infrastructure`; `Reconciled` is the end state. [live 2.19.0]
- Two old machines plus one new machine is the normal shape of a roll: a pool rolls with `maxSurge: 1`, `maxUnavailable: 0` — one new node must be Ready before an old node drains. The control plane rolls first, then the pools. [live 2.19.0][pdf p.1043]
- Machines are immutable: the rollout makes new machines and deletes old ones one at a time. [pdf p.24]
- An error does not start a repair or a rollback, and the rules say: **do not delete Machines, Clusters, NKPClusters, or UpgradePlans**. [pdf p.1044, p.1048] Deleting a machine mid-roll can leave a VM, a disk, or an IP behind and nothing tracking it.
- A warning that clears without action is normal while a part reconciles. Wait 10 minutes, then check again. [pdf p.1043]

One hour for a large cluster is not long. Each node takes some minutes.

### Watch the upgrade (I run this now)

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get upgradeplans -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.phase}{"\n"}{range .status.steps[*]}{"  "}{.name}{"\t"}{.state}{"\t"}{.error}{"\n"}{end}{end}'
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get nkpcluster "$CLUSTER_NAME"
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get machines -l "cluster.x-k8s.io/cluster-name=$CLUSTER_NAME"
```

UNKNOWN (P-25): whether `nkp upgrade cluster` (CLI) makes an UpgradePlan, or only the UI and `nkp upgrade platform-apps` do. If there is no UpgradePlan, we watch the NKPCluster PHASE and the machines. [live 2.19.0]

### Then the machine detail (I run this next)

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get machines -l "cluster.x-k8s.io/cluster-name=$CLUSTER_NAME" -o custom-columns='NAME:.metadata.name,NODE:.status.nodeRef.name,PHASE:.status.phase,READY:.status.conditions[?(@.type=="Ready")].status,UPTODATE:.status.conditions[?(@.type=="UpToDate")].status,DELETING:.metadata.deletionTimestamp,AGE:.metadata.creationTimestamp'
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get machines -l "cluster.x-k8s.io/cluster-name=$CLUSTER_NAME" -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{range .status.conditions[?(@.status!="True")]}  {.type}={.status} {.reason}: {.message}{"\n"}{end}{end}'
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get nkpcluster "$CLUSTER_NAME" -o jsonpath='{range .status.conditions[*]}{.type}{"\t"}{.status}{"\t"}{.reason}{"\t"}{.message}{"\n"}{end}'
```

Healthy: the only conditions that are not `True` on a machine are `Updating=False`, `Paused=False`, `Deleting=False`. [live 2.19.0] The first `False` NKPCluster condition shows the part that stopped — healthy is all `True`. [live 2.19.0]

### How I decide, from the output

| What we see | Meaning | Next |
|---|---|---|
| Old machines `Running`, one new machine `Provisioning` | normal roll | wait; check again in 10 minutes |
| Old machine `Running` for a long time, rollout waits | a drain is blocked (PDB) or the new node is not Ready | R6: `kubectl get pdb -A -o custom-columns=...ALLOWED:.status.disruptionsAllowed` and the pods on that node |
| Old machine `Deleting` for **more than 15 minutes** | the drain, the VM delete, or a finalizer blocks | `deletes.md` D1–D3 |
| Machine `Failed`, or `Provisioning` with `InfrastructureReady` not `True` | the VM is not made | CAPX log (`capx-system`) for that machine name |
| `Paused=True` | reconcile is paused | ask what ran last; I do not unpause |
| NKPCluster condition `False` naming a credential Secret or a missing image | the two common causes of a long `Reconciling` [pdf p.1048] | the message names it; image → the upgrade image, credentials → `nkp-install` |

Send me the output of the three blocks and I name the stage. I will not delete a machine and I will not strip a finalizer while this rollout is running.

---

## nkp-upgrade U6

Skill files read: `skills/_shared/RULES.md`, `skills/nkp/SKILL.md`, `skills/nkp-upgrade/SKILL.md`, `skills/nkp-upgrade/references/non-clusterclass.md`, `skills/nkp-upgrade/references/clusterclass.md`, `skills/nkp-upgrade/references/stopped.md`, `skills/nkp-install/references/cloud.md`

### Path first: one check decides the steps

The guide lists vSphere as a **non-ClusterClass** provider in the upgrade chapter. [pdf p.1025] `nkp upgrade cluster` has only `eks`, `metal`, `nutanix`. [live 2.19.0] So if your vSphere cluster has a CLASS value, stop and tell me: the CLI has no `vsphere` upgrade subcommand and that path is **not in the skills**. If CLASS is empty, we use `non-clusterclass.md`.

### Step 1 (I run this now)

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" get nkpclusters -A -o custom-columns='NAMESPACE:.metadata.namespace,NAME:.metadata.name,NKP:.status.platformVersion,K8S:.status.kubernetesVersion,PHASE:.status.phase,CLASS:.spec.capiCluster.topology.classRef.name,MGMT:.metadata.labels.kommander\.d2iq\.io/host'
kubectl --kubeconfig "$MGMT_KUBECONFIG" get clusters.cluster.x-k8s.io -A -o custom-columns='NAMESPACE:.metadata.namespace,NAME:.metadata.name,CLASS:.spec.topology.classRef.name,K8S:.spec.topology.version'
kubectl --kubeconfig "$MGMT_KUBECONFIG" get workspaces -o custom-columns='WORKSPACE:.metadata.name,NAMESPACE:.status.namespaceRef.name'
```

Done when: NKP and PHASE for `web-01` are read, the CLASS column is read, and the WORKSPACE `apps` row shows NAMESPACE `apps-x7k2p`. `nkp upgrade platform-apps --workspace` takes the workspace **name** (`apps`), not the namespace. [live 2.19.0]

### Step: the cluster env file `~/nkp-web-01.env`

**Plan** (two blocks). Target: `~/nkp-web-01.env` on this bastion. Result: a mode-600 file that sources the site file, plus the four values.

```bash
# CHANGES  (makes the cluster env file with mode 600 if it does not exist)
test -e ~/nkp-web-01.env || { (umask 077 && echo 'source ~/nkp-site.env 2>/dev/null' > ~/nkp-web-01.env); }
```

```bash
# CHANGES  (appends CLUSTER_NAME and WORKSPACE_NS to the cluster env file)
echo "export CLUSTER_NAME='web-01'" >> ~/nkp-web-01.env
echo "export WORKSPACE_NS='apps-x7k2p'" >> ~/nkp-web-01.env
```

`CLUSTER_KUBECONFIG` for this cluster is written with the workload-cluster block of `nkp-install` (it runs `nkp get kubeconfig` and appends the path). That is a `# CHANGES` block; I show it when we get there. `MGMT_KUBECONFIG` is already in `~/nkp-site.env`.

```bash
# READ-ONLY
source ~/nkp-web-01.env 2>/dev/null
for v in CLUSTER_NAME WORKSPACE_NS CLUSTER_KUBECONFIG MGMT_KUBECONFIG; do if [ -n "$(printenv "$v")" ]; then echo "set: $v"; else echo "MISSING: $v"; fi; done
```

Done when: all four print `set:`.

### Step N1: select the provider and read the pools (I run this)

```bash
# READ-ONLY
source ~/nkp-web-01.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get nkpcluster "$CLUSTER_NAME" -o custom-columns='CAPI:.status.capiClusterRef.name,CAPI_NS:.status.capiClusterRef.namespace,K8S:.status.kubernetesVersion'
kubectl --kubeconfig "$MGMT_KUBECONFIG" get workspaces -o custom-columns='WORKSPACE:.metadata.name,NAMESPACE:.status.namespaceRef.name'
nkp get nodepools --cluster-name "$CLUSTER_NAME" --namespace "$WORKSPACE_NS" --kubeconfig "$MGMT_KUBECONFIG"
```

`infra=vsphere`. `capi` and `capins` come from the first block — always give the namespace, the CLI default `default` is wrong. [pdf p.1030][live 2.19.0] `ws=apps`.

### The sequence (each block separately approved)

**1. N2 — platform apps of the workload cluster first.** Target: `web-01` only. Result: the workspace platform apps go to `$NKP_TARGET_VERSION`; no other lifecycle job may run at the same time. [pdf p.1031]

```bash
# CHANGES  (server dry run only: prints the UpgradePlan; creates nothing)
source ~/nkp-web-01.env 2>/dev/null
ws='apps'
: "${ws:?}"
nkp upgrade platform-apps --cluster-name "$CLUSTER_NAME" --workspace "$ws" --version "$NKP_TARGET_VERSION" --kubeconfig "$MGMT_KUBECONFIG" --dry-run
```

```bash
# CHANGES  (creates an UpgradePlan; upgrades the platform apps of one workload cluster)
source ~/nkp-web-01.env 2>/dev/null
ws='apps'
: "${ws:?}"
( set -o pipefail; nkp upgrade platform-apps --cluster-name "$CLUSTER_NAME" --workspace "$ws" --version "$NKP_TARGET_VERSION" --kubeconfig "$MGMT_KUBECONFIG" 2>&1 | tee -a "$HOME/nkp-upgrade-$CLUSTER_NAME.log" ); echo "exit: $?"
```

Error "no Workspace with this name": `ws` is a namespace, not the workspace name — then we read the WORKSPACE column again. [live 2.19.0]

**2. N3 — core addons.** This **replaces the global ClusterResourceSets with one set for each cluster**, so changes you made to a ClusterResourceSet are lost. [pdf p.1026-1027] Question: did anyone change the addon ClusterResourceSets of `web-01`? If yes, we keep the dry-run file to re-apply the custom parts.

```bash
# CHANGES  (writes the new addon objects to a local file; changes nothing in the cluster)
source ~/nkp-web-01.env 2>/dev/null
infra='vsphere'; capi=''; capins=''
: "${infra:?}" "${capi:?}" "${capins:?}"
umask 077 && nkp upgrade addons "$infra" --cluster-name "$capi" --namespace "$capins" --kubeconfig "$MGMT_KUBECONFIG" --dry-run -o yaml > "$PWD/$CLUSTER_NAME-addons-dryrun.yaml"
grep -c '^kind:' "$PWD/$CLUSTER_NAME-addons-dryrun.yaml"
```

```bash
# CHANGES  (upgrades the core addons of one cluster; replaces its ClusterResourceSets)
source ~/nkp-site.env 2>/dev/null
infra='vsphere'; capi=''; capins=''
: "${infra:?}" "${capi:?}" "${capins:?}"
nkp upgrade addons "$infra" --cluster-name "$capi" --namespace "$capins" --kubeconfig "$MGMT_KUBECONFIG"
```

Done when each output line ends with `upgraded`. [pdf p.1027]

**3. N4 — control plane.** `VSPHERE_TEMPLATE` is the **new** template for the target Kubernetes version, built with NIB and the target CLI. [pdf p.1028] `TARGET_K8S_VERSION` is what `nkp upgrade cluster nutanix --help | head -1` prints (v1.36.2 for 2.19.0); you confirm it against the release notes.

```bash
# CHANGES  (upgrades Kubernetes on the control plane; replaces the control-plane nodes)
source ~/nkp-web-01.env 2>/dev/null
infra='vsphere'; capi=''; capins=''
: "${infra:?}" "${capi:?}" "${capins:?}" "${TARGET_K8S_VERSION:?}"
case "$infra" in aws) img=(--ami "$AWS_AMI_ID");; azure) img=(--compute-gallery-id "$AZURE_IMAGE_ID");; gcp) img=(--image "$GCP_IMAGE");; vsphere) img=(--vm-template "$VSPHERE_TEMPLATE");; *) img=();; esac
nkp update controlplane "$infra" --cluster-name "$capi" --namespace "$capins" --kubernetes-version "$TARGET_K8S_VERSION" "${img[@]}" --kubeconfig "$MGMT_KUBECONFIG"
```

Plan text: "NKP replaces the control-plane nodes one at a time." Default timeout 30m. [live 2.19.0] If it prints "timed out waiting for the condition": I do not run it again — I check the machine versions first. [pdf p.1029]

**4. N5 — each node pool, one at a time.** Same image flag. `pool` is each name from N1.

```bash
# CHANGES  (upgrades Kubernetes on one node pool; replaces its nodes)
source ~/nkp-web-01.env 2>/dev/null
infra='vsphere'; capi=''; capins=''; pool=''
: "${infra:?}" "${capi:?}" "${capins:?}" "${pool:?}" "${TARGET_K8S_VERSION:?}"
case "$infra" in aws) img=(--ami "$AWS_AMI_ID");; azure) img=(--compute-gallery-id "$AZURE_IMAGE_ID");; gcp) img=(--image "$GCP_IMAGE");; vsphere) img=(--vm-template "$VSPHERE_TEMPLATE");; *) img=();; esac
nkp update nodepool "$infra" "$pool" --cluster-name "$capi" --namespace "$capins" --kubernetes-version "$TARGET_K8S_VERSION" "${img[@]}" --kubeconfig "$MGMT_KUBECONFIG"
```

**5. Step 7 post-checks** for `web-01` (versions, PHASE `Reconciled`, `history`, machines `Running`, nodes `Ready`, no bad pods, HelmRelease list header only). [pdf p.1044-1047]

### Questions

1. Confirm the new vSphere template name (`VSPHERE_TEMPLATE`) and that it was built with NIB for 1.36.2. [pdf p.1028]
2. Is `VSPHERE_TEMPLATE` already in `~/nkp-site.env`, or do I append the **new** value?
3. Did anyone change the addon ClusterResourceSets (N3)?
4. `web-01` was created by NKP, not attached? Attached clusters are not upgraded by NKP; the tool that made them upgrades them. [pdf p.1035]

Waiting for: the two CLASS/WORKSPACE outputs, your `yes` for the env file blocks, and the four answers.

---

## nkp-upgrade U7

Skill files read: `skills/_shared/RULES.md`, `skills/nkp/SKILL.md`, `skills/nkp-upgrade/SKILL.md`, `skills/nkp-upgrade/references/gitops.md`, `skills/nkp-upgrade/references/stopped.md`

### Answer: yes — a different order, and one dangerous step to remove first

NKP supports GitOps only for **workload** clusters. [pdf p.1016] The order: [pdf p.1037]

1. **Turn off Flux pruning (before the Kommander upgrade).**
2. Upgrade Kommander.
3. Upgrade the management cluster.
4. **Move the Git repository from CAPI `Cluster` objects to NKPCluster objects.** That also upgrades each workload cluster.

**Why:** the Kommander upgrade adopts each ClusterClass CAPI `Cluster` into an NKPCluster. From then on a webhook rejects every change of `Cluster.spec.topology`, also from Flux — message: "CAPI Cluster topology spec is managed by NKPCluster". [pdf p.1038-1039, p.1048] And if pruning is on and the `Cluster` file leaves Git, Flux **deletes the live workload cluster**. [pdf p.1037]

Also: GitOps upgrades make **no UpgradePlan**, so the NKP UI does not show their progress. [pdf p.1037]

### F1: turn off pruning (I run this now)

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" get kustomizations -A -o custom-columns='NAMESPACE:.metadata.namespace,NAME:.metadata.name,PRUNE:.spec.prune,SOURCE:.spec.sourceRef.name'
```

- PRUNE `false`: skip this step. [pdf p.1037]
- The `kommander` Kustomizations are NKP objects. **Do not change them.** [live 2.19.0]

**Question:** which Kustomization applies the cluster files, and in which namespace? Is it applied by a parent Kustomization from Git, or by hand?

- **From Git:** you set `spec.prune: false` in the repo, commit, push, and we wait for Flux. [pdf p.1037] I do not push to Git.
- **By hand:** I patch it, after approval:

```bash
# CHANGES  (sets prune to false on one Flux Kustomization)
source ~/nkp-site.env 2>/dev/null
ks=''; ns=''
: "${ks:?}" "${ns:?}"
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$ns" patch kustomization "$ks" --type merge -p '{"spec":{"prune":false}}'
```

Done when this prints `false`:

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$ns" get kustomization "$ks" -o jsonpath='{.spec.prune}'
```

### F2: management cluster

Step 5 of `nkp-upgrade` only. The workload clusters upgrade in F3. [pdf p.1039] After the Kommander upgrade, Flux shows the webhook error for the workload clusters. **That is expected** until F3. [pdf p.1039]

### F3: one cluster at a time — make the NKPCluster file

**Plan.** Target: a local file `$PWD/<cluster>-nkpcluster-upgrade.yaml` (mode 600, may hold Secrets). Result: the NKPCluster object that replaces the `Cluster` file in Git. Nothing is applied.

```bash
# CHANGES  (writes the upgraded NKPCluster object to a local file; upgrades nothing)
source ~/nkp-<cluster>.env 2>/dev/null
umask 077 && nkp upgrade cluster nutanix --cluster-name "$CLUSTER_NAME" --namespace "$WORKSPACE_NS" --vm-image "$VM_IMAGE" --kubeconfig "$MGMT_KUBECONFIG" --dry-run -o yaml 2>/dev/null | yq 'del(.spec.kommanderCluster.labels)' > "$PWD/$CLUSTER_NAME-nkpcluster-upgrade.yaml"
```

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
grep -n -E '^kind:|classRef:|^ *name: nkp-|^ *version:|image:' "$PWD/$CLUSTER_NAME-nkpcluster-upgrade.yaml"
grep -c '^kind:' "$PWD/$CLUSTER_NAME-nkpcluster-upgrade.yaml"
```

Checks: `kind: NKPCluster`; `classRef` with `nkp-nutanix-v2.19.0`; `spec.capiCluster.topology.version` `1.36.2`; the new image; `spec.version` `v2.19.0`; keep `metadata.name`, `namespace`, `labels`, `annotations`. [pdf p.1042]

UNKNOWN (P-24): whether an adopted GitOps cluster's dry run gives one object or more (Secrets). If the count is more than 1, **stop** — never put a Secret in Git. [pdf p.1042]

Then **you** replace the `Cluster` file in the repo (for example `clusters/<namespace>_<cluster>/cluster.yaml`) with this file, commit, push. I do not push to Git. [pdf p.1042]

Watch:

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get nkpcluster "$CLUSTER_NAME" -o jsonpath='{.status.phase}{"\n"}'
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get machines -l "cluster.x-k8s.io/cluster-name=$CLUSTER_NAME"
kubectl --kubeconfig "$MGMT_KUBECONFIG" get kustomizations -A | awk 'NR==1 || $4!="True"'
```

Done when PHASE goes `Reconciling…` → `Reconciled`, the cluster Kustomization is ready, and the step 7 post-checks pass. [pdf p.1046] Then, optionally, you set `prune: true` again. [pdf p.1043]

### If it goes wrong

| Symptom | Cause | Action |
|---|---|---|
| Flux: webhook denied, "CAPI Cluster topology spec is managed by NKPCluster" | Git still has the `Cluster` object | finish F3 |
| The CAPI `Cluster` was deleted during the move | pruning was on | **stop**, apply nothing, `nkp-troubleshooting` |
| NKPCluster stays `Reconciling` | missing credential Secret, or an image not in Prism Central | `stopped.md` S3 |

### Questions

1. Which Kustomization and namespace applies the cluster files? Is it applied from Git or by hand?
2. Are the workload clusters ClusterClass clusters (they must be, for this procedure)? [pdf p.1016]
3. How many workload clusters, and which one first?

Waiting for: the F1 output, `yes` for the prune patch (if by hand), and the three answers.

---

## nkp-upgrade U8

Skill files read: `skills/_shared/RULES.md`, `skills/nkp-upgrade/SKILL.md`, `skills/nkp-upgrade/references/clusterclass.md`, `skills/nkp-upgrade/references/stopped.md`

### How long

A total time for a 20-node cluster is **not in the skills**. What the skills do give:

- The Kommander upgrade: `--core-app-timeout` default 20m, `--platform-apps-timeout` default 1h. [live 2.19.0]
- `nkp upgrade cluster`: default `--timeout` 40m (`eks` 40m, `metal` 1h), and "each node takes some minutes". [live 2.19.0]
- Every node is replaced, one at a time per pool: `maxSurge: 1`, `maxUnavailable: 0`, so one new node must be Ready before an old one drains. Control plane first, then the pools; by default one pool at a time. [live 2.19.0][pdf p.1018, p.1043]
- Non-ClusterClass: control plane default timeout 30m, then each pool separately. [live 2.19.0]

So for 20 nodes the default 40m is too small. I put `--timeout 3h` (or more) in the command and we watch the progress instead of guessing. A per-pool parallelism exists (`topology.cluster.x-k8s.io/upgrade-concurrency`), but it needs one more free VM **per pool**. [pdf p.1020]

I measure instead of guessing:

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get upgradeplans -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.phase}{"\n"}{range .status.steps[*]}{"  "}{.name}{"\t"}{.state}{"\t"}{.error}{"\n"}{end}{end}'
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get machines -l "cluster.x-k8s.io/cluster-name=$CLUSTER_NAME" -o custom-columns='NAME:.metadata.name,PHASE:.status.phase,READY:.status.conditions[?(@.type=="Ready")].status,AGE:.metadata.creationTimestamp'
```

Count the machines that are `Running` with the new age; that gives the real minutes per node on your hardware. If no UpgradePlan exists (UNKNOWN P-25), the NKPCluster PHASE and the machines are the progress.

### Rollback: no

- "An upgrade replaces every node. **There is no rollback**: an error does not start an automatic repair or rollback." [pdf p.1044]
- There is **no downgrade** in the skills. The stopped-upgrade rules are: no repair, no rollback, do not delete Machines/Clusters/NKPClusters/UpgradePlans, and do not edit the CAPI `Cluster`. [pdf p.1048]
- If 2.19.0 breaks for you, the recovery is to fix forward (support + `stopped.md` S1–S4), or to **rebuild** the cluster at 2.18.0. A rebuild is a cluster delete plus a create: it deletes the nodes, the pods, and all PVC data. [pdf p.814] That is a separate plan with its own approvals.

### What to do instead of relying on a rollback

1. **Velero backup before the upgrade** (optional per the guide). [pdf p.1010] The owning skill is `nkp-storage-backup`, which is **not installed** here: "Skill `nkp-storage-backup` is not installed." I can give no backup command from it. Tell me if you want me to plan the upgrade around a backup you already take.
2. PodDisruptionBudgets keep apps up during the drains; a PDB that allows 0 disruptions blocks a drain and the rollout waits for ever. [pdf p.1010, p.1003]
3. Verify every gate (G1–G9) before you start — most upgrade failures in the skills are gates, not the upgrade itself.
4. One cluster at a time, worst-last order: a workload cluster first? No — the skills fix the order: Kommander, then the management cluster, then the workload clusters. [pdf p.1017-1022]

### Questions

1. Which cluster is the 20-node one — the management cluster or a workload cluster?
2. Do you have a Velero backup, or another backup of the PVC data? Which apps hold state?
3. Which timeout do you want for the cluster command (`3h` is my suggestion for 20 nodes)?

---

## nkp-troubleshooting T1

Skill files read: `skills/_shared/RULES.md`, `skills/nkp/SKILL.md`, `skills/nkp-troubleshooting/SKILL.md`, `skills/nkp-troubleshooting/references/flux.md`, `skills/nkp-troubleshooting/references/controllers.md`, `skills/nkp/SKILL.md` (component table: `kommander-default-workspace`)

### Where you start: rung 4 of the debug ladder, but read rung 1 first

"The apps tab is red" is a **platform apps** symptom (Kommander/Flux), which is rung 4. The ladder says do it from the top and stop at the first rung that is not healthy — a broken NKPCluster or a broken addon also makes the apps red. [live 2.19.0]

### Questions

1. What changed last — a create, an upgrade, a scale, an app change, an infrastructure change — and when did the tab go red?
2. Is the whole UI red, or only this cluster's apps tab?
3. Which vSphere/AHV workspace is `default` here (I read the namespace, I do not guess: the default workspace is normally `kommander-default-workspace` [live 2.19.0]).

### Step 1: select the cluster (I run this now)

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" get nodes
kubectl --kubeconfig "$MGMT_KUBECONFIG" get nkpclusters -A -o custom-columns='NAMESPACE:.metadata.namespace,NAME:.metadata.name,PHASE:.status.phase,K8S:.status.kubernetesVersion,PLATFORM:.status.platformVersion'
kubectl --kubeconfig "$MGMT_KUBECONFIG" get workspaces -o custom-columns='WORKSPACE:.metadata.name,NAMESPACE:.status.namespaceRef.name'
```

If `get nodes` fails or times out, the management API does not answer and we go to the diagnose file, section "API server down". A healthy NKPCluster is PHASE `Reconciled`; `Reconciling Platform Applications` and `Reconciling Kubernetes and Cluster Infrastructure` are the other phases. [live 2.19.0]

The cluster env file for `dev-01` (plan — one file, mode 600). Target: this bastion. Result: `~/nkp-dev-01.env` with the site line, the name, and the namespace from the WORKSPACE row.

```bash
# CHANGES  (makes the cluster env file with mode 600 if it does not exist)
test -e ~/nkp-dev-01.env || { (umask 077 && echo 'source ~/nkp-site.env 2>/dev/null' > ~/nkp-dev-01.env); }
```

```bash
# CHANGES  (appends CLUSTER_NAME and WORKSPACE_NS to the cluster env file)
echo "export CLUSTER_NAME='dev-01'" >> ~/nkp-dev-01.env
echo "export WORKSPACE_NS='kommander-default-workspace'" >> ~/nkp-dev-01.env
```

(The namespace comes from the WORKSPACE row above; if it is different, I append the value it shows.)

### Rung 1: NKPCluster conditions

```bash
# READ-ONLY
source ~/nkp-dev-01.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get nkpcluster "$CLUSTER_NAME" -o jsonpath='phase={.status.phase}{"\n"}{range .status.conditions[?(@.status!="True")]}NKP {.type}={.status} {.reason}: {.message}{"\n"}{end}{range .status.capiCluster.conditions[?(@.status!="False")]}CAPI {.type}={.status} {.reason}: {.message}{"\n"}{end}'
```

On a healthy cluster the `NKP` lines are empty. [live 2.19.0] The first bad line names the part: `PlatformAppsReconciled` / `KommanderClusterReady` → rung 4; `CAPITopologyReconciled` → rung 2 and the CAREN log.

### Rung 4: platform apps (this is the likely one for a red apps tab)

```bash
# READ-ONLY
source ~/nkp-dev-01.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get nkpcluster "$CLUSTER_NAME" -o jsonpath='{range .status.kommanderCluster.conditions[?(@.status!="True")]}{.type}={.status} {.reason}: {.message}{"\n"}{end}'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get helmreleases -A | grep -v -w True
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get kustomizations -A | grep -v -w True
kubectl --kubeconfig "$MGMT_KUBECONFIG" get ocirepositories,gitrepositories,helmcharts -A | grep -v -w True
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get appdeployments
```

Healthy: the first command prints nothing and the others print only headers. [live 2.19.0] Start with the **lowest** failing link: source → HelmChart → HelmRelease → Kustomization. A failed source makes everything above it fail.

Then the message of that object (READ-ONLY):

```bash
# READ-ONLY
source ~/nkp-dev-01.env 2>/dev/null
kind=''; name=''; ns=''; where='mgmt'; case "$where" in mgmt) kc="$MGMT_KUBECONFIG";; cluster) kc="$CLUSTER_KUBECONFIG";; *) kc='';; esac
: "${kind:?}" "${name:?}" "${ns:?}" "${kc:?}"
kubectl --kubeconfig "$kc" -n "$ns" get "$kind" "$name" -o jsonpath='{range .status.conditions[*]}{.type}={.status} {.reason}: {.message}{"\n"}{end}{.status.history[0].status}{"\n"}'
kubectl --kubeconfig "$kc" -n "$ns" get events --field-selector "involvedObject.name=$name" --sort-by=.lastTimestamp | tail -10
```

`where=cluster` for a HelmRelease or Kustomization; `where=mgmt` for a source, a HelmChart, an AppDeployment. `kind`, `name`, `ns` come from the failing row.

### The fix, and its limit

The owner of every platform-app fix is skill **`nkp-platform-apps-gitops`**. That skill is **not installed** here: "Skill `nkp-platform-apps-gitops` is not installed." So I give you READ-ONLY checks only, and **no CHANGES command** from it. I do not write an app override or a HelmRelease reset from memory.

What I can still say from the diagnosis file, so you know the shape of the answer: `exhausted` / `another rollback/release in progress` → the release needs a reset (`spec.suspend` true then false — that is the owner skill's step); `failed to pull` / `x509` / `401` on an OCI source → registry (`nkp-airgap`, which **is** installed); webhook `denied` with "CAPI Cluster topology spec is managed by NKPCluster" → a Kustomization applies a CAPI `Cluster` (`nkp-upgrade`, GitOps migration); a values or schema error → a bad override ConfigMap. [pdf p.1047][live 2.19.0]

### If the cause is still not known

A support bundle finds the failing layer: `nkp diagnose` is a **CHANGES** command (it starts a privileged pod on every node and writes a bundle with ConfigMap data and logs), so I plan it with you first. On an air-gapped site the collector image `v0.14.0` is not in the bundle — item P5 of `nkp-airgap/references/prestage.md` applies first.

Send me the output of step 1, rung 1 and rung 4 and I name the failing object and the message.

---

## nkp-troubleshooting T2

Skill files read: `skills/_shared/RULES.md`, `skills/nkp-troubleshooting/SKILL.md`, `skills/nkp-troubleshooting/references/deletes.md`, `skills/nkp-troubleshooting/references/rollouts.md`, `skills/nkp-troubleshooting/references/controllers.md`

### Answer: I will not strip a finalizer now

A finalizer removal is the last resort, and it **skips the cleanup**: if the VM, disk, or IP still exists it stays in Prism Central and NKP forgets it. [deletes.md, D5] The rules for it are: D1–D3 done, controller healthy, the protected thing already gone, children have no finalizers. Nothing of that is proven yet. [pdf p.497]

A Machine in `Deleting` for an hour after a scale-down has three usual causes and all three are fixable without a finalizer: a drain blocked by a PodDisruptionBudget, a VM delete that Prism Central refuses, or a volume that does not detach. [pdf p.1003]

### R1: read the state (I run this now)

```bash
# READ-ONLY
source ~/nkp-prod-01.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get kubeadmcontrolplanes,machinedeployments,machinesets -l "cluster.x-k8s.io/cluster-name=$CLUSTER_NAME"
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get machines -l "cluster.x-k8s.io/cluster-name=$CLUSTER_NAME" -o custom-columns='NAME:.metadata.name,NODE:.status.nodeRef.name,PHASE:.status.phase,READY:.status.conditions[?(@.type=="Ready")].status,UPTODATE:.status.conditions[?(@.type=="UpToDate")].status,DELETING:.metadata.deletionTimestamp,AGE:.metadata.creationTimestamp'
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get machines -l "cluster.x-k8s.io/cluster-name=$CLUSTER_NAME" -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{range .status.conditions[?(@.status!="True")]}  {.type}={.status} {.reason}: {.message}{"\n"}{end}{end}'
```

`~/nkp-prod-01.env` must exist with `CLUSTER_NAME=prod-01`, its `WORKSPACE_NS`, `CLUSTER_KUBECONFIG`, and `MGMT_KUBECONFIG`. If the file does not exist yet, tell me the workspace and I make it with the block from section T1 (plan, mode 600).

### R6: the drain (I run this next, with the node name from R1)

```bash
# READ-ONLY
source ~/nkp-prod-01.env 2>/dev/null
node=''
: "${node:?}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get pods -A -o wide --field-selector "spec.nodeName=$node"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get pdb -A -o custom-columns='NAMESPACE:.metadata.namespace,NAME:.metadata.name,ALLOWED:.status.disruptionsAllowed'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get pvc -A
```

A PDB with ALLOWED `0` and one of its pods on that node: the drain waits for ever (a pool has no drain timeout by default). [pdf p.1003]

### D1–D3: the object and the cleanup error

```bash
# READ-ONLY
source ~/nkp-prod-01.env 2>/dev/null
kind='machine'; name=''; ns=''; where='mgmt'; case "$where" in mgmt) kc="$MGMT_KUBECONFIG";; cluster) kc="$CLUSTER_KUBECONFIG";; *) kc='';; esac
: "${kind:?}" "${name:?}" "${ns:?}" "${kc:?}"
kubectl --kubeconfig "$kc" -n "$ns" get "$kind" "$name" -o jsonpath='deleting since: {.metadata.deletionTimestamp}{"\n"}finalizers: {.metadata.finalizers}{"\n"}owners: {range .metadata.ownerReferences[*]}{.kind}/{.name} {end}{"\n"}{range .status.conditions[?(@.status!="True")]}{.type}={.status} {.reason}: {.message}{"\n"}{end}'
```

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" get deploy -A --no-headers -o custom-columns='NAMESPACE:.metadata.namespace,NAME:.metadata.name,READY:.status.readyReplicas,WANT:.spec.replicas' | awk '$3 != $4'
```

The second block prints only Deployments where READY ≠ WANT; healthy is no line. If it prints `capx-controller-manager` or `capi-controller-manager`, the cleanup cannot run and the fix is the controller, not the finalizer.

Then the CAPX log for the machine name (AHV provider is `capx-system`):

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
ns='capx-system'; deploy='capx-controller-manager'; filter=''; where='mgmt'; case "$where" in mgmt) kc="$MGMT_KUBECONFIG";; bootstrap) kc="$BOOTSTRAP_KUBECONFIG";; *) kc='';; esac
: "${ns:?}" "${deploy:?}" "${kc:?}"
kubectl --kubeconfig "$kc" -n "$ns" get deploy "$deploy" -o wide
kubectl --kubeconfig "$kc" -n "$ns" get pods -o wide
kubectl --kubeconfig "$kc" -n "$ns" logs "deploy/$deploy" --all-containers --since 2h --timestamps | grep -i -E "${filter:-error|fail|denied|timeout}" | tail -40
```

Set `filter` to the machine name.

### What we do, from the output — not a finalizer

| Cause from D1–D3 | Fix | Owner |
|---|---|---|
| PDB with 0 allowed disruptions on that node | app owner scales up or changes the PDB, or the pool gets a drain timeout (`deletion.nodeDrainTimeoutSeconds: 600`; after the timeout CAPI deletes the node **with the pods still on it**) [live 2.19.0] | owner skill not installed here (`kubernetes-core` / `nkp-cluster-lifecycle`) |
| Prism Central refuses the VM delete (401/403, `x509`, VM lock from a backup or snapshot task) | the PC admin clears the lock; credentials → `nkp-install` | `nkp-install` (installed) / PC admin |
| Volume does not detach | CSI owner | `nkp-storage-backup` — **not installed** |
| Machine sits with a finalizer, its NutanixMachine is gone, VM confirmed gone, controller healthy | then, and only then, the D5 single-finalizer patch | this skill, D5 |

Send me the R1 output (machine name and its first bad condition) and I go to the row above. **No finalizer is removed in this reply.**

---

## nkp-troubleshooting T3

Skill files read: `skills/_shared/RULES.md`, `skills/nkp-troubleshooting/SKILL.md`, `skills/nkp-troubleshooting/references/deletes.md`, `skills/nkp-cluster-lifecycle/references/delete.md`, `skills/nkp-troubleshooting/references/controllers.md`

### "Yes go ahead" is not enough yet — two checks are missing

D5 has four conditions and I must write each one in the plan with its evidence: [pdf p.497]

1. D1–D3 are done and the cleanup error is known and cannot be fixed (your case looks like this: the cluster is gone and the VMs were deleted by hand).
2. The controller of the finalizer is healthy (or will never come back).
3. The thing the finalizer protects is **already gone**, and **you** checked it: the VM with `status.vmUUID` is not in Prism Central.
4. The children of the object have no finalizers left; remove from the bottom up.

`NutanixMachine` is the bottom of the chain (its finalizer is `infrastructure.cluster.x-k8s.io/nutanixmachine`, controller `capx-system`), so it is the correct first object — but I still need the finalizer **list and index** from the object itself, because the patch removes exactly one entry and it has a `test` guard on that index.

### D1: the object (I run this now)

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" get nutanixmachines -A | grep test-03-md-0-abc12
```

That gives the namespace (I do not guess it — it is the workspace namespace `test-03` lived in). Then:

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
kind='nutanixmachine'; name='test-03-md-0-abc12'; ns=''; where='mgmt'; case "$where" in mgmt) kc="$MGMT_KUBECONFIG";; cluster) kc="$CLUSTER_KUBECONFIG";; *) kc='';; esac
: "${kind:?}" "${name:?}" "${ns:?}" "${kc:?}"
kubectl --kubeconfig "$kc" -n "$ns" get "$kind" "$name" -o jsonpath='deleting since: {.metadata.deletionTimestamp}{"\n"}finalizers: {.metadata.finalizers}{"\n"}owners: {range .metadata.ownerReferences[*]}{.kind}/{.name} {end}{"\n"}{range .status.conditions[?(@.status!="True")]}{.type}={.status} {.reason}: {.message}{"\n"}{end}'
```

### The VM check you must confirm (READ-ONLY)

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
ns=''
: "${ns:?}"
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$ns" get nutanixmachine test-03-md-0-abc12 -o custom-columns='NAME:.metadata.name,VM-UUID:.status.vmUUID,DELETING:.metadata.deletionTimestamp'
```

Read the VM UUID and look for it in Prism Central → VMs. You said you deleted the VMs by hand; this is where we prove it. **If that UUID still exists in Prism Central, I will not remove the finalizer** — it would leak a VM that nothing tracks.

### D2 and D3 (I run this too)

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" get deploy -A --no-headers -o custom-columns='NAMESPACE:.metadata.namespace,NAME:.metadata.name,READY:.status.readyReplicas,WANT:.spec.replicas' | awk '$3 != $4'
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n capx-system logs deploy/capx-controller-manager --all-containers --since 48h --timestamps | grep -i -E 'test-03-md-0-abc12|not found|denied|timeout' | tail -40
```

Also its owner Machine — a child of that Machine may be the real blocker:

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -A get machines | grep test-03-md-0-abc12
```

### The plan I will show you (after the checks, with the real index and name)

**Target:** the one `NutanixMachine` object, in its namespace, on the management cluster.
**Result:** Kubernetes deletes the object at once. **The CAPX cleanup is skipped.** If that VM or its disks still exist, they stay in Prism Central and NKP forgets them; you delete them by hand. **This cannot be undone.**

```bash
# CHANGES  (removes one finalizer: the cleanup of that controller is skipped; cannot be undone)
source ~/nkp-site.env 2>/dev/null
kind='nutanixmachine'; name='test-03-md-0-abc12'; ns=''; f=''; fin=''; where='mgmt'; case "$where" in mgmt) kc="$MGMT_KUBECONFIG";; cluster) kc="$CLUSTER_KUBECONFIG";; *) kc='';; esac
: "${kind:?}" "${name:?}" "${ns:?}" "${f:?}" "${fin:?}" "${kc:?}"
kubectl --kubeconfig "$kc" -n "$ns" patch "$kind" "$name" --type json -p "[{\"op\":\"test\",\"path\":\"/metadata/finalizers/$f\",\"value\":\"$fin\"},{\"op\":\"remove\",\"path\":\"/metadata/finalizers/$f\"}]"
```

`f` is the index of the blocking finalizer in the D1 list (the first is `0`), `fin` is its exact name. The `test` op stops the patch if the index points at another name.

Approval: type `yes` **and** the exact object name `test-03-md-0-abc12` in one message, **after** you see this plan with the filled values and after you confirmed the VM UUID is gone. Then I re-run D1 and tell you which Prism Central objects to check.

Waiting for: the `get nutanixmachines -A` output, the VM UUID confirmation, and the D2/D3 output.

---

## nkp-troubleshooting T4

Skill files read: `skills/_shared/RULES.md`, `skills/nkp-troubleshooting/SKILL.md`, `skills/nkp-troubleshooting/references/diagnose.md`, `skills/nkp-airgap/SKILL.md`, `skills/nkp-airgap/references/prestage.md`

### Two things before I run `nkp diagnose`

1. **It is not READ-ONLY.** It starts a privileged pod on every node (host network, PID and IPC) for up to 600 s and writes a `.tar.gz` on this host, and the bundle holds **all ConfigMap data**, all pod logs, host names, and IPs. [live 2.19.0][pdf p.1049-1050] So it is a `# CHANGES` block and it needs your `yes` and a folder.
2. **Air-gapped: the node collector image is missing.** `nkp diagnose` (v0.14.0) asks for `docker.io/mesosphere/dkp-diagnostics-node-collector:v0.14.0`; the 2.19.0 image bundles have only `v0.12.0`. [live 2.19.0] Before the first run, item **P5** of the air-gap prestage file applies.

### P5, choice A (recommended): get the v0.14.0 image in

On a connected host (you run it there; it needs internet — not from this bastion):

```bash
# USER-TERMINAL  (connected host; you run it. Writes diagnose-images.txt and diagnose-collector.tar)
echo 'docker.io/mesosphere/dkp-diagnostics-node-collector:v0.14.0' > diagnose-images.txt
nkp create bundle --images-file diagnose-images.txt --output-file diagnose-collector.tar
```

Move `diagnose-collector.tar` into the air gap (SHA-256 both sides), then push it with the "extra bundle" block. Target: your Harbor mirror. Result: the v0.14.0 collector is pullable by the nodes.

```bash
# CHANGES  (pushes the images of one extra bundle file into the site registry)
source ~/nkp-site.env 2>/dev/null
nkp push bundle --bundle "$EXTRA_BUNDLE" --to-registry "$REGISTRY_URL" --to-registry-ca-cert-file "$REGISTRY_CA_FILE" --to-registry-username "$REGISTRY_PUSH_USERNAME" --to-registry-password "$REGISTRY_PUSH_PASSWORD"
```

`EXTRA_BUNDLE` is the path of `diagnose-collector.tar`; I append it to `~/nkp-site.env` when you tell me the path.

Choice B (not tested): a config file that uses the `v0.12.0` image from the bundle. UNKNOWN (A-08): if the `v0.12.0` collector works with `nkp diagnose` v0.14.0 — only a lab test answers it. Check the tag the CLI asks for:

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
nkp diagnose default-config | grep -n 'node-collector'
```

### Checks before the run (I run these now)

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
nkp version
df -h "${DIAG_DIR:-$PWD}"
nkp diagnose default-config | grep -n -E 'image:|pauseImage:|timeout:'
```

Question: which folder for the bundle (it is big; `DIAG_DIR`)? I append `DIAG_DIR` when you name it.

### Plan: the bundle of the air-gapped management cluster

**Target:** the management cluster (`kommander`) and every pod in it.
**Result:** `support-bundle-<prefix>-<date>.tar.gz` in `DIAG_DIR`. A privileged pod runs on every node, also the control plane, for up to 600 s. The bundle contains all ConfigMap data, all pod logs, host names, and IPs; Secret **values** are not collected, only names and metadata. [pdf p.1050]

```bash
# CHANGES  (runs collector pods on every node; writes support-bundle-*.tar.gz in DIAG_DIR)
source ~/nkp-<mgmt>.env 2>/dev/null
cd "${DIAG_DIR:?}" && nkp diagnose --kubeconfig "$MGMT_KUBECONFIG" --bundle-name-prefix "$CLUSTER_NAME"
```

`<mgmt>` is the name of your management cluster: the file is `~/nkp-<mgmt>.env` with `CLUSTER_NAME` and `MGMT_KUBECONFIG`. Tell me the name and I write the exact path in the block.

With choice B, use the config file instead:

```bash
# CHANGES  (runs the collectors of the file; writes support-bundle-*.tar.gz in DIAG_DIR)
source ~/nkp-<mgmt>.env 2>/dev/null
cfg=''
: "${cfg:?}"
cd "${DIAG_DIR:?}" && nkp diagnose "$cfg" --kubeconfig "$MGMT_KUBECONFIG" --bundle-name-prefix "$CLUSTER_NAME"
```

UNKNOWN (A-22): whether `nkp diagnose` 2.19.0 reads a config file given as an argument — check `nkp diagnose --help`, and after a run the `tar -tzf` list shows the collector names of the file.

Useful flag: `--since 6h` limits the pod logs. [live 2.19.0]

### D3: check the bundle (I run this after, READ-ONLY)

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
cd "${DIAG_DIR:?}" && ls -lt ./*support-bundle-*.tar.gz | head -3
f="$(ls -t "$DIAG_DIR"/*support-bundle-*.tar.gz | head -1)"; tar -tzf "$f" | awk -F/ '{print $2}' | sort | uniq -c
tar -tzf "$f" | grep -E 'error\.txt$|pod-collector\.(json|log)$'
```

Expected folders: `cluster-info`, `cluster-resources`, `configmaps`, `node-diagnostics`, `pod-logs`, `secrets`, `version.yaml`. [pdf p.1050] No `node-diagnostics` → the node collection failed (pull error = the P5 problem, `timeout` = raise `timeout` in a config file). [pdf p.1054]

I do not open or print the bundle in the chat, except the `*-error.txt` and `pod-collector.log` files if the node collection failed. You send the `.tar.gz` to Nutanix support.

Waiting for: `DIAG_DIR`, the answer whether you can bring the v0.14.0 image in (choice A) or want choice B, and `yes` for the plan.

---

## nkp-troubleshooting T5

Skill files read: `skills/_shared/RULES.md`, `skills/nkp-troubleshooting/SKILL.md`, `skills/nkp-troubleshooting/references/controllers.md`, `skills/nkp-troubleshooting/references/rollouts.md`, `skills/nkp-troubleshooting/references/diagnose.md`

### What is happening

The create has not pivoted yet. Before the pivot, the CAPI objects and the controllers are on the **kind bootstrap cluster** on this host, not on a management cluster — so "no mgmt cluster yet" is expected, and the "waiting for control plane" phase means the control-plane machines are not Ready. [pdf p.22-23] There is nothing to look at on a management cluster; the evidence is on the bootstrap cluster and in the create log.

Known causes of a control plane that does not come up, in this order: [pdf p.1048, p.725-726]
1. the VM image name is wrong or the image is not in Prism Central;
2. the Prism Central credentials or role are wrong;
3. the subnet IP pool is full, or Prism Element has no free CPU/memory for one more VM;
4. the node cannot pull images (air-gapped registry), or cannot reach the API VIP;
5. the time on the nodes is wrong (NTP).

### B1: is the bootstrap cluster running? (I run this now)

```bash
# READ-ONLY
docker ps -a --filter name=konvoy-capi-bootstrapper --format '{{.Names}} {{.Status}} {{.Image}}'
docker image ls --format '{{.Repository}}:{{.Tag}}' | grep konvoy-bootstrap
```

On Podman use `podman`. The kind cluster name is `konvoy-capi-bootstrapper`. [live 2.19.0]

- No container and the create failed early → the operator-host requirements (4 CPU, 4 GB free, cgroups v2, container engine) are the cause; on an air-gapped site the image `mesosphere/konvoy-bootstrap:<version>` must be loaded or the create needs `--bootstrap-cluster-image`. [live 2.19.0]
- Container `Exited` → you read its log (it can be long, so you run it):

```bash
# USER-TERMINAL  (operator host; you run it and send me the last error lines)
docker logs --tail 100 konvoy-capi-bootstrapper-control-plane
```

### B2: find the bootstrap kubeconfig

```bash
# READ-ONLY
ls -l ./*bootstrap*.conf ~/.kube/config 2>/dev/null
kubectl config get-contexts
```

UNKNOWN (A-21): the kubeconfig file of the bootstrap cluster during `nkp create cluster --self-managed`. The guide uses `${CLUSTER_NAME}-bootstrap.conf` [pdf p.683]; a field run found a bootstrap context in `~/.kube/config`. A context or file with `konvoy-capi-bootstrapper` or `bootstrap` in the name is the bootstrap cluster — **confirm the path to me**, then I append `BOOTSTRAP_KUBECONFIG` to `~/nkp-site.env` (plan, one line).

### B3: read the create on the bootstrap cluster

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
: "${BOOTSTRAP_KUBECONFIG:?}"
kubectl --kubeconfig "$BOOTSTRAP_KUBECONFIG" get nodes
kubectl --kubeconfig "$BOOTSTRAP_KUBECONFIG" get pods -A --field-selector=status.phase!=Running,status.phase!=Succeeded
kubectl --kubeconfig "$BOOTSTRAP_KUBECONFIG" get clusters.cluster.x-k8s.io,kubeadmcontrolplanes,machines -A
```

Then R1/R2/R3 with `MGMT_KUBECONFIG` replaced by `BOOTSTRAP_KUBECONFIG` and `-A` instead of `-n "$WORKSPACE_NS"`. The provider log for a `Provisioning` machine is CAPX, on the bootstrap cluster:

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
ns='capx-system'; deploy='capx-controller-manager'; filter=''; where='bootstrap'; case "$where" in mgmt) kc="$MGMT_KUBECONFIG";; bootstrap) kc="$BOOTSTRAP_KUBECONFIG";; *) kc='';; esac
: "${ns:?}" "${deploy:?}" "${kc:?}"
kubectl --kubeconfig "$kc" -n "$ns" get deploy "$deploy" -o wide
kubectl --kubeconfig "$kc" -n "$ns" get pods -o wide
kubectl --kubeconfig "$kc" -n "$ns" logs "deploy/$deploy" --all-containers --since 2h --timestamps | grep -i -E "${filter:-error|fail|denied|timeout}" | tail -40
```

For a `Pending` machine without bootstrap data, read `capi-kubeadm-bootstrap-system/capi-kubeadm-bootstrap-controller-manager` the same way.

### Do not clean up yet

The create still owns the machines, and their VMs exist in Prism Central. `nkp delete bootstrap` removes only the kind cluster; the VMs stay and then **nothing tracks them**. [field] Before any cleanup, collect the evidence: the B3 output and a support bundle with the bootstrap kubeconfig (a `# CHANGES` block, planned with you):

```bash
# CHANGES  (writes support-bundle-*.tar.gz and bootstrap-support-bundle-*.tar.gz in DIAG_DIR)
source ~/nkp-site.env 2>/dev/null
cd "${DIAG_DIR:?}" && nkp diagnose --kubeconfig "$BOOTSTRAP_KUBECONFIG" --bootstrap-kubeconfig "$BOOTSTRAP_KUBECONFIG"
```

### Questions

1. Which folder did you run the create from (the `--dry-run` file and the create log are there)?
2. Send me the last 30 lines of the create output.
3. Which image name did you pass, and is that exact name in Prism Central?

Waiting for: the B1/B2/B3 outputs and the answers.

---

## nkp-troubleshooting T6

Skill files read: `skills/_shared/RULES.md`, `skills/nkp-troubleshooting/SKILL.md`, `skills/nkp-airgap/SKILL.md`, `skills/nkp-airgap/references/nodes.md`, `skills/nkp-cluster-lifecycle/references/maintenance.md`, `skills/nkp-cluster-lifecycle/references/variables.md`

### Diagnosis

`x509: certificate signed by unknown authority` on a **new** node means the node's containerd does not trust the certificate the mirror serves. The owner of this symptom is skill `nkp-airgap` (step 5 and its nodes file). [live 2.19.0] Two facts decide the fix:

- CAREN writes the registry files on each node **at bootstrap**. So a registry or CA change reaches only **new** machines. [live 2.19.0] Your new pool nodes got the **current** config from the NKPCluster; the old workers kept the old CA. That is why old nodes still work and new ones fail.
- The practical causes: `--registry-mirror-cacert` / `REGISTRY_CA_FILE` is the wrong file, an **incomplete chain** (root without intermediate), the mirror URL's path changed (needs `override_path = true` in `hosts.toml`), or the mirror answers with a certificate from another CA than the one in the file.

### Step 5 checks (I run this now)

```bash
# READ-ONLY
source ~/nkp-edge-02.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get nkpclusters "$CLUSTER_NAME" -o jsonpath='{..globalImageRegistryMirror.url}{"\n"}{..imageRegistries[*].url}{"\n"}'
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get kubeadmcontrolplane -l cluster.x-k8s.io/cluster-name="$CLUSTER_NAME" -o jsonpath='{range .items[*].spec.kubeadmConfigSpec.files[*]}{.path}{"\n"}{end}'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get pods -A | grep -E 'ImagePullBackOff|ErrImagePull' || echo "no image pull errors"
```

Line 1 must show the site mirror URL. The file list must contain `/etc/containerd/certs.d/_default/hosts.toml`, `/etc/containerd/certs.d/<registry-host>/ca.crt`, and `/etc/caren/containerd/patches/registry-config.toml`. [live 2.19.0]

Also which pods and which images fail:

```bash
# READ-ONLY
source ~/nkp-edge-02.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get pods -A -o wide | grep -E 'ImagePullBackOff|ErrImagePull'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" describe pod -n <ns> <pod> | tail -30
```

Give me the `Failed to pull image` line and the `x509` line; they name the registry host and path.

### On one failing node (you run this, over SSH as `konvoy`)

```bash
# USER-TERMINAL  (on a node; you run it over SSH)
sudo cat /etc/containerd/certs.d/_default/hosts.toml
sudo ls /etc/containerd/certs.d/
sudo cat /etc/caren/containerd/patches/registry-config.toml
sudo journalctl -u containerd --since "30 min ago" | grep -i -E 'pull|x509|401|403' | tail -20
```

`hosts.toml` must have `[host."https://<registry-host>/v2/<path>"]`, the `ca` path, `capabilities = ["pull", "resolve"]`, and `override_path = true` when the mirror URL has a path. [live 2.19.0] Never print `/etc/kubernetes/static-image-credentials.json` — it holds registry credentials.

Compare the CA on the node with the certificate the registry serves (you run this from the bastion):

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
h="${REGISTRY_URL#*://}"; h="${h%%/*}"; case "$h" in *:*) ;; *) h="$h:443";; esac; echo | openssl s_client -showcerts -connect "$h" 2>/dev/null | openssl x509 -noout -subject -issuer -fingerprint -sha256
openssl x509 -in "$REGISTRY_CA_FILE" -noout -subject -issuer -fingerprint -sha256
```

If the issuer of the served certificate is not in `REGISTRY_CA_FILE`, the file is wrong or incomplete — that is the bug, not the node.

### The fix (owner: `nkp-airgap`, which is installed)

1. Correct `REGISTRY_CA_FILE` to the full chain the registry admin gives you. Ask the registry admin to confirm the SHA-256 fingerprint.
2. Put the corrected CA into the cluster config so that new machines get it. The field is `clusterConfig.globalImageRegistryMirror` / `imageRegistries` (owner: `nkp-airgap`; the effect of a change is in `variables.md`, V5). This is a `# CHANGES` plan on the NKPCluster, with the step 3 flow: patch file, server dry run, plan, apply — I show it after step 1 tells me the current value.
3. The old workers keep the old CA. A registry mirror or CA change reaches only new machines [live 2.19.0], so the pool must roll. Question: do you want **only** the affected pool rolled, or all of them? A roll replaces nodes one by one (M4/R9) and needs one free VM and one free IP during the roll.

I will not run a node patch from the operator host. `nkp`/NKP owns the node files; a hand edit is lost at the next machine.

### Questions

1. Did the mirror URL, the path, or the certificate change **after** the pool was created? When?
2. Is the Harbor project path in `REGISTRY_URL` the same as in `hosts.toml` on the node?
3. Send me the two `openssl` outputs and the containerd journal lines.

---

## nkp-troubleshooting T7

Skill files read: `skills/_shared/RULES.md`, `skills/nkp-troubleshooting/SKILL.md`, `skills/nkp-troubleshooting/references/rollouts.md`, `skills/nkp-cluster-lifecycle/SKILL.md`, `skills/nkp-cluster-lifecycle/references/variables.md`, `skills/nkp-airgap/references/nodes.md`

### Answer: `rolloutAfter` will do nothing, and it is the wrong tool here

- In this CAPI API version the field is **`spec.rollout.after`** (an RFC3339 time). The old name `spec.rolloutAfter` is **dropped and has no effect**. [live 2.19.0]
- The **NKPCluster drops `rollout.after` from a pool**. [live 2.19.0] So it is a direct patch of a topology-owned object, and UNKNOWN (A-20): whether the topology controller keeps it. That is why it is the last resort, not the first.
- The right first move: a registry CA is written by CAREN into the machine at bootstrap, so the **config change itself** rolls the machines. [live 2.19.0] If you already fixed the CA in the cluster config, the pool should roll on its own — the question is why it did not.

### Step 1: read the current config and the rollout state (I run this now)

```bash
# READ-ONLY
source ~/nkp-prod-01.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get nkpcluster "$CLUSTER_NAME" -o jsonpath='{..globalImageRegistryMirror}{"\n"}{..imageRegistries}{"\n"}'
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get kubeadmcontrolplane -l cluster.x-k8s.io/cluster-name="$CLUSTER_NAME" -o jsonpath='{range .items[*].spec.kubeadmConfigSpec.files[*]}{.path}{"\n"}{end}'
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get machinedeployments,kubeadmcontrolplanes -l "cluster.x-k8s.io/cluster-name=$CLUSTER_NAME" -o custom-columns='NAME:.metadata.name,GEN:.metadata.generation,OBSERVED:.status.observedGeneration,REPLICAS:.status.replicas,READY:.status.readyReplicas,UPDATED:.status.updatedReplicas,AFTER:.spec.rollout.after'
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get nkpcluster "$CLUSTER_NAME" -o jsonpath='phase={.status.phase}{"\n"}{range .status.conditions[?(@.status!="True")]}{.type}={.status} {.reason}: {.message}{"\n"}{end}'
```

Done when: I know the mirror/CA value in the NKPCluster, whether `md-0` has `UPDATED` < `REPLICAS` (a roll in progress or not), and the NKPCluster phase.

### Step 2: if the config change did not roll the pool

The clean trigger is a topology change that the NKPCluster owns. Read the pool's `workerConfig` and change a field that replaces nodes (`variables.md`, V2) — for example `nutanix/machineDetails/additionalCategories`, or the CA value itself if it is not yet in the config. That is the step 3 flow: patch file → server dry run → plan → apply → watch.

If the config is already correct **and** the machines really did not roll, the last resort is R9. **Plan, dry run first:**

```bash
# READ-ONLY  (server dry run: the API server checks the patch and changes nothing)
source ~/nkp-prod-01.env 2>/dev/null
obj=''
: "${obj:?}"
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" patch "$obj" --type merge -p "{\"spec\":{\"rollout\":{\"after\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}}}" --dry-run=server -o jsonpath='{.spec.rollout}{"\n"}'
```

`obj` is `machinedeployment/<name>` from step 1 (the MachineDeployment of `md-0`, not the NKPCluster). The output must contain `"after"`.

**Plan for the real patch** (only after the dry run and after you accept the A-20 risk):

- Target: the MachineDeployment of `md-0` of `prod-01`.
- Result: CAPI replaces **every** machine of that pool, one by one. One more VM and one free IP are needed during the roll; PodDisruptionBudgets keep apps up, and a PDB with 0 allowed disruptions stops the drain. The NKPCluster may drop the field again (UNKNOWN A-20) — the dry run proves the API accepts it, not that the topology controller keeps it.

```bash
# CHANGES  (sets spec.rollout.after: CAPI replaces every machine of this object, one by one)
source ~/nkp-prod-01.env 2>/dev/null
obj=''
: "${obj:?}"
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" patch "$obj" --type merge -p "{\"spec\":{\"rollout\":{\"after\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}}}"
```

Then watch with the cluster-lifecycle step 3d block. Done when every machine of the pool has a new AGE and is `Running`, and the step 7 post-checks pass.

### Question

Was the CA fix made only in the **operator host** env file (`REGISTRY_CA_FILE`), or in the **NKPCluster** of `prod-01`? Only the second one reaches new machines. [live 2.19.0] Send me the step 1 output and I tell you which of the two paths we take.

---

## nkp-troubleshooting T8

Skill files read: `skills/_shared/RULES.md`, `skills/nkp-troubleshooting/SKILL.md`, `skills/nkp-troubleshooting/references/controllers.md`, `skills/nkp-troubleshooting/references/deletes.md`, `skills/nkp-cluster-lifecycle/references/maintenance.md`

### Answer: not in the skills

An etcd snapshot restore on the NKP control plane is **not in the skills**. The controller table says it directly: "Etcd repair is not in the skills." [live 2.19.0] I will not write a restore procedure from memory — etcd holds the whole cluster state, and a wrong restore ends the cluster.

What I can do, and what the skills do own:

### READ-ONLY checks I can run now

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get nkpcluster "$CLUSTER_NAME" -o custom-columns='PHASE:.status.phase,K8S:.status.kubernetesVersion,CLASS:.spec.capiCluster.topology.classRef.name'
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get nkpcluster "$CLUSTER_NAME" -o jsonpath='{range .status.conditions[?(@.status!="True")]}{.type}={.status} {.reason}: {.message}{"\n"}{end}'
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get kubeadmcontrolplanes,machines -l "cluster.x-k8s.io/cluster-name=$CLUSTER_NAME"
```

- If the API server still answers, the cluster is not in the state where a restore is the only option. Etcd health and member errors are the kubeadm-control-plane controller's log (`capi-kubeadm-control-plane-system`). [live 2.19.0]
- If the API server does **not** answer: the ladder sends us to `nkp diagnose` section "API server down" — the SSH fallback (`nkp diagnose ssh` with an inventory of `ansible_host`, `ansible_port`, `ansible_user`, `ansible_ssh_private_key_file`) collects node data without the API. [pdf p.1051-1052]

### The order the skills do give

1. **Do not delete control-plane Machines, the KubeadmControlPlane, or the NKPCluster to "fix" etcd.** Do not edit the CAPI `Cluster`. [pdf p.1048] `deletes.md` says: a removed finalizer skips the cleanup, and for a control plane the cleanup is the VM and the etcd member.
2. **Support bundle first**, so Nutanix support has the evidence: `nkp diagnose` is a `# CHANGES` command (privileged pod on every node, bundle with ConfigMap data and logs) — plan it with me, or with the bootstrap/SSH variant if the API is down. [pdf p.1049-1052]
3. **Ask Nutanix support for the etcd restore procedure** for NKP 2.19.0, with the bundle and the exact symptom. A control-plane certificate renewal or a control-plane machine replace (MHC, or a `clusterConfig.controlPlane` change) is the supported repair in the skills for a single unhealthy control-plane node — but it is **not** an etcd restore, and it does not bring back lost etcd data.
4. If the data is gone, the supported paths in the skills are: a Velero restore of the apps (skill `nkp-storage-backup` — **not installed** here, so: "Skill `nkp-storage-backup` is not installed."), or a rebuild of the cluster.

### Questions

1. What is the actual symptom — API server down, one etcd member unhealthy, or a restore after data loss?
2. Do you have an etcd snapshot, and from which time? Where is it (a node path, or a backup system)?
3. Is the cluster still serving the API? (`kubectl get --raw /readyz` with its kubeconfig)

Give me those answers and the output above; then the next step is the support bundle and Nutanix support, not a command from me.

---

## nkp-install E13

Skill files read: `skills/_shared/RULES.md`, `skills/nkp/SKILL.md`, `skills/nkp-install/SKILL.md`, `skills/nkp-install/references/preprovisioned.md`, `skills/nkp-airgap/SKILL.md`

### Provider: pre-provisioned hosts (SSH). Answers I need to confirm

1. Infrastructure → **pre-provisioned hosts** ([preprovisioned.md](preprovisioned.md)), not AHV. NKP does not make these machines; it configures them over SSH. [pdf p.765, p.792]
2. First cluster → **management cluster** → `--self-managed`.
3. Dark site with a Harbor mirror → site **registry mirror** mode, and `--airgapped`. [pdf p.713, p.722-723]
4. **License:** pre-provisioned is **Pro or Ultimate**. Starter supports only Nutanix AHV. [pdf p.27-28] Confirm which one you have.

### P1: confirm these before I write anything (you must say yes to each)

- 3 control-plane hosts: 4 cores, 16 GB memory, about 80 GB free for `/var/lib/kubelet` and `/var/lib/containerd`, 15% free on the root file system. [pdf p.767]
- 4 workers: 8 cores, 32 GiB memory, same disk rules. [pdf p.767]
- SSH works with an **unencrypted** private key; the user is `root` or has passwordless `sudo`. [pdf p.766, p.768]
- Swap is off; `firewalld` is stopped and disabled; the NKP ports are open. [pdf p.767]
- Local volumes: at least four volumes mounted under `/mnt/disks/` on each worker (the default storage is `localvolumeprovisioner`). [pdf p.767]
- Control-plane endpoint: no external LB, so the built-in VIP (kube-vip). The VIP is a static IPv4 on the Layer 2 network of the control-plane hosts, and the NIC name is the same on every control-plane host — you say `ens192`, which matches "use a VIP on ens192". [pdf p.80, p.787][live 2.19.0]
- Pod CIDR `192.168.0.0/16` and service CIDR `10.96.0.0/12` do not overlap the host subnet. [pdf p.788]
- **NTP is mandatory on an air-gapped site.** [pdf p.724]

### P2: the values I still need (then I append them, one block, after your `yes`)

| Name | File | Value |
|---|---|---|
| `CP_HOSTS` | `~/nkp-<cluster>.env` | the 3 control-plane IPs, comma-separated |
| `WORKER_HOSTS` | `~/nkp-<cluster>.env` | the 4 worker IPs, comma-separated |
| `CP_VIP` | `~/nkp-<cluster>.env` | the free VIP on `ens192` |
| `VIP_INTERFACE` | `~/nkp-<cluster>.env` | `ens192` (given) |
| `LB_IP_RANGE` | `~/nkp-<cluster>.env` | `<first>-<last>` for MetalLB, in the host subnet |
| `WORKSPACE_NS` | `~/nkp-<cluster>.env` | `default` — **not** `kommander`, for this provider [live 2.19.0][pdf p.768] |
| `SSH_USER` | `~/nkp-site.env` | `nkpadmin` (given) |
| `SSH_PRIVATE_KEY_FILE` | `~/nkp-site.env` | `/home/ops/.ssh/nkp` (given) |
| `BUNDLE_DIR` | `~/nkp-site.env` | the extracted 2.19.0 bundle folder |
| `REGISTRY_URL` | `~/nkp-site.env` | your Harbor URL including the project |
| `REGISTRY_CA_FILE` | `~/nkp-site.env` | the Harbor CA file |
| `NTP_SERVERS` | `~/nkp-site.env` | your NTP servers, comma-separated |
| cluster name | `~/nkp-<cluster>.env` | your choice, only `a-z 0-9 . -`; the inventory uses the same name [pdf p.777] |

Secrets — you add them, never in the chat:

```bash
# USER-TERMINAL  (you add the mirror pull account lines with an editor)
vi ~/nkp-site.env
```

`REGISTRY_MIRROR_USERNAME` and `REGISTRY_MIRROR_PASSWORD` (write `''` for the password if the mirror allows anonymous pulls).

### P2 checks (I run these)

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
for v in CLUSTER_NAME CP_HOSTS WORKER_HOSTS CP_VIP LB_IP_RANGE WORKSPACE_NS SSH_USER SSH_PRIVATE_KEY_FILE; do if [ -n "$(printenv "$v")" ]; then echo "set: $v"; else echo "MISSING: $v"; fi; done
```

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
for h in ${CP_HOSTS//,/ } ${WORKER_HOSTS//,/ }; do ssh -i "$SSH_PRIVATE_KEY_FILE" -o BatchMode=yes "$SSH_USER@$h" 'hostname; sudo -n true && echo sudo-ok; swapon --show | wc -l'; done
```

Done when each host prints its name, `sudo-ok`, and `0`. `Host key verification failed` → the host is not in known_hosts; you check the keys and add them (`ssh-keyscan`, a CHANGES command you run), then I re-run the block.

Also the bundle must hold the OS package bundle, because the hosts cannot download OS packages over SSH otherwise: [pdf p.71-73]

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
ls "$BUNDLE_DIR"/image-artifacts/ "$BUNDLE_DIR"/image-artifacts/images/
```

The 2.19.0 bundle has containerd files for each OS and the Kubernetes image files. [live 2.19.0] The OS **distribution packages** are not in the bundle — they are made with `nkp create package-bundle` on a connected host (skill `nkp-airgap`, OS images file, item P9). Confirm that file is in `$BUNDLE_DIR/image-artifacts`.

### P3: upload the artifacts to the 7 hosts (plan)

**Target:** all 7 hosts, over SSH.
**Result:** packages, containerd, and the Kubernetes images are copied and installed on each host. Nothing is clustered yet.

```bash
# CHANGES  (copies packages, containerd, and images to every host over SSH and installs them)
source ~/nkp-<cluster>.env 2>/dev/null
nkp upload image-artifacts \
  --ssh-host "$CP_HOSTS,$WORKER_HOSTS" \
  --ssh-username "$SSH_USER" \
  --ssh-private-key-file "$SSH_PRIVATE_KEY_FILE" \
  --artifacts-directory "$BUNDLE_DIR/image-artifacts"
```

Here `--ssh-username` is the **login** user (`nkpadmin`). On `nkp create cluster`, `--ssh-username` is a different thing — the user NKP creates on the nodes (default `konvoy`) — so I do not add it to the create. [live 2.19.0]

### P4: the inventory (plan)

**Target:** `~/nkp-<cluster>-inventory.yaml` (mode 600).
**Result:** a `PreprovisionedInventory` for `control-plane` and `md-0` with the host addresses and the SSH key reference. It creates nothing.

```bash
# CHANGES  (writes the inventory file of this cluster; creates nothing yet)
source ~/nkp-<cluster>.env 2>/dev/null
f="$HOME/nkp-$CLUSTER_NAME-inventory.yaml"
{ for pool in control-plane md-0; do
    hosts="$CP_HOSTS"; [ "$pool" = md-0 ] && hosts="$WORKER_HOSTS"
    printf -- '---\napiVersion: infrastructure.cluster.konvoy.d2iq.io/v1alpha1\nkind: PreprovisionedInventory\nmetadata:\n  name: %s-%s\n  namespace: %s\n  labels:\n    cluster.x-k8s.io/cluster-name: %s\n    clusterctl.cluster.x-k8s.io/move: ""\nspec:\n  hosts:\n' "$CLUSTER_NAME" "$pool" "$WORKSPACE_NS" "$CLUSTER_NAME"
    for h in ${hosts//,/ }; do printf '    - address: %s\n' "$h"; done
    printf '  sshConfig:\n    port: 22\n    user: %s\n    privateKeyRef:\n      name: %s-ssh-key\n      namespace: %s\n' "$SSH_USER" "$CLUSTER_NAME" "$WORKSPACE_NS"
  done; } > "$f"
```

Done when this prints `7`:

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
grep -c 'address:' "$HOME/nkp-$CLUSTER_NAME-inventory.yaml"
```

### P5: the create script (plan)

**Target:** `~/nkp-<cluster>-create.sh` (mode 700).
**Result:** one script with your values; it creates nothing until P6.

```bash
# CHANGES  (writes the create script of this cluster; creates nothing yet)
source ~/nkp-<cluster>.env 2>/dev/null
(umask 077 && cat > "$HOME/nkp-$CLUSTER_NAME-create.sh" <<'EOF'
nkp create cluster preprovisioned \
  --self-managed \
  --namespace "$WORKSPACE_NS" \
  --cluster-name "$CLUSTER_NAME" \
  --control-plane-endpoint-host "$CP_VIP" \
  ${VIP_INTERFACE:+--virtual-ip-interface "$VIP_INTERFACE"} \
  --pre-provisioned-inventory-file "$HOME/nkp-$CLUSTER_NAME-inventory.yaml" \
  --ssh-private-key-file "$SSH_PRIVATE_KEY_FILE" \
  ${REGISTRY_URL:+--registry-mirror-url "$REGISTRY_URL"} \
  ${REGISTRY_CA_FILE:+--registry-mirror-cacert "$REGISTRY_CA_FILE"} \
  ${REGISTRY_MIRROR_USERNAME:+--registry-mirror-username "$REGISTRY_MIRROR_USERNAME"} \
  ${REGISTRY_MIRROR_PASSWORD:+--registry-mirror-password "$REGISTRY_MIRROR_PASSWORD"} \
  ${NUTANIX_REGISTRY_TOKEN:+--nutanix-registry-username "$NUTANIX_REGISTRY_USERNAME" --nutanix-registry-password "$NUTANIX_REGISTRY_TOKEN"} \
  ${BUNDLE_DIR:+--bootstrap-cluster-image "$(ls "$BUNDLE_DIR"/konvoy-bootstrap-image-*.tar)"} \
  "$@"
EOF
)
```

Notes for the plan: this is air-gapped, so `--airgapped` belongs on the line — I add it when I write the file. The bootstrap image comes from the bundle file. The CLI takes the mirror password only as a flag, so other users on this host can see it in the process list. [live 2.19.0]

### P6: dry run, then create

```bash
# CHANGES  (writes the dry-run objects to a local file; creates no cluster)
source ~/nkp-<cluster>.env 2>/dev/null
umask 077 && bash "$HOME/nkp-$CLUSTER_NAME-create.sh" --dry-run --output yaml > "$PWD/$CLUSTER_NAME-dryrun.yaml"
```

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
grep -n -E '^kind:|^  name:|^  namespace:|address:|host:|cidrBlocks:|url:' "$PWD/$CLUSTER_NAME-dryrun.yaml"
```

The dry-run file holds Secrets; I never print it. Done when the dry run ends without an error and you agree with the shown lines.

Then the create (`# CHANGES`, planned and approved on its own). Target: the 7 hosts over SSH, plus a kind bootstrap cluster on this bastion for `--self-managed`, plus the pivot. Result: Kubernetes on the hosts, then the pivot, then Kommander. Default timeout 45m; for 7 hosts I add `--timeout 90m`. If it reports the Secret `<cluster>-ssh-key` is missing, there is a documented block that makes it in the management cluster, then we run the create again. [field]

### After the create (in order)

1. **Kubeconfig:** `ls -l "./$CLUSTER_NAME.conf"`, then (plan) append `MGMT_KUBECONFIG` to `~/nkp-site.env` and `CLUSTER_KUBECONFIG` to `~/nkp-<cluster>.env`. If the file is not there, I ask you for the path in the create output; the guide's fallback is `nkp get kubeconfig` (a CHANGES block). [pdf p.729, p.82]
2. **Kommander:** check `kommander-flux` and the HelmReleases; if they are not there, install Kommander — and on this provider the guide adds a Rook Ceph override first, because the local static provisioner cannot give `volumeMode: Block` PVCs. **Ask me which raw disks Ceph may use; Ceph deletes the data on them.** [pdf p.85-86]
3. **MetalLB:** the pre-provisioned provider has no `--load-balancer-ip-range` flag, so `LB_IP_RANGE` is applied afterwards with an `IPAddressPool` + `L2Advertisement` (a `# CHANGES` block, planned with you). [pdf p.83-84]
4. **Verify:** `nkp describe cluster` all Machine READY `True`, NKPCluster `Reconciled`, all nodes `Ready`, no pod outside `Running`/`Succeeded`, HelmRelease wait "condition met".
5. **UI access:** you run `nkp get dashboard` (a `# USER-TERMINAL` block: it shows the admin password). Use the static admin only to set up an identity provider. [pdf p.729]

UNKNOWN (P-14): the namespace of a pre-provisioned management cluster after the pivot. We check with `kubectl get clusters -A` and, if it moved, I append the real `WORKSPACE_NS`.

### Questions (the short list)

1. The 3 control-plane IPs and the 4 worker IPs.
2. The VIP and a free MetalLB range in the same subnet.
3. The cluster name.
4. `BUNDLE_DIR`, `REGISTRY_URL`, `REGISTRY_CA_FILE`, `NTP_SERVERS`.
5. Pro or Ultimate license?
6. Is the OS package bundle for Rocky 9.8 in `$BUNDLE_DIR/image-artifacts`?
7. Do all 7 hosts have 4 volumes under `/mnt/disks/` (at least on the workers)?

Waiting for: those answers and `yes` for the first plan (P1 confirmations consume nothing; the first CHANGES block is the upload in P3, or the env-file blocks earlier if you prefer).

---

## nkp-cluster-lifecycle L1

Skill files read: `skills/_shared/RULES.md`, `skills/nkp/SKILL.md`, `skills/nkp-cluster-lifecycle/SKILL.md`, `skills/nkp-cluster-lifecycle/references/maintenance.md`, `skills/nkp-cluster-lifecycle/references/variables.md`, `skills/nkp-troubleshooting/references/rollouts.md`

### Step 1 and 2 first, because of one trap: min/max

A pool that `nkp` made has **no `replicas` field**. Its size comes from the annotations `cluster.x-k8s.io/cluster-api-autoscaler-node-group-min-size` and `-max-size`, and the webhook rejects a `replicas` field on such a pool. [live 2.19.0] `nkp scale nodepool` **fails** when the new size is outside min and max: "greater than the configured max size annotation". [pdf p.934] So 6 must be inside your range, or we change min/max first.

### Step 1 (I run this now)

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" get nkpclusters -A -o custom-columns='NAMESPACE:.metadata.namespace,NAME:.metadata.name,CAPI:.status.capiClusterRef.name,PHASE:.status.phase,K8S:.status.kubernetesVersion,CLASS:.spec.capiCluster.topology.classRef.name,MGMT:.metadata.labels.kommander\.d2iq\.io/host'
```

`dev-01` in the default workspace: NAMESPACE is normally `kommander-default-workspace`. [live 2.19.0] If the cluster env file `~/nkp-dev-01.env` does not exist, I make it (plan, mode 600) with `CLUSTER_NAME`, `WORKSPACE_NS`, `CLUSTER_KUBECONFIG`, and I check all four names:

```bash
# READ-ONLY
source ~/nkp-dev-01.env 2>/dev/null
for v in CLUSTER_NAME WORKSPACE_NS CLUSTER_KUBECONFIG MGMT_KUBECONFIG; do if [ -n "$(printenv "$v")" ]; then echo "set: $v"; else echo "MISSING: $v"; fi; done
```

### Step 2: read the topology and the pool (I run this)

```bash
# READ-ONLY
source ~/nkp-dev-01.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get nkpcluster "$CLUSTER_NAME" -o go-template='{{range $i, $v := .spec.capiCluster.topology.variables}}variable {{$i}}: {{$v.name}}{{"\n"}}{{end}}controlPlane: replicas={{.spec.capiCluster.topology.controlPlane.replicas}}{{"\n"}}{{range $i, $p := .spec.capiCluster.topology.workers.machineDeployments}}pool {{$i}}: name={{$p.name}} class={{$p.class}} replicas={{or $p.replicas "-"}}{{with $p.metadata}}{{with .annotations}} min={{index . "cluster.x-k8s.io/cluster-api-autoscaler-node-group-min-size"}} max={{index . "cluster.x-k8s.io/cluster-api-autoscaler-node-group-max-size"}}{{end}}{{end}}{{"\n"}}{{end}}'
nkp get nodepools --cluster-name "$CLUSTER_NAME" --namespace "$WORKSPACE_NS" --kubeconfig "$MGMT_KUBECONFIG"
nkp describe cluster --cluster-name "$CLUSTER_NAME" --namespace "$WORKSPACE_NS" --kubeconfig "$MGMT_KUBECONFIG"
```

Done when: I have the pool index `i` of `md-0`, its current size, and its `min`/`max`.

### The plan: scale md-0 to 6

**Target:** workload cluster `dev-01`, pool `md-0`, on the management cluster.
**Result:** NKP adds 6 − (current) machines and VMs in Prism Central. `maxSurge`-style spare capacity is not needed for a pure scale-up, but each new node needs **one IP from the subnet pool and one VM slot** in the Prism Element cluster. A scale-up does not drain or replace the running nodes.

```bash
# CHANGES  (sets the size of one node pool; NKP adds or deletes machines and VMs)
source ~/nkp-dev-01.env 2>/dev/null
pool='md-0'; replicas='6'; nodes=''
: "${pool:?}" "${replicas:?}"
nkp scale nodepool "$pool" --replicas "$replicas" ${nodes:+--nodes-to-delete "$nodes"} --cluster-name "$CLUSTER_NAME" --namespace "$WORKSPACE_NS" --kubeconfig "$MGMT_KUBECONFIG"
```

- Set `nodes` only for a scale down (comma-separated node names). Not needed here. [pdf p.934]
- If `nkp` stops with "greater than the configured max size annotation": we first change the pool's `min`/`max` with the annotation patch (`maintenance.md`, M1) — a separate plan — and then run the scale again. UNKNOWN (P-08): whether `nkp scale nodepool` also changes the annotations; I check with the step 2 block after the scale.
- If `max` is already 6 or more with `min` < `max`, the cluster autoscaler is in charge of the size; scaling by hand is still allowed inside the range, but the autoscaler can move it again. [pdf p.935]

### Watch (step 3d)

```bash
# READ-ONLY
source ~/nkp-dev-01.env 2>/dev/null
capi=$(kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get nkpcluster "$CLUSTER_NAME" -o jsonpath='{.status.capiClusterRef.name}'); sleep 60
for c in RollingOut=False ScalingUp=False ScalingDown=False Remediating=False Available; do kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" wait "clusters.cluster.x-k8s.io/$capi" --for=condition="$c" --timeout=60m; done
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" wait "nkpclusters.clusters.nkp.nutanix.com/$CLUSTER_NAME" --for=jsonpath='{.status.phase}'=Reconciled --timeout=30m
nkp get nodepools --cluster-name "$CLUSTER_NAME" --namespace "$WORKSPACE_NS" --kubeconfig "$MGMT_KUBECONFIG"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get nodes
```

Done when each wait prints "condition met", `nkp get nodepools` shows DESIRED = READY with the new size, and all nodes are `Ready`. A wait that times out goes to skill `nkp-troubleshooting`.

### Questions

1. The current size of `md-0` and its `min`/`max` — or I read them in step 2.
2. Is 6 the final fixed size, or should the autoscaler range also change (for example `max=6`)? A fixed pool with `min=max=5` needs the annotation change first, or `nkp scale` stops.

Waiting for: the step 1/step 2 output and `yes` for the scale.
