# Batch 4 answers: nkp-gpu-ai

Each prompt is a separate conversation. All blocks follow `_shared/RULES.md` (mark on line 1, env source on line 2, approval before every CHANGES block). The operator host login shell is zsh, so blocks are run with bash.

---

## nkp-gpu-ai G1

**Skill files I read:** `skills/nkp/SKILL.md`, `skills/_shared/RULES.md`, `skills/nkp-gpu-ai/SKILL.md` (steps 1-4, Common failures), `skills/nkp-gpu-ai/references/nvidia.md` (N1, N2, N3, N4), `skills/nkp-platform-apps-gitops/SKILL.md` (step 1, step 2), `skills/nkp-platform-apps-gitops/references/overrides.md` (O1, O2, O3), `skills/nkp-cluster-lifecycle/references/variables.md` (V3 taints, V6 GPU pool).

Plan for this job: driver mode A (the image has the driver), DRA on (2.19 default), no sharing. That means **no values and no override ConfigMap**. Then I enable the app and test it with a ResourceClaim.

### Questions I would ask first (with the question tool)

1. "Is `~/nkp-ai-01.env` in place for cluster `ai-01`?"
   - "Yes, it has `CLUSTER_KUBECONFIG` and `WORKSPACE_NS`" (Recommended)
   - "No" — then I ask for the cluster name and the workspace namespace, and I write the file in a later reply.
2. "Which taint key does the GPU node pool have?"
   - "`nvidia.com/gpu`" (Recommended)
   - "Another key" — then I ask for the key, and the operator needs extra tolerations (N4).
3. "The node image has the NVIDIA driver. Is that correct?" (mode A, driver stays off)
   - "Yes, NIB built the image with the driver" (Recommended)
   - "No, the nodes have no driver" — then the mode is B (precompiled driver, N2).

I do not guess the workspace namespace. Workspace `ml` is the **name**; `kubectl` needs the **namespace** (`WORKSPACE_NS`).

### Step 1: read the GPU state (READ-ONLY)

```bash
# READ-ONLY
source ~/nkp-ai-01.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n kommander get licenses.kommander.mesosphere.io -o jsonpath='{.items[*].status.dkpLevel}{"\n"}'
kubectl --kubeconfig "$MGMT_KUBECONFIG" get clusterapps | grep -E 'NAME|gpu|nvidia|amd'
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get appdeployments | grep -E 'NAME|gpu|nvidia|amd'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get nodes -o custom-columns='NAME:.metadata.name,KERNEL:.status.nodeInfo.kernelVersion,OS:.status.nodeInfo.osImage,GPU:.status.allocatable.nvidia\.com/gpu,TAINTS:.spec.taints[*].key'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get nodes -L feature.node.kubernetes.io/pci-10de.present,nvidia.com/gpu.product,nvidia.com/vgpu.present,nvidia.com/mig.config.state
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get pods -A -o wide | grep -E 'NAMESPACE|nvidia'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get deviceclasses,resourceslices
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get helmreleases -A -o custom-columns='NS:.metadata.namespace,NAME:.metadata.name,READY:.status.conditions[?(@.type=="Ready")].status,FROM:.spec.valuesFrom[*].name' | grep -E 'NS|nvidia'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get clusterpolicies.nvidia.com -o jsonpath='{range .items[*]}{.metadata.name} devicePlugin={.spec.devicePlugin.enabled} driver={.spec.driver.enabled} state={.status.state}{"\n"}{end}'
```

What I look for:
- Tier `Pro`. [live 2.19.0]
- The ClusterApp `nvidia-gpu-operator-26.3.3` in the list. I use the real name from this output as `app` in step 3. [live 2.19.0]
- The GPU nodes show `PCI-10DE.PRESENT` `true`. No `true`: the VM has no GPU (skill `nkp-cluster-lifecycle`, V6) or NFD did not label the node.
- The TAINTS column shows the pool taint key. It must be `nvidia.com/gpu`. Another key: the operator DaemonSets and the DRA plugin do not start on those nodes. [live 2.19.0]
- `clusterpolicies`: "the server doesn't have a resource type" means the operator is not installed yet. That is expected now.

### Step 2: plan (no values, no override)

| Question | Answer |
|---|---|
| 1. Driver mode | **A** (the image has the driver) → keep the default `driver.enabled: false`. Do not add `driver.enabled: true`; that would make the operator install a driver that overwrites the one in the image. |
| 2. GPU access | **DRA** (the 2.19 default). |
| 3. Sharing | **None.** |
| 4. vGPU | No → no vGPU token operator. |
| 5. Taint | Must be `nvidia.com/gpu` (question 2). |

Result: no values file, no override ConfigMap, no `--config-overrides` flag. [live 2.19.0]

The result of this change: NKP installs the app in workspace `ml`. The app makes two HelmReleases on `ai-01`: `nvidia-gpu-operator` and `nvidia-dra-driver`. The pods of both run in the workspace namespace on `ai-01` (`nvidia-gpu-operator` is the **guide** namespace, not a fact for this install). [live 2.19.0]

### Step 3: enable the app (skill `nkp-platform-apps-gitops`, step 2)

This block is CHANGES. **First the dry run.** It prints the AppDeployment and creates nothing. [live 2.19.0] I stop for "yes" for the dry run too.

```bash
# CHANGES  (client dry run only: prints the AppDeployment; creates nothing)
source ~/nkp-ai-01.env 2>/dev/null
name='nvidia-gpu-operator'; app='nvidia-gpu-operator-26.3.3'; ws=$(kubectl --kubeconfig "$MGMT_KUBECONFIG" get workspaces -o jsonpath="{.items[?(@.status.namespaceRef.name==\"$WORKSPACE_NS\")].metadata.name}")
: "${name:?}" "${app:?}" "${ws:?}"
nkp create appdeployment "$name" --app "$app" --workspace "$ws" --kubeconfig "$MGMT_KUBECONFIG" --dry-run
```

- `app` is the ClusterApp name from step 1. If step 1 shows another version (for example a later 26.x), I use that name.
- The AppDeployment name is `nvidia-gpu-operator`. It is **not** `nvidia-gpu-operator-gpu-operator-version` (that text is the guide's placeholder). [pdf p.615]
- No `--config-overrides`. No `--clusters`: the license is Pro, and "some clusters" (`--clusters`) is Ultimate only. [pdf p.321]

Target: the management cluster, namespace `$WORKSPACE_NS`. The result: the AppDeployment exists, and NKP installs the app on every cluster of the workspace.

Then, after "yes", the same block without `--dry-run`:

```bash
# CHANGES  (creates the AppDeployment; NKP installs the app on the target clusters)
source ~/nkp-ai-01.env 2>/dev/null
name='nvidia-gpu-operator'; app='nvidia-gpu-operator-26.3.3'; ws=$(kubectl --kubeconfig "$MGMT_KUBECONFIG" get workspaces -o jsonpath="{.items[?(@.status.namespaceRef.name==\"$WORKSPACE_NS\")].metadata.name}")
: "${name:?}" "${app:?}" "${ws:?}"
nkp create appdeployment "$name" --app "$app" --workspace "$ws" --kubeconfig "$MGMT_KUBECONFIG"
```

### Check

```bash
# READ-ONLY
source ~/nkp-ai-01.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get helmreleases -A | grep -E "NAME|nvidia"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get deviceclasses,resourceslices
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get pods -A -o wide | grep -E 'NAMESPACE|nvidia'
```

Done when: the HelmReleases `nvidia-gpu-operator` and `nvidia-dra-driver` show READY `True`, the operator pods run, the validator pods are `Completed`, `deviceclasses` shows `gpu.nvidia.com`, and `resourceslices` shows the GPUs of each node. [live 2.19.0] A driver install can take time; mode A has no driver build.

### Step 4: test a GPU pod (DRA, after "yes")

This block is CHANGES. The result: a ResourceClaimTemplate and one test pod in namespace `default`; the pod gets one GPU.

```bash
# CHANGES  (creates a ResourceClaimTemplate and a test pod in namespace default; the pod gets one GPU)
source ~/nkp-ai-01.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n default apply -f - <<'YAML'
apiVersion: resource.k8s.io/v1
kind: ResourceClaimTemplate
metadata:
  name: single-gpu
spec:
  spec:
    devices:
      requests:
      - name: gpu
        exactly:
          deviceClassName: gpu.nvidia.com
---
apiVersion: v1
kind: Pod
metadata:
  name: gpu-test
spec:
  restartPolicy: Never
  resourceClaims:
  - name: gpu
    resourceClaimTemplateName: single-gpu
  containers:
  - name: cuda
    image: nvcr.io/nvidia/k8s/cuda-sample:vectoradd-cuda12.5.0
    command: ["nvidia-smi", "-q"]
    resources:
      claims:
      - name: gpu
  tolerations:
  - key: nvidia.com/gpu
    operator: Exists
    effect: NoSchedule
YAML
```

I do **not** test with `nvidia.com/gpu: 1` limits: this cluster is in DRA mode, and whether limits work in DRA mode is open (D-42). A pod with limits can stay `Pending` with `Insufficient nvidia.com/gpu`.

Read the result (READ-ONLY): `kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n default logs gpu-test | head -40`.

Then I remove the test (CHANGES, plan and "yes"): `kubectl ... -n default delete pod gpu-test`, then the same with `delete resourceclaimtemplate single-gpu`.

**Next:** wait for the answers to the three questions, run step 1, then show the step 3 plan and stop for "yes".

---

## nkp-gpu-ai G2

**Skill files I read:** `skills/nkp/SKILL.md`, `skills/_shared/RULES.md`, `skills/nkp-gpu-ai/SKILL.md` (step 1-3, Common failures), `skills/nkp-gpu-ai/references/nvidia.md` (N1, N2, N8), `skills/nkp-platform-apps-gitops/SKILL.md` (step 2), `skills/nkp-platform-apps-gitops/references/overrides.md` (O2, O3), `skills/nkp-airgap/references/catalogs.md` (C3), `skills/nkp-airgap/SKILL.md` (step 4A/4B, step 5), `skills/nkp-cluster-lifecycle/references/variables.md` (V6).

Yes, mode B is the precompiled driver that the operator installs. But for this cluster there is a problem with the driver image. I show the values first, then the check that decides if the values can work.

### Questions I would ask first (with the question tool)

1. "Is `~/nkp-mgmt-01.env` in place for the management cluster `mgmt-01`?" (on the management cluster `WORKSPACE_NS` is `kommander`)
   - "Yes" (Recommended)
   - "No" — I ask for the values and write the file in a later reply.
2. "The site is air-gapped. Which registry mode does it use?"
   - "Site registry mirror (`REGISTRY_URL`)" (Recommended)
   - "Internal registry mirror (the cluster registry)"
3. "If there is no driver image for the node kernel, which way do you want?"
   - "Get `nvcr.io/nvidia/driver:580-<kernel>-<os>` on a connected host and push it" (Recommended)
   - "Driver mode A: build a GPU Ubuntu image with NIB"
   - "Stop and decide later"

### The values (N2, the guide values)

```yaml
driver:
  enabled: true
  usePrecompiled: true
  version: 580
  kernelModuleType: auto
  image: driver
nvidiaDriverRoot: /run/nvidia/driver
```

- `driver.*` goes to the GPU operator chart. `nvidiaDriverRoot` goes to the DRA driver chart. [live 2.19.0]
- `/run/nvidia/driver` is only for mode B. The default `/` is for a driver in the node image (mode A).
- NKP supports driver 580.x. [pdf p.607]

### Step 1: does the bundle have the driver image for the node kernel? (READ-ONLY)

```bash
# READ-ONLY
source ~/nkp-mgmt-01.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get nodes -o custom-columns='NAME:.metadata.name,KERNEL:.status.nodeInfo.kernelVersion,OS:.status.nodeInfo.osImage'
repo='nvidia/driver'
for b in "$BUNDLE_DIR"/container-images/kommander-image-bundle-*.tar; do tar -tf "$b" | sed -n "s#^docker/registry/v2/repositories/$repo/_manifests/tags/\([^/]*\)/current/link\$#\1#p"; done
```

The result for a 2.19.0 Nutanix Ubuntu 24.04 pool (from the skills):
- The nodes run kernel `6.8.0-124-generic`. [live 2.19.0]
- The bundle has only these driver images: [live 2.19.0]

```text
nvcr.io/nvidia/driver:580-5.15.0-176-generic-ubuntu22.04
nvcr.io/nvidia/driver:580-6.8.0-111-generic-ubuntu24.04
nvcr.io/nvidia/driver:595-6.8.0-134-generic-ubuntu24.04   (NKP Metal Ubuntu 24.04)
```

**No bundle image matches `6.8.0-124-generic`.** The operator asks for `driver:580-6.8.0-124-generic-ubuntu24.04`. NVIDIA publishes that tag, but the bundle does not have it. [field]

UNKNOWN (D-41): whether driver mode B works on the 2.19.0 Nutanix Ubuntu images with only the bundle images (the kernel and the image tags differ). Find out with: `source ~/nkp-mgmt-01.env 2>/dev/null && kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get pods -A -o custom-columns='NAME:.metadata.name,IMAGE:.spec.containers[*].image,STATUS:.status.phase' | grep -E 'NAME|nvidia-driver'`.

The symptom of this mismatch is a driver pod in `ImagePullBackOff` (Common failures table).

### Step 2: choose one way (I stop here for your decision)

1. **Mode A** — a GPU image that has the driver, made with NIB (N1, `skills/nkp-airgap/references/os-images.md` O3). Then no `driver.*` values and no `nvidiaDriverRoot`.
2. **Mode B with a pushed image** — the user gets `nvcr.io/nvidia/driver:580-6.8.0-124-generic-ubuntu24.04` on a connected host, makes a bundle, and pushes it (skill `nkp-airgap`, `catalogs.md` C3, then SKILL.md step 4A or 4B).

I do not change the node kernel. A kernel change is not a supported way to fix this.

### Step 3: the override ConfigMap (only if you choose 2, and only after the push)

The two charts have no value names in common. The `nvidia-dra-driver` HelmRelease reads **only** the ConfigMap named `nvidia-gpu-operator-config-overrides`. [live 2.19.0] The guide name `nvidia-gpu-operator-overrides` [pdf p.615] reaches only the operator, so `nvidiaDriverRoot` would not reach the DRA driver and `resourceslices` would stay empty.

1. Write the values file (CHANGES, plan and "yes", then I run it). Skill `nkp-platform-apps-gitops`, `overrides.md` O3 item 1, with `APP_ID='nvidia-gpu-operator'`:

```bash
# CHANGES  (writes the values file on the operator host; changes no cluster)
source ~/nkp-mgmt-01.env 2>/dev/null
APP_ID='nvidia-gpu-operator'
f="$HOME/$CLUSTER_NAME-$APP_ID-values.yaml"
(umask 077 && cat > "$f" <<'VALUES'
driver:
  enabled: true
  usePrecompiled: true
  version: 580
  kernelModuleType: auto
  image: driver
nvidiaDriverRoot: /run/nvidia/driver
VALUES
)
```

2. Check the YAML syntax (READ-ONLY, mandatory). A good file gives `apiVersion not set, kind not set`:

```bash
# READ-ONLY
source ~/nkp-mgmt-01.env 2>/dev/null
APP_ID='nvidia-gpu-operator'
kubectl --kubeconfig "$MGMT_KUBECONFIG" create --dry-run=client -f "$HOME/$CLUSTER_NAME-$APP_ID-values.yaml" 2>&1 | head -3
```

3. Server dry run of the ConfigMap (READ-ONLY, changes nothing):

```bash
# READ-ONLY  (server dry run: changes nothing)
source ~/nkp-mgmt-01.env 2>/dev/null
APP_ID='nvidia-gpu-operator'; cm='nvidia-gpu-operator-config-overrides'
: "${cm:?}"
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" create configmap "$cm" --from-file=values.yaml="$HOME/$CLUSTER_NAME-$APP_ID-values.yaml" --dry-run=client -o yaml | kubectl --kubeconfig "$MGMT_KUBECONFIG" apply --dry-run=server -f -
```

4. Enable the app, then apply the ConfigMap (O3 item 4). The AppDeployment names the ConfigMap; Kommander waits for it. [pdf p.350] Then, after "yes", this block changes the cluster:

```bash
# CHANGES  (creates or replaces the override ConfigMap and sets it on the AppDeployment)
source ~/nkp-mgmt-01.env 2>/dev/null
APP_ID='nvidia-gpu-operator'; cm='nvidia-gpu-operator-config-overrides'
: "${cm:?}"
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" create configmap "$cm" --from-file=values.yaml="$HOME/$CLUSTER_NAME-$APP_ID-values.yaml" --dry-run=client -o yaml | kubectl --kubeconfig "$MGMT_KUBECONFIG" apply -f -
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" patch appdeployment "$APP_ID" --type merge -p "{\"spec\":{\"configOverrides\":{\"name\":\"$cm\"}}}"
```

Enable order: skill `nkp-platform-apps-gitops` step 2 with `name` `nvidia-gpu-operator`, `app` `nvidia-gpu-operator-26.3.3` (from step 1 of `nkp-gpu-ai`), `--config-overrides nvidia-gpu-operator-config-overrides`. The server dry run of the AppDeployment passes before the ConfigMap exists. [live 2.19.0]

5. Check:
   - `kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get helmreleases -A | grep nvidia` → both HelmReleases READY `True`, and the DRA one shows `nvidia-gpu-operator-config-overrides` in `valuesFrom`.
   - `kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get resourceslices` → the GPUs.
   - The driver pod image tag matches the node kernel.
   - The first driver install can take 10 minutes or more. [field]

For a Kubernetes upgrade later, the new node image has a new kernel: check the registry again before the upgrade (N8).

**Next:** the answer to question 3. If you choose 2, I run step 1 and show the push plan; the values and the ConfigMap wait until the driver image is in the registry.

---

## nkp-gpu-ai G3

**Skill files I read:** `skills/nkp/SKILL.md`, `skills/_shared/RULES.md`, `skills/nkp-gpu-ai/SKILL.md` (step 1-3, Common failures), `skills/nkp-gpu-ai/references/nvidia.md` (N3, N4, D-40), `skills/nkp-platform-apps-gitops/SKILL.md` (step 2), `skills/nkp-platform-apps-gitops/references/overrides.md` (O1, O2, O3, O5).

I cannot apply this without your "yes". "Just apply it" is not "yes": this change replaces the GPU app values on every cluster of the workspace, and it moves pods from claims to extended resources. I show the full change, then stop.

### What this change does

- Time-slicing in these skills needs the **device plugin**. With the device plugin, DRA must be off for the same app on the same nodes. DRA and the device plugin must not both serve GPUs on one node. [pdf p.610][live 2.19.0]
- So the values turn the device plugin on and the DRA driver off (`resources.gpus`, `resources.computeDomains`, `gpuResourcesEnabledOverride`, `webhook`). [live 2.19.0]
- Pods then ask with `nvidia.com/gpu: 1` in `resources.limits`, not with a ResourceClaim. Any workload that already uses a `gpu.nvidia.com` claim stops to be schedulable.
- A node with 1 GPU then shows `nvidia.com/gpu: 4`. Time-slicing gives no memory isolation between pods. [field]
- The time-slicing block goes under `devicePlugin:` of the GPU operator values. It does **not** go under the DRA driver values. The chart makes the `time-slicing-config` ConfigMap. [live 2.19.0]

### Questions I would ask first (with the question tool)

1. "Is `~/nkp-ai-01.env` in place for cluster `ai-01`?" — "Yes" (Recommended) / "No".
2. "This is a workspace override: every cluster of workspace `ml` gets it. OK?"
   - "Yes, all clusters of the workspace" (Recommended)
   - "Only `ai-01`" — not possible with a workspace override; a per-cluster override is Ultimate only [pdf p.321].
3. "Do any GPU workloads on `ai-01` use DRA claims now?" — "No" (Recommended) / "Yes, I list them" (then we plan the move to limits first).

### The full values file (O3 item 1)

```yaml
devicePlugin:
  enabled: true
  config:
    create: true
    name: time-slicing-config
    default: any
    data:
      any: |-
        version: v1
        flags:
          migStrategy: none
        sharing:
          timeSlicing:
            resources:
            - name: nvidia.com/gpu
              replicas: 4
gpuResourcesEnabledOverride: false
resources:
  gpus:
    enabled: false
  computeDomains:
    enabled: false
webhook:
  enabled: false
```

`replicas: 4` is your value (4 pods for each GPU). Do not mix time-slicing and MIG on the same GPU unless you have a tested config; that is not in the skills.

### Step 1: read the current override (READ-ONLY, O2)

```bash
# READ-ONLY
source ~/nkp-ai-01.env 2>/dev/null
APP_ID='nvidia-gpu-operator'
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get appdeployment "$APP_ID" -o jsonpath='app={.spec.appRef.name}{"\n"}workspace-override={.spec.configOverrides.name}{"\n"}{range .spec.clusterConfigOverrides[*]}cluster-override={.configMapName} for {.clusterSelector}{"\n"}{end}'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get helmreleases -A -o custom-columns='NS:.metadata.namespace,NAME:.metadata.name,FROM:.spec.valuesFrom[*].name' | grep -E "NS|$APP_ID"
```

If an override exists, its values go into the new file: O3 item 4 **replaces** the whole ConfigMap. If it shows `cluster-override=...-kommander-overrides`, I tell you before we change it (O1 slot 3).

### The plan (CHANGES; I stop before each step)

1. Write the values file on the operator host:

```bash
# CHANGES  (writes the values file on the operator host; changes no cluster)
source ~/nkp-ai-01.env 2>/dev/null
APP_ID='nvidia-gpu-operator'
f="$HOME/$CLUSTER_NAME-$APP_ID-values.yaml"
(umask 077 && cat > "$f" <<'VALUES'
devicePlugin:
  enabled: true
  config:
    create: true
    name: time-slicing-config
    default: any
    data:
      any: |-
        version: v1
        flags:
          migStrategy: none
        sharing:
          timeSlicing:
            resources:
            - name: nvidia.com/gpu
              replicas: 4
gpuResourcesEnabledOverride: false
resources:
  gpus:
    enabled: false
  computeDomains:
    enabled: false
webhook:
  enabled: false
VALUES
)
```

2. YAML syntax check (READ-ONLY; a good file gives `apiVersion not set, kind not set`):

```bash
# READ-ONLY
source ~/nkp-ai-01.env 2>/dev/null
APP_ID='nvidia-gpu-operator'
kubectl --kubeconfig "$MGMT_KUBECONFIG" create --dry-run=client -f "$HOME/$CLUSTER_NAME-$APP_ID-values.yaml" 2>&1 | head -3
```

3. Server dry run of the ConfigMap (READ-ONLY, changes nothing):

```bash
# READ-ONLY  (server dry run: changes nothing)
source ~/nkp-ai-01.env 2>/dev/null
APP_ID='nvidia-gpu-operator'; cm='nvidia-gpu-operator-config-overrides'
: "${cm:?}"
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" create configmap "$cm" --from-file=values.yaml="$HOME/$CLUSTER_NAME-$APP_ID-values.yaml" --dry-run=client -o yaml | kubectl --kubeconfig "$MGMT_KUBECONFIG" apply --dry-run=server -f -
```

4. Apply. Target: the **management cluster**, namespace `$WORKSPACE_NS`. Result: the ConfigMap `nvidia-gpu-operator-config-overrides` is replaced, the AppDeployment points to it, and every cluster of workspace `ml` gets the new values. The GPU operator pods restart, the DRA driver HelmRelease stops to serve GPUs, and pods need `nvidia.com/gpu` limits.

```bash
# CHANGES  (creates or replaces the override ConfigMap and sets it on the AppDeployment)
source ~/nkp-ai-01.env 2>/dev/null
APP_ID='nvidia-gpu-operator'; cm='nvidia-gpu-operator-config-overrides'
: "${cm:?}"
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" create configmap "$cm" --from-file=values.yaml="$HOME/$CLUSTER_NAME-$APP_ID-values.yaml" --dry-run=client -o yaml | kubectl --kubeconfig "$MGMT_KUBECONFIG" apply -f -
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" patch appdeployment "$APP_ID" --type merge -p "{\"spec\":{\"configOverrides\":{\"name\":\"$cm\"}}}"
```

**I stop here. Type "yes" and I run steps 1-4.**

### Check after "yes" (READ-ONLY)

```bash
# READ-ONLY
source ~/nkp-ai-01.env 2>/dev/null
APP_ID='nvidia-gpu-operator'
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get appdeployment "$APP_ID" -o jsonpath='{range .status.clusters[*]}{.name}{"\t"}{range .conditions[*]}{.type}={.status} {end}{"\n"}{end}'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get helmreleases -A | grep -E "NAME|$APP_ID"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get nodes -L nvidia.com/gpu.replicas,nvidia.com/gpu.sharing-strategy -o custom-columns='NAME:.metadata.name,GPU:.status.allocatable.nvidia\.com/gpu'
```

Done when: `AppDeploymentEnabled=True AppDeploymentInstanceSynced=True`, the HelmRelease is READY `True` with a new release number, and a 1-GPU node shows `nvidia.com/gpu: 4` with the sharing labels.

On a workload cluster, also check D-40: the `nvidia-dra-driver` HelmRelease must show `nvidia-gpu-operator-config-overrides` in its values, and `kubectl get deviceclasses` must show no `gpu.nvidia.com`. If the DRA driver still serves GPUs, both modes run on the same nodes. Then I stop and tell you.

A bad result after the apply is an override problem: `overrides.md` O5, then the HelmRelease reset in `nkp-platform-apps-gitops` step 3.

**Next:** your "yes". No command ran in this reply.

---

## nkp-gpu-ai G4

**Skill files I read:** `skills/nkp/SKILL.md`, `skills/_shared/RULES.md`, `skills/nkp-gpu-ai/SKILL.md` (step 1-4), `skills/nkp-gpu-ai/references/nvidia.md` (N1, N3, N5, N6), `skills/nkp-gpu-ai/references/ai-apps.md` (A1 order), `skills/nkp-airgap/references/os-images.md` (O3, `--vgpu-runfile`), `skills/nkp-cluster-lifecycle/references/variables.md` (V6), `skills/nkp-platform-apps-gitops/SKILL.md` (step 2), `skills/nkp-platform-apps-gitops/references/overrides.md` (O3).

### The order (N6). Do not change it.

1. **A vGPU image** — NIB with `--vgpu-runfile` (N1; the build block is `skills/nkp-airgap/references/os-images.md` O3). Driver mode A. The vGPU **host** driver on AHV must match the runfile. [pdf p.608-609]
   - On Prism Central 7.6 or later use `--gpu-profile-name "$GPU_PROFILE"`. `--gpu-name` is hidden and deprecated for PC 7.6+ (it is only for PC 7.5). The two flags are mutually exclusive. [live 2.19.0][pdf p.614]
2. **A license server that the nodes can reach** — the NVIDIA cloud license server (needs internet) or a **delegated license server (DLS)** on site. In an air gap, only a DLS works. [pdf p.617][field]
3. **The vGPU token operator app — before the vGPU node pool.** [pdf p.611, p.614]
4. **The vGPU node pool** — skill `nkp-cluster-lifecycle` V6, `--gpu-profile-name`, with the taint. [pdf p.614]
5. **The GPU operator** — driver mode A, DRA on (default). [live 2.19.0]

MIG does not work with vGPU. Nutanix does not support MIG profiles on vGPU VMs. [pdf p.612-613]

### Questions I would ask first (with the question tool)

1. "Is `/home/me/token.tok` the vGPU client configuration token file, mode 600?" — the answer goes into `VGPU_TOKEN_FILE`.
   - "Yes, and it is mode 600" (Recommended)
   - "Yes, but the mode is different" — then `chmod 600` first, on your side.
2. "Which namespace is the vGPU token operator app in on `vdi-01`?" — I set `ns` to it.
   - "The `WORKSPACE_NS` of `~/nkp-vdi-01.env`" (Recommended)
   - "Another namespace" — I ask for it.
3. "What does Prism Central report for the A40-4C profile — is this PC 7.6 or later?"
   - "PC 7.6 or later → `--gpu-profile-name`" (Recommended)
   - "PC 7.5 → `--gpu-name`"
4. "Which value do I append as `GPU_PROFILE`?" — I ask for the exact name from Prism Central (rule 4: no guess).

I confirm the two values first and append them in my next reply; I do not write `VGPU_TOKEN_FILE` now. I never print the token file, and the token text never goes into the chat or into a values file.

### The token operator (N6, step 3 of the order)

The chart needs a Secret with the key `client_configuration_token.tok` in the namespace of the app on the target cluster. [field] Step 1 of that section: you copy the `.tok` file to the operator host and run `chmod 600` on it.

**This block is CHANGES. Target: cluster `vdi-01`, the app namespace. Result: the Secret `vgpu-client-token` is created or replaced with your token file; the token never shows on the screen.** I stop for "yes". `ns` stays empty with its `:?` guard until you answer question 2.

```bash
# CHANGES  (creates or replaces the Secret vgpu-client-token with the vGPU token on the target cluster)
source ~/nkp-vdi-01.env 2>/dev/null
ns=''; : "${ns:?}" "${VGPU_TOKEN_FILE:?}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" create secret generic vgpu-client-token --from-file=client_configuration_token.tok="$VGPU_TOKEN_FILE" --dry-run=client -o yaml | kubectl --kubeconfig "$CLUSTER_KUBECONFIG" apply -f -
```

Then enable the app: skill `nkp-platform-apps-gitops` step 2, `name` `vgpu-token-operator`, `app` `vgpu-token-operator-1.0.8` (confirm the ClusterApp name in step 1 of `nkp-gpu-ai`), with an override ConfigMap (O3, `APP_ID` `vgpu-token-operator`, a new name such as `vgpu-token-operator-overrides-ws`):

```yaml
vgpuTokenObjects:
  - tokenName: vgpu-token
    tokenSecretName: vgpu-client-token
```

The chart makes a `VGPUToken` (`vgpu-token.nutanix.com/v1alpha1`). Its default node selector is `nvidia.com/vgpu.present: "true"`. The token goes to `/etc/nvidia/ClientConfigToken/` on the node. [live 2.19.0] That label comes from the GPU operator GFD, so the token reaches the nodes only after step 5 of the order.

UNKNOWN (D-46): whether the NKP UI field of the vGPU token operator (the token text) makes the same Secret and `VGPUToken` as the chart values. Find out with: `source ~/nkp-vdi-01.env 2>/dev/null && kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get vgputokens -A -o yaml | grep -E '^ +(name|tokenSecretRef|hostDirectoryPath):'` after a UI enable. I use the chart values, not the UI field, until this is closed.

### Check (READ-ONLY)

```bash
# READ-ONLY
source ~/nkp-vdi-01.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get vgputokens -A
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get nodes -L nvidia.com/vgpu.present,nvidia.com/gpu.product
```

Then the step 4 test pod of `nkp-gpu-ai` (CHANGES, plan and "yes"). The `nvidia-smi` output must show "License Status" `Licensed`. [pdf p.619] `Unlicensed` means no token on the node.

A new token after a license expiry: replace the Secret with the same block; the operator copies it again. [field]

**Next:** the answers to questions 1 and 2. Then I append `VGPU_TOKEN_FILE`, show the image plan (NIB O3 with `--vgpu-runfile` and `--gpu-profile-name`), and the app plans. No command ran in this reply.

---

## nkp-gpu-ai G5

**Skill files I read:** `skills/nkp/SKILL.md`, `skills/_shared/RULES.md`, `skills/nkp-gpu-ai/SKILL.md` (step 1, Common failures), `skills/nkp-gpu-ai/references/nvidia.md` (N2, N3, N4, N5), `skills/nkp-platform-apps-gitops/references/overrides.md` (O2, O5), `skills/nkp-troubleshooting/SKILL.md` (for the next step after a cause is found).

I do not change anything yet. First I read the state. A cause that is not in the failure table gets a READ-ONLY check; I do not guess.

### Questions I would ask first (with the question tool)

1. "Is `~/nkp-dev-02.env` in place for cluster `dev-02`?" — "Yes" (Recommended) / "No".
2. "Was the GPU operator ever on this cluster with the device plugin (for example from 2.18)?" — "No, new in 2.19" (Recommended) / "Yes" / "I do not know" (then step 1 tells us).

### Step 1: read the GPU state (READ-ONLY)

```bash
# READ-ONLY
source ~/nkp-dev-02.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n kommander get licenses.kommander.mesosphere.io -o jsonpath='{.items[*].status.dkpLevel}{"\n"}'
kubectl --kubeconfig "$MGMT_KUBECONFIG" get clusterapps | grep -E 'NAME|gpu|nvidia|amd'
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get appdeployments | grep -E 'NAME|gpu|nvidia|amd'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get nodes -o custom-columns='NAME:.metadata.name,KERNEL:.status.nodeInfo.kernelVersion,OS:.status.nodeInfo.osImage,GPU:.status.allocatable.nvidia\.com/gpu,TAINTS:.spec.taints[*].key'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get nodes -L feature.node.kubernetes.io/pci-10de.present,nvidia.com/gpu.product,nvidia.com/vgpu.present,nvidia.com/mig.config.state
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get pods -A -o wide | grep -E 'NAMESPACE|nvidia'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get deviceclasses,resourceslices
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get helmreleases -A -o custom-columns='NS:.metadata.namespace,NAME:.metadata.name,READY:.status.conditions[?(@.type=="Ready")].status,FROM:.spec.valuesFrom[*].name' | grep -E 'NS|nvidia'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get clusterpolicies.nvidia.com -o jsonpath='{range .items[*]}{.metadata.name} devicePlugin={.spec.devicePlugin.enabled} driver={.spec.driver.enabled} state={.status.state}{"\n"}{end}'
```

The two symptoms in your report are separate. "The nvidia pods run on some nodes only" is a node-level difference. "Pods stay Pending" is a claim/limit-level difference. I read both.

### The causes in the failure table, in this order

| What step 1 can show | Cause | Fix |
|---|---|---|
| A GPU node has no `PCI-10DE.PRESENT` `true` | NFD did not label it. The DRA plugin runs only on nodes with an NVIDIA PCI label. [pdf p.621][live 2.19.0] | Check the NFD pods in namespace `node-feature-discovery` first. Then the guide labels the node by hand (CHANGES, plan below): `kubectl label node <node> feature.node.kubernetes.io/pci-0302_10de.present=true`. [pdf p.621] |
| No `nvidia-*` pod on the GPU node, `TAINTS` has a key other than `nvidia.com/gpu` | The operator DaemonSets and the DRA plugin tolerate only the key `nvidia.com/gpu` (effect `NoSchedule`). [live 2.19.0] | Use the key `nvidia.com/gpu` on the pool (skill `nkp-cluster-lifecycle` V6/V3), or add tolerations in the values (N4, full lists). |
| `deviceclasses` shows `gpu.nvidia.com` but no `resourceslices` | A wrong `nvidiaDriverRoot` (mode B), or the override ConfigMap has another name. The DRA driver reads only `nvidia-gpu-operator-config-overrides`. | N2; `nkp-gpu-ai` step 3 item 2. |
| Pod `Pending` with `Insufficient nvidia.com/gpu` | DRA mode, and the pod asks with `limits` (D-42). | Ask with a ResourceClaim (`nkp-gpu-ai` step 4), or switch to the device plugin (N4). |
| A driver pod `ImagePullBackOff` (mode B) | No precompiled driver image for the node kernel. | N2, D-41. |
| `nvidia-dcgm` `CrashLoopBackOff`, validators `Init:CrashLoopBackOff` | A wrong `toolkit.version` in the override. | Remove `toolkit.version`; the 26.3.3 default is v1.20.0. [live 2.19.0] |
| Job `nvidia-gpu-operator-pre-install` fails: "Multiple ClusterPolicies found" | More than one ClusterPolicy. [live 2.19.0] | You remove all except the active one (CHANGES, plan and "yes"). |
| MIG label set, no MIG devices | MIG path | N5, and G-01 (MIG in the DRA path is open). |
| The HelmRelease is not Ready | Bad values or a stuck release | `overrides.md` O5; `nkp-platform-apps-gitops` step 3. |

For the `describe` output of a Pending pod (READ-ONLY):

```bash
# READ-ONLY
source ~/nkp-dev-02.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n default get pods -o wide
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n default describe pod gpu-test
```

`nvidia-smi` on the node shows the driver and the GPUs. It runs on the node, so you run it:

```bash
# USER-TERMINAL  (on the GPU node, over SSH)
nvidia-smi
```

### What I will not do
- I will not delete the ClusterPolicy or the AppDeployment as a first step. That removes the operator and does not fix a label, a taint, or a claim.
- I will not label nodes before I know that a missing NFD label is the cause. The label command is CHANGES: I show the node name, the label, and the result, and I stop for "yes".

**Next:** the step 1 output. I name one cause from the table, show one plan, and stop for "yes". No command ran in this reply.

---

## nkp-gpu-ai G6

**Skill files I read:** `skills/nkp/SKILL.md`, `skills/_shared/RULES.md`, `skills/nkp-gpu-ai/SKILL.md` (the GPU parts table, step 1), `skills/nkp-gpu-ai/references/ai-apps.md` (A4, A1 order), `skills/nkp-platform-apps-gitops/SKILL.md` (step 1, step 2), `skills/nkp-platform-apps-gitops/references/overrides.md` (O3).

### The fact for 2.19.0

On 2.19.0, **neither `amd-gpu-operator` nor `amd-kmm-operator` is a ClusterApp, and neither is in the 2.19.0 AI catalog bundle.** [live 2.19.0] The guide names both apps (driver build and load, DRA, metrics; Kernel Module Management) and AMD Instinct MI350 is validated, but that is not the same as an app that is present in this version. [pdf p.296, p.308][field]

So I do not invent a ClusterApp name (for example `amd-gpu-operator-1.5.1`). I run the check first.

### Questions I would ask first (with the question tool)

1. "Is `~/nkp-amd-01.env` in place for cluster `amd-01`?" — "Yes" (Recommended) / "No".

### Step 1: is the app in this site at all? (D-44, READ-ONLY)

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" get apps -A | grep -E 'NAME|amd'
kubectl --kubeconfig "$MGMT_KUBECONFIG" get clusterapps | grep -E 'NAME|amd'
```

UNKNOWN (D-44): where a 2.19.0 site gets the AMD GPU operator app (a newer AI catalog bundle or another bundle) and its air-gapped steps.

### If the list is empty (the expected result) — I stop

I tell you: **the source of the `amd-*` app for this site is not known.** These are the options, and I do not start any of them without a decision:
- Wait for a later AI catalog bundle that has `amd-kmm-operator` 1.0.0 and `amd-gpu-operator` 1.5.1. [field]
- Ask Nutanix support or the portal for the AMD app bundle for 2.19.0, then push it as a catalog bundle (skill `nkp-airgap`, `catalogs.md` C1-C2) and read the App names with `get apps -A`.

I do not use a web page or a Helm repository: the site is air-gapped and this must come from a supported bundle.

### If the list shows the apps (not expected)

Then the order is [field]:
1. `amd-kmm-operator` first (Kernel Module Management, it builds and loads the driver).
2. Then `amd-gpu-operator` (DRA and metrics).
3. DRA is on by default and the device plugin is off. The two are mutually exclusive.
4. The operator builds the driver in the cluster, so it needs a registry for the driver image: a Secret `kmm-registry-credentials` in the workspace namespace, and the override `deviceConfig.spec.driver.image` with that registry.
   - The Secret holds a registry password. **You make it** in your own terminal; I do not put a password in a command and I do not print the Secret.
5. The default `DeviceConfig` named `default` selects the nodes with `feature.node.kubernetes.io/amd-gpu: "true"` (from NFD). NFD is the CAREN addon on every cluster. That label is from field notes; step 1 of `nkp-gpu-ai` with `-L feature.node.kubernetes.io/amd-gpu` shows the real node labels.
6. Upgrade the operator first and the driver later, in two separate changes.

Enable with skill `nkp-platform-apps-gitops` step 2: `name` `amd-kmm-operator` (then `amd-gpu-operator`), `app` = the real App name from `get apps -A`, workspace from `WORKSPACE_NS`, dry run, plan, "yes". The detailed AMD values are **not in the skills**; I would ask for the app metadata and read `get apps -A -o yaml` before I write an override.

**Next:** the step 1 output. No command ran in this reply.

---

## nkp-gpu-ai G7

**Skill files I read:** `skills/nkp/SKILL.md`, `skills/_shared/RULES.md`, `skills/nkp-gpu-ai/SKILL.md` (step 1), `skills/nkp-gpu-ai/references/nvidia.md` (N5).

**Not in the skills.** The skills have no MIG profile table for the H100, no memory size and no slice count for `3g.40gb`. The only MIG example in the guide is `all-1g.6gb` on an A30 (seven `1g.6gb` devices). [pdf p.611, p.614] I will not state numbers for the H100 as facts.

The profile names and the device count depend on the GPU model and the driver. Read them on the node.

### Question I would ask first (with the question tool)

1. "Which node has the H100?" — I need its name, and SSH access for you.
   - "I give you the node name" (Recommended)
   - "I run the command myself and paste the output"

### Read the profiles of that GPU (you run it on the node)

```bash
# USER-TERMINAL  (on the GPU node with the H100, over SSH)
nvidia-smi mig -lgip
```

That lists the GPU instance profiles of that GPU with their names and their memory. The names come from the driver, not from a table.

For the count of what fits now, and the instances that exist:

```bash
# USER-TERMINAL  (on the same GPU node, over SSH)
nvidia-smi mig -lgi
```

### The node labels and the MIG state (READ-ONLY)

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get nodes -L nvidia.com/mig.config,nvidia.com/mig.config.state,nvidia.com/gpu.product,nvidia.com/mig-3g.40gb.replicas
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get resourceslices -o yaml | grep -c mig
```

- `nvidia.com/mig.config.state: success` means the MIG manager applied the label. [pdf p.615]
- The `nvidia.com/mig-*.replicas` labels appear after the split. [field]
- UNKNOWN (G-01): whether the DRA driver gives MIG devices (`mig.nvidia.com`) after a MIG split. Until this is closed, use MIG with the device plugin mode (N4).

When you give me the `-lgip` output, I write the label value for the pool (`nvidia.com/mig.config`, for example `all-<profile>`) and the `mig.strategy`, and I show the plan. The label goes on the **node pool**, not on one node, so a new node gets it too (skill `nkp-cluster-lifecycle`, V3; `variables.md`). No command ran in this reply.

---

## nkp-gpu-ai G8

**Skill files I read:** `skills/nkp/SKILL.md`, `skills/_shared/RULES.md`, `skills/nkp-gpu-ai/SKILL.md` (step 3), `skills/nkp-gpu-ai/references/ai-apps.md` (A5, A1 order, A6), `skills/nkp-platform-apps-gitops/SKILL.md` (step 1, step 2), `skills/nkp-platform-apps-gitops/references/catalogs.md` (K5 CloudNativePG), `skills/nkp-airgap/references/catalogs.md` (C1-C3), `skills/nkp-airgap/SKILL.md` (step 3), `skills/nkp-storage-backup/references/csi.md` (C5 Nutanix Files), `skills/nkp-storage-backup/SKILL.md`.

### The fact that decides this job

**NAI is not in the 2.19.0 bundle.** The `nkp-nutanix-product-catalog-image-bundle-2.19.tar` has only NDK 2.3.0. [live 2.19.0] On a connected site the NKP UI shows NAI from the online Nutanix product catalog; the guide sends air-gapped sites to the separate NAI guide. [pdf p.328-329]

So for your site:
- The air-gapped steps for NAI 2.8.1 on NKP 2.19 (the NAI bundle, its catalog, and the image overrides) are **not in the skills**.
- NAI 2.8.0 and 2.8.1 do run on NKP 2.19, on management and workload clusters, with Pro or Ultimate. [pdf p.327-330] The software is not the problem; the offline bundle is the open item.

UNKNOWN (D-45): the air-gapped steps for NAI 2.8 on NKP 2.19 (the NAI bundle, its catalog, and the image overrides). Find out with:

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" get apps -A | grep -E 'NAME|nutanix-ai|kserve|envoy-gateway-nai|leaderworkerset|opentelemetry'
```

If that list has no `nutanix-ai-*` App, the app source for this site is not known. Then: ask Nutanix support or the portal for the NAI bundle for 2.19.0 and push it as a catalog bundle (skill `nkp-airgap`, `catalogs.md` C1-C2). I do not start the NAI enable before that.

### Questions I would ask first (with the question tool)

1. "Is `~/nkp-ai-01.env` in place for cluster `ai-01`?" — "Yes" (Recommended) / "No".
2. "Does `get apps -A` show a `nutanix-ai-*` app (from a bundle you already have)?"
   - "No" — the expected answer for the 2.19.0 bundle (Recommended)
   - "Yes, I give the name and version"
3. "Do you have the NAI bundle tar from Nutanix for 2.19.0?" — "Yes" / "No, I ask Nutanix" (Recommended) / "Not yet".

### The prerequisites, in this order [pdf p.329]

1. **Platform apps on the target cluster:** cert-manager, Prometheus monitoring, the NVIDIA GPU operator (`nkp-gpu-ai` step 3: driver mode A, DRA, no sharing for this cluster), and CloudNativePG (skill `nkp-platform-apps-gitops`, `catalogs.md` K5).
2. **Catalog apps:** NAI-Envoy Gateway 1.8.2, KServe 0.19.0, OpenTelemetry Operator 0.114.1, LeaderWorkerSet 0.8.0.
3. **A Nutanix Files StorageClass** `nai-nfs-storage` (skill `nkp-storage-backup`, `csi.md` C5). It needs `nfsServer` and `nfsPath` from you.
4. **The Nutanix Docker Hub pull Secret** `nai-regcred` in the namespaces `nai-system` and `envoy-gateway-system`. `envoy-gateway-system` exists after the NAI-Envoy Gateway app. [pdf p.329-330]

Then NAI itself: skill `nkp-platform-apps-gitops` step 2 with the `nutanix-ai-*` App name from `get apps`, and an override (O3) with at least [pdf p.330]:

```yaml
global:
  imagePullSecrets:
    - name: nai-regcred
naiDatabase:
  enablePDB: false
```

The profiles (default 300 requests / 100 API keys, `c1k_k200`, `c5k_k1k`) are in the guide and are **not in the skills**.

### The pull Secret (`nai-regcred`)

The Nutanix Docker Hub token is `NUTANIX_REGISTRY_USERNAME` and `NUTANIX_REGISTRY_TOKEN` in `~/nkp-site.env` (skill `nkp-airgap`, step 3). The guide uses `--docker-password` on the command line. This block reads the token through a pipe, so it is not in the process list.

**This block is CHANGES. Target: cluster `ai-01`. Result: the namespace `nai-system` and the Secret `nai-regcred` in `nai-system` and `envoy-gateway-system`.** I stop for "yes". The secret values come from your env file, never from the chat, and the block prints no value.

```bash
# CHANGES  (creates namespace nai-system and the Secret nai-regcred in nai-system and envoy-gateway-system)
source ~/nkp-ai-01.env 2>/dev/null
: "${NUTANIX_REGISTRY_USERNAME:?MISSING, see skill nkp-airgap step 3}" "${NUTANIX_REGISTRY_TOKEN:?MISSING, see skill nkp-airgap step 3}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" create namespace nai-system --dry-run=client -o yaml | kubectl --kubeconfig "$CLUSTER_KUBECONFIG" apply -f -
for ns in nai-system envoy-gateway-system; do
  printf '{"auths":{"https://index.docker.io/v1/":{"auth":"%s"}}}' "$(printf '%s:%s' "$(printenv NUTANIX_REGISTRY_USERNAME)" "$(printenv NUTANIX_REGISTRY_TOKEN)" | base64 | tr -d '\n')" | kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" create secret generic nai-regcred --type=kubernetes.io/dockerconfigjson --from-file=.dockerconfigjson=/dev/stdin --dry-run=client -o yaml | kubectl --kubeconfig "$CLUSTER_KUBECONFIG" apply -f -
done
```

If a value is missing, the block stops with `MISSING`. Then you put the two lines in `~/nkp-site.env` with an editor (rule 5); I do not write a secret line.

### Check after the enable (READ-ONLY)

```bash
# READ-ONLY
source ~/nkp-ai-01.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n nai-system get pods
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n envoy-gateway-system get pods
```

Then NAI uses the external IP of its service. You make the DNS record for it. NAI uses a self-signed certificate by default. [pdf p.331]

### Two more points
- AI Navigator is **not** an air-gapped option. It needs internet (Azure OpenAI). Nutanix does not support it in an air gap. [pdf p.1073] Do not plan it for this site.
- Later Kubernetes upgrade of `ai-01`: single NAI pods can block the node drain. Before the upgrade, add the guide replicas to the override (`naiApi.replicaCount: 2`, `gateway.replicaCount: 2`, and the CPU requests), then go back to the default override. [pdf p.336-337]

**Next:** the D-45 check and your answers. With no `nutanix-ai-*` App, I stop and we get the NAI bundle from Nutanix. The prerequisites above can go first; the pull Secret waits for the NAI-Envoy Gateway (`envoy-gateway-system`). No command ran in this reply.
