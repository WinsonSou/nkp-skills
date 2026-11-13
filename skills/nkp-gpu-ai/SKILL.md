---
name: nkp-gpu-ai
description: >
  NKP GPU and AI: NVIDIA GPU operator (nvidia-gpu-operator app, drivers, precompiled drivers, DRA driver,
  device plugin, MIG, time-slicing, DCGM), GPU not visible or nvidia-* pods fail, GPU node images, vGPU
  and the vGPU token operator, AMD GPU operator, AI Catalog apps (Kueue, KAI Scheduler, Slurm, Kubeflow
  Pipelines, JupyterHub, Milvus), Nutanix Enterprise AI (NAI), AI Navigator.
metadata:
  nkp_versions: "2.19"
  last_verified: "2026-11-03"
  sources: "live 2.19.0, pdf 2.19, field"
---

# NKP GPU and AI

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

This skill owns the GPU software on NKP clusters and the AI apps. Not in this skill: the GPU node pool (VMs, `--gpu-profile-name`, `--gpu-count`, pool taints): skill `nkp-cluster-lifecycle` (file `variables.md`, V6). Images and catalogs in a closed site: skill `nkp-airgap`. How to enable an app and how override ConfigMaps work: skill `nkp-platform-apps-gitops` (step 2; file `overrides.md`, O2-O4). Grafana and Prometheus: skill `nkp-observability`.

## The GPU parts [live 2.19.0]

| Part | What it is |
|---|---|
| `nvidia-gpu-operator-26.3.3` | Platform app (ClusterApp), Pro and Ultimate. Chart `gpu-operator` v26.3.3. It also installs the NVIDIA **DRA driver** (chart `dra-driver-nvidia-gpu` 0.4.1) as a second HelmRelease, `nvidia-dra-driver`. |
| Its defaults | Driver install **off** (`driver.enabled: false`), device plugin **off**, DRA driver **on**, CDI on, GFD on, DCGM and the DCGM exporter on (with a ServiceMonitor), MIG manager on, the NFD of the chart off. |
| NFD | The CAREN addon `node-feature-discovery` (namespace `node-feature-discovery`) on every cluster. It labels by PCI class and vendor (`deviceLabelFields: [class, vendor]`). [live 2.19.0] An NVIDIA node gets `feature.node.kubernetes.io/pci-0302_10de.present` (3D controller) or `pci-0300_10de.present` (VGA). [pdf p.621] |
| `vgpu-token-operator-1.0.8` | Platform app, Pro and Ultimate. It copies the NVIDIA vGPU client token to the vGPU nodes. Its defaults are empty. |
| `nvidia-network-operator-26.4.1` | Platform app. The guide has no steps for it. Not in the skills. |
| AMD GPU operator | Not a ClusterApp in 2.19.0, and not in the 2.19.0 bundle. [references/ai-apps.md](references/ai-apps.md), A4. |
| AI Catalog | Catalog apps from `nkp-ai-applications-catalog-image-bundle-2.19.tar`: JupyterHub, Kubeflow Pipelines, KAI Scheduler, Kueue, Milvus Operator, Slurm Operator. [references/ai-apps.md](references/ai-apps.md), A1-A3. |
| NAI | Nutanix Enterprise AI 2.8.x, a catalog app with its own prerequisites. [references/ai-apps.md](references/ai-apps.md), A5. |

- NKP supports the NVIDIA driver 580.x. [pdf p.607]
- The operator pods run in the namespace of the app: `kommander` on the management cluster, the workspace namespace on a workload cluster. [live 2.19.0] The guide says `nvidia-gpu-operator`. [pdf p.616] Step 1 finds them with `grep nvidia`.
- DRA (`resource.k8s.io/v1`) is on in Kubernetes 1.36. You do not enable it. [pdf p.610][live 2.19.0]

## Job → section

| Job | Where |
|---|---|
| Read the GPU state of a cluster | step 1 |
| Plan: driver mode, DRA or device plugin, sharing, vGPU, taint | step 2 |
| Enable the NVIDIA GPU operator | step 3 |
| Test a GPU pod | step 4 |
| Disable the GPU operator | step 5 |
| GPU node image (NIB flags `--gpu-profile-name`, `--vgpu-runfile`) | [references/nvidia.md](references/nvidia.md), N1 |
| Precompiled driver, driver image for the node kernel, air-gapped driver image | [references/nvidia.md](references/nvidia.md), N2 |
| DRA claims, device plugin mode, time-slicing | [references/nvidia.md](references/nvidia.md), N3-N4 |
| MIG | [references/nvidia.md](references/nvidia.md), N5 |
| vGPU and the vGPU token operator | [references/nvidia.md](references/nvidia.md), N6 |
| DCGM metrics and the GPU dashboard | [references/nvidia.md](references/nvidia.md), N7 |
| Kubernetes upgrade of a GPU cluster | [references/nvidia.md](references/nvidia.md), N8 |
| AI Catalog apps (Kueue, KAI, Slurm, others); AMD; NAI; AI Navigator | [references/ai-apps.md](references/ai-apps.md) |
| GPU not visible, `nvidia-*` pods fail | step 1, then "Common failures" |

## Step 1: Read the GPU state

Ask the user for the cluster. For the management cluster, `WORKSPACE_NS` is `kommander`.

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n kommander get licenses.kommander.mesosphere.io -o jsonpath='{.items[*].status.dkpLevel}{"\n"}'
kubectl --kubeconfig "$MGMT_KUBECONFIG" get clusterapps | grep -E 'NAME|gpu|nvidia|amd'
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get appdeployments | grep -E 'NAME|gpu|nvidia|amd'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get nodes -o custom-columns='NAME:.metadata.name,KERNEL:.status.nodeInfo.kernelVersion,OS:.status.nodeInfo.osImage,GPU:.status.allocatable.nvidia\.com/gpu,TAINTS:.spec.taints[*].key'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get nodes -L feature.node.kubernetes.io/pci-0302_10de.present,feature.node.kubernetes.io/pci-0300_10de.present,nvidia.com/gpu.product,nvidia.com/vgpu.present,nvidia.com/mig.config.state
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get pods -A -o wide | grep -E 'NAMESPACE|nvidia'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get deviceclasses,resourceslices
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get helmreleases -A -o custom-columns='NS:.metadata.namespace,NAME:.metadata.name,READY:.status.conditions[?(@.type=="Ready")].status,FROM:.spec.valuesFrom[*].name' | grep -E 'NS|nvidia'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get clusterpolicies.nvidia.com -o jsonpath='{range .items[*]}{.metadata.name} devicePlugin={.spec.devicePlugin.enabled} driver={.spec.driver.enabled} state={.status.state}{"\n"}{end}'
```

How to read it:
- The tier must be `Pro` or `Ultimate`. Starter has no GPU apps. [live 2.19.0]
- An NVIDIA node has `PCI-0302_10DE.PRESENT` or `PCI-0300_10DE.PRESENT` `true` (NFD labels by PCI class and vendor [live 2.19.0]). A label without the class (`pci-10de.present`) is never set on NKP. No such node: the VM has no GPU (skill `nkp-cluster-lifecycle`, V6), or NFD did not label it ("Common failures").
- The `GPU` column (`nvidia.com/gpu` in the node allocatable) shows a number in device plugin mode.
- With the DRA driver: `deviceclasses` shows `gpu.nvidia.com`, `mig.nvidia.com`, `vfio.gpu.nvidia.com`, and two `compute-domain-*` classes. `resourceslices` shows the GPUs of each node. [live 2.19.0]
- `clusterpolicies`: "the server doesn't have a resource type" means that the operator was never installed.

Done when: you know the tier, the GPU nodes and their kernel, and whether the operator runs, in DRA mode or in device plugin mode.

## Step 2: Plan

Ask the user these questions. Write down the answers. Do not guess them.

1. **Driver mode.** Where does the NVIDIA driver come from?
   - **A. In the node image.** NIB built the image with the driver (passthrough) or with `--vgpu-runfile` (vGPU), or the pre-provisioned hosts got `--nvidia-runfile`. Keep the driver default (off). [live 2.19.0] Use A for vGPU, and for Rocky or RHEL nodes.
   - **B. Precompiled driver, installed by the operator.** For the Nutanix Ubuntu images. The guide recommends it for production. GPU in an air gap is supported with precompiled drivers. [pdf p.13, p.612] The driver image tag must match the node kernel ([references/nvidia.md](references/nvidia.md), N2).
2. **GPU access.** DRA (the 2.19 default: a pod asks for a GPU with a ResourceClaim), or the device plugin (a pod asks with `nvidia.com/gpu: 1` limits). Time-slicing in this skill needs the device plugin. A cluster that had the operator with the device plugin before (for example from 2.18) keeps the device plugin. [live 2.19.0] See [references/nvidia.md](references/nvidia.md), N3-N4.
3. **Sharing.** None, time-slicing (N4), or MIG (N5). MIG works only with passthrough, not with vGPU. [pdf p.613]
4. **vGPU?** Then the vGPU token operator comes first (N6). [pdf p.614]
5. **Pool taint.** The operator DaemonSets and the DRA plugin tolerate only the taint key `nvidia.com/gpu` (effect `NoSchedule`). [live 2.19.0] On a pool with another taint key, the operator pods do not start. Use the key `nvidia.com/gpu` on the GPU pool (skill `nkp-cluster-lifecycle`, V6), or add tolerations in the values (N4).

Done when: you have the answers to 1-5.

## Step 3: Enable the NVIDIA GPU operator

Before: a Pro or Ultimate license, and a GPU node pool with the right image (skill `nkp-cluster-lifecycle`, V6). [pdf p.615] Air-gapped: the operator images are in `kommander-image-bundle`. The precompiled driver image can be missing (N2). [live 2.19.0]

1. **The values.** Driver mode A, DRA, no sharing: no values. Go to item 3, without `--config-overrides`. Else use the values of N2, N4, or N5. Put all the values in one file.
2. **The override ConfigMap.** Use skill `nkp-platform-apps-gitops`, file `overrides.md`, O3 items 1-3 (values file, syntax check, server dry run), with `APP_ID` `nvidia-gpu-operator` and `cm` `nvidia-gpu-operator-config-overrides`. Use exactly this name: the `nvidia-dra-driver` HelmRelease reads only this name. With another name, the DRA values (for example `nvidiaDriverRoot`) do not reach the DRA driver. The guide name `nvidia-gpu-operator-overrides` [pdf p.615] reaches only the operator. [live 2.19.0] The two charts have no value names in common. [live 2.19.0] On the management cluster this ConfigMap is in `kommander`, the HelmRelease namespace: only a delete of the ConfigMap removes the DRA values; removing `configOverrides` does not. [live 2.19.0]
3. **Enable.** Use skill `nkp-platform-apps-gitops`, step 2, with `name` `nvidia-gpu-operator`, `app` `nvidia-gpu-operator-26.3.3` (the ClusterApp name from step 1), and `--config-overrides nvidia-gpu-operator-config-overrides` when item 2 applies. Kommander waits for the ConfigMap. [pdf p.350] The server dry run of this AppDeployment passes before the ConfigMap exists. [live 2.19.0]
4. **Apply the ConfigMap.** Use `overrides.md` O3 item 4 with the same `cm`.

UNKNOWN (D-40): whether the `nvidia-dra-driver` HelmRelease on a workload cluster gets the workspace override (it reads `nvidia-gpu-operator-config-overrides` in its own namespace on that cluster). Find out with: `source ~/nkp-<cluster>.env 2>/dev/null && kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$WORKSPACE_NS" get configmaps | grep nvidia-gpu-operator`.

5. **Check.** Run step 1 again. The first driver install (mode B) can take 10 minutes or more. [field]

Done when: the `nvidia-gpu-operator` and `nvidia-dra-driver` HelmReleases are READY `True`, the operator pods run, the validator pods are `Completed`, and step 4 passes.

## Step 4: Test a GPU pod

DRA mode. The server dry run of this claim and this pod passes on 2.19.0. [live 2.19.0] Show the plan, stop for "yes":

```bash
# CHANGES  (creates a ResourceClaimTemplate and a test pod in namespace default; the pod gets one GPU)
source ~/nkp-<cluster>.env 2>/dev/null
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

- Device plugin mode: remove the ResourceClaimTemplate, `resourceClaims`, and `claims`. Set `resources.limits` to `nvidia.com/gpu: 1`, as the guide test pod does. [pdf p.618-619]
- The test image is in `kommander-image-bundle`. [live 2.19.0]
- Read the result (READ-ONLY): `kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n default logs gpu-test | head -40`. It shows the driver version and the GPU. vGPU: "License Status" must be `Licensed`. [pdf p.619]
- Pod `Pending`: run `kubectl describe pod gpu-test`, then read "Common failures".

UNKNOWN (D-42): whether a pod with `nvidia.com/gpu: 1` limits gets a GPU in DRA mode (the DeviceClass `gpu.nvidia.com` sets `extendedResourceName: nvidia.com/gpu`, and the gate `DRAExtendedResource` is on). Find out with: `source ~/nkp-<cluster>.env 2>/dev/null && kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n default describe pod gpu-test` after a test pod with limits in DRA mode.

Remove the test after it passes (CHANGES, plan and "yes"): `kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n default delete pod gpu-test`, then the same with `delete resourceclaimtemplate single-gpu`.

Done when: the log shows the GPU.

## Step 5: Disable the GPU operator

1. The user stops all GPU workloads on the clusters first. [pdf p.617]
2. Use skill `nkp-platform-apps-gitops`, step 2, "Disable", with `name` `nvidia-gpu-operator`.
3. Check (READ-ONLY): `kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get pods -A | grep nvidia` shows no pods after a few minutes. [pdf p.617]

## Common failures

| Symptom | Cause | Fix |
|---|---|---|
| A GPU node has no `pci-0302_10de.present` and no `pci-0300_10de.present` label | NFD did not label it. [pdf p.621] | Check the NFD pods (namespace `node-feature-discovery`). The guide labels the node by hand (CHANGES): `kubectl label node <node> feature.node.kubernetes.io/pci-0302_10de.present=true`. [pdf p.621] The DRA plugin runs only on nodes with an NVIDIA PCI label. [live 2.19.0] |
| No operator pods on the GPU node | The pool taint key is not `nvidia.com/gpu`. [live 2.19.0] | Step 2, item 5. |
| Job `nvidia-gpu-operator-pre-install` fails: "Multiple ClusterPolicies found" | More than one ClusterPolicy. [live 2.19.0] | The user removes all except the active one (CHANGES). |
| `nvidia-dcgm` `CrashLoopBackOff`, validators `Init:CrashLoopBackOff` | A wrong toolkit version. [pdf p.620-621] | Remove `toolkit.version` from the override. The 26.3.3 default is v1.20.0. [live 2.19.0] |
| Driver pod `ImagePullBackOff` (mode B) | No precompiled driver image for the node kernel. | [references/nvidia.md](references/nvidia.md), N2. |
| No `ResourceSlices`; the DRA plugin pod is not ready | A wrong `nvidiaDriverRoot`, or the override has another name. | N2; step 3, item 2. |
| Pod `Pending` with `Insufficient nvidia.com/gpu` | DRA mode, and the pod asks with limits (D-42). | Use a claim (step 4), or device plugin mode (N4). |
| MIG label set, but no MIG devices | | [references/nvidia.md](references/nvidia.md), N5. |
| vGPU node: `Unlicensed` | No token on the node. | [references/nvidia.md](references/nvidia.md), N6. |
| HelmRelease not Ready | | Skill `nkp-troubleshooting` (file `flux.md`). Bad values: skill `nkp-platform-apps-gitops`, `overrides.md` O5. |

`nvidia-smi` on the node shows the driver and the GPUs. [pdf p.620] It runs on the node, so the user runs it:

```bash
# USER-TERMINAL  (on the GPU node, over SSH)
nvidia-smi
```

For the debug ladder and other failures, use skill `nkp-troubleshooting`.
