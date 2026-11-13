# NVIDIA GPU details

Use this file from skill `nkp-gpu-ai`. The values in this file go into one values file for the override ConfigMap `nvidia-gpu-operator-config-overrides` (SKILL.md step 3). Both HelmReleases of the app read that file. The `gpu-operator` chart and the `dra-driver-nvidia-gpu` chart have no top-level value names in common, so each chart uses only its own values. [live 2.19.0] Helm replaces a list, it does not merge it. [pdf p.276]

| File | Site variables |
|---|---|
| `~/nkp-site.env` | `GPU_PROFILE` `VGPU_RUNFILE` `VGPU_TOKEN_FILE` |

- `GPU_PROFILE`: the AHV GPU profile name (Prism Central 7.6 or later), or the GPU name or vGPU profile name (Prism Central 7.5). The user reads it in Prism Central. [pdf p.707, p.611]
- `VGPU_RUNFILE`: the path of the NVIDIA vGPU guest driver runfile on the operator host. `VGPU_TOKEN_FILE`: the path of the NVIDIA client configuration token file (`.tok`), mode 600. The token file is a secret: never print it.

Ask for each value. Append it only after the answer (rule 4).

## N1. GPU node image (NIB)

The build block is in skill `nkp-airgap`, file `os-images.md`, O3. This section gives only the GPU values. The node pool: skill `nkp-cluster-lifecycle`, V6.

| OS image | GPU | GPU air-gapped | vGPU |
|---|---|---|---|
| Rocky Linux 9.8 | no | no | no |
| Ubuntu 22.04, Ubuntu 24.04 | yes | yes | no |
| RHEL 8.10, 9.6, 9.8 | yes | yes | yes |

[pdf p.13-14] The image page says that the Nutanix Ubuntu image supports passthrough **and vGPU**, and the Rocky image does not. [pdf p.56] The two pages differ for vGPU on Ubuntu. Tell the user, and let the user decide.

- Ubuntu 22.04 GPU in an air gap is not supported with "NVIDIA Installer Bundles (NIB)" (the guide words), only with precompiled drivers (N2). [pdf p.13]
- Custom images need Pro or Ultimate (skill `nkp-airgap`). A GPU image of the Nutanix Ubuntu image is not needed for driver mode B.
- Flags for `nkp create image nutanix` [live 2.19.0]:
  - `--gpu-profile-name "$GPU_PROFILE"`: the GPU of the temporary VM. Use it on Prism Central 7.6 or later.
  - `--gpu-name`: hidden in `--help`. The CLI says: "deprecated for PC 7.6+ ... (retained for PC 7.5 compatibility)". Use it only on Prism Central 7.5. The two flags are mutually exclusive.
  - `--vgpu-runfile "$VGPU_RUNFILE"`: installs the vGPU guest driver. The runfile must match the vGPU host driver on AHV (for example `NVIDIA-Linux-x86_64-580.126.18-grid.run`). [pdf p.609] The user gets it from the NVIDIA licensing portal on a connected host.
- Pre-provisioned hosts: `nkp upload image-artifacts --nvidia-runfile <file>` (skill `nkp-install`, file `preprovisioned.md`). [pdf p.801]

Done when: Prism Central shows the GPU image. Give its name to the node pool step (skill `nkp-cluster-lifecycle`, V6).

## N2. Driver mode B: precompiled driver

The guide values (recommended for production). The guide says that they are for the Nutanix Ubuntu images. [pdf p.612, p.615]

```yaml
driver:
  enabled: true
  usePrecompiled: true
  version: 580
  kernelModuleType: auto
  image: driver
nvidiaDriverRoot: /run/nvidia/driver
```

- `driver.*` goes to the GPU operator. `nvidiaDriverRoot` goes to the DRA driver. [live 2.19.0] Its default `/` is for a driver in the node image (mode A). Use `/run/nvidia/driver` only in mode B. When the user goes back to mode A after mode B failed, remove `nvidiaDriverRoot` from the override too.
- The operator pulls the image `driver:<version>-<kernel>-<os>` for the kernel of each node. [field] The bundle has only these driver images [live 2.19.0]:

```text
nvcr.io/nvidia/driver:580-5.15.0-176-generic-ubuntu22.04
nvcr.io/nvidia/driver:580-6.8.0-111-generic-ubuntu24.04
nvcr.io/nvidia/driver:595-6.8.0-134-generic-ubuntu24.04   (NKP Metal Ubuntu 24.04)
```

- The 2.19.0 Nutanix Ubuntu 24.04 nodes run kernel `6.8.0-124-generic`. [live 2.19.0] The guide gives `5.15.0-185-generic` for Ubuntu 22.04. [pdf p.13] **No bundle image matches these kernels.** NVIDIA publishes the tag `580-6.8.0-124-generic-ubuntu24.04`. [field]

UNKNOWN (D-41): whether driver mode B works on the 2.19.0 Nutanix Ubuntu images with only the bundle images (the kernel and the image tags differ). Find out with: `source ~/nkp-<cluster>.env 2>/dev/null && kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get pods -A -o custom-columns='NAME:.metadata.name,IMAGE:.spec.containers[*].image,STATUS:.status.phase' | grep -E 'NAME|nvidia-driver'`.

Compare the node kernels with the driver images of the bundle:

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get nodes -o custom-columns='NAME:.metadata.name,KERNEL:.status.nodeInfo.kernelVersion,OS:.status.nodeInfo.osImage'
repo='nvidia/driver'
for b in "$BUNDLE_DIR"/container-images/kommander-image-bundle-*.tar; do tar -tf "$b" | sed -n "s#^docker/registry/v2/repositories/$repo/_manifests/tags/\([^/]*\)/current/link\$#\1#p"; done
```

- A tag with the kernel of each GPU node exists: continue.
- No tag: tell the user. Choose with the user: (1) driver mode A (a GPU image with the driver, N1), or (2) the user gets the image `nvcr.io/nvidia/driver:580-<kernel>-<os>` on a connected host and pushes it to the registry (skill `nkp-airgap`, file `prestage.md`, P12). Do not change the node kernel.
- A Kubernetes upgrade changes the node image and the kernel. Check this again before each upgrade (N8).

## N3. DRA (the default)

The DRA driver publishes each GPU in a `ResourceSlice`. A pod asks for a device with a ResourceClaim. [pdf p.610][live 2.19.0]

| DeviceClass | Devices |
|---|---|
| `gpu.nvidia.com` | full GPUs (`extendedResourceName: nvidia.com/gpu`) |
| `mig.nvidia.com` | MIG devices |
| `vfio.gpu.nvidia.com` | GPUs for VFIO passthrough |
| `compute-domain-daemon.nvidia.com`, `compute-domain-default-channel.nvidia.com` | multi-node NVLink compute domains |

[live 2.19.0] The step 4 test of SKILL.md shows a template with one GPU. For two GPUs in one claim, add `count: 2` under `exactly` (the API field `exactly.count`; `allocationMode` `ExactCount`). [live 2.19.0]

- Every pod must tolerate the taint of the GPU pool (`nvidia.com/gpu`, `NoSchedule`).
- A `ResourceClaimTemplate` makes one claim for each pod. Two pods that name the same `ResourceClaim` (`resourceClaimName`) use the same GPU. [field]
- Kueue counts DRA GPUs only with a device class mapping: [ai-apps.md](ai-apps.md), A3.
- Time-slicing and MPS with the DRA driver are not in the skills. Use the device plugin (N4).

## N4. Device plugin mode and time-slicing

**Device plugin mode.** These values turn the DRA driver off and the device plugin on. They are the same values that the app pre-install job uses for an old install with the device plugin. [live 2.19.0] DRA and the device plugin must not both serve GPUs on the same nodes. [pdf p.610]

```yaml
devicePlugin:
  enabled: true
gpuResourcesEnabledOverride: false
resources:
  gpus:
    enabled: false
  computeDomains:
    enabled: false
webhook:
  enabled: false
```

Then pods ask with `resources.limits` `nvidia.com/gpu: 1`, and `kubectl get nodes` shows `nvidia.com/gpu` in the allocatable (SKILL.md step 1).

On a workload cluster, check D-40 (SKILL.md step 3) after the enable: the `nvidia-dra-driver` HelmRelease must show `nvidia-gpu-operator-config-overrides` in its values, and `kubectl get deviceclasses` must show no `gpu.nvidia.com`. If the DRA driver still serves GPUs, both run on the same nodes. Stop and tell the user.

**Time-slicing** (device plugin mode only). Add this under the same `devicePlugin:` key. The chart makes the ConfigMap. [live 2.19.0] The sharing text is from field notes. [field]

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
```

- Ask the user for `replicas` (the number of pods for each GPU). Do not guess it.
- A node with 1 GPU then shows `nvidia.com/gpu: 4`. The node labels `nvidia.com/gpu.replicas` and `nvidia.com/gpu.sharing-strategy` show the setting. [pdf p.618] Time-slicing gives no memory isolation between the pods. [field]
- Do not use time-slicing and MIG on the same GPU unless the user has a tested config. Not in the skills.

**Other taint key on the GPU pool.** The default tolerations are only for `nvidia.com/gpu`. [live 2.19.0] To add a key, give the full lists (Helm replaces a list). Ask the user for the key. Example with the key `dedicated`:

```yaml
daemonsets:
  tolerations:
  - key: nvidia.com/gpu
    operator: Exists
    effect: NoSchedule
  - key: dedicated
    operator: Exists
    effect: NoSchedule
kubeletPlugin:
  tolerations:
  - key: nvidia.com/gpu
    operator: Exists
    effect: NoSchedule
  - key: dedicated
    operator: Exists
    effect: NoSchedule
```

`daemonsets.tolerations` is a `gpu-operator` value. `kubeletPlugin.tolerations` is a DRA driver value. [live 2.19.0]

## N5. MIG

- MIG works only on passthrough GPUs. Nutanix does not support MIG profiles on vGPU VMs. From AOS 7.3 and AHV 10.3, Prism hides the MIG profiles. [pdf p.612-613]
- The MIG manager is on by default. [live 2.19.0] It reads the node label `nvidia.com/mig.config` and splits the GPUs. Example from the guide: `all-1g.6gb` on an A30 (seven 1g.6gb devices). [pdf p.611, p.614] The profile names depend on the GPU model. The user runs `nvidia-smi mig -lgip` on the node to list them (USER-TERMINAL, on the node). [field]
- Put the label on the node pool, not on one node: a new node then gets it too. Which pool labels reach the nodes, and how to set them: skill `nkp-cluster-lifecycle` (file `variables.md`, node labels). The guide also labels one node by hand: `kubectl label nodes <node> nvidia.com/mig.config=all-1g.6gb --overwrite`. [pdf p.614]
- Values (device plugin mode): `mig.strategy: single` when all GPUs of a node have the same MIG profile, `mixed` when not. [pdf p.612] The chart default is `single`. [live 2.19.0]
- Check: the node labels show `nvidia.com/mig.config.state: success`. [pdf p.615] Run SKILL.md step 1 (the `MIG.CONFIG.STATE` column).

UNKNOWN (G-01): whether the DRA driver gives MIG devices (DeviceClass `mig.nvidia.com`) after the MIG manager splits a GPU. The 2.19 release notes say that MIG partitioning is not in the DRA path. Find out with: `source ~/nkp-<cluster>.env 2>/dev/null && kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get resourceslices -o yaml | grep -c mig` on a MIG node in DRA mode.

Until G-01 is closed, use MIG with the device plugin mode (N4). With `mig.strategy: single`, pods ask for `nvidia.com/gpu`. With `mixed`, pods ask for the MIG resource name (for example `nvidia.com/mig-1g.6gb`). [field]

## N6. vGPU and the vGPU token operator

vGPU VMs need an NVIDIA license. The vGPU token operator copies the client configuration token to each vGPU node. [pdf p.617][live 2.19.0] Order:

1. A vGPU image (N1, `--vgpu-runfile`). Driver mode A. The vGPU host driver must be on AHV. [pdf p.608-609]
2. A license server that the nodes can reach: the NVIDIA cloud license server (needs internet) or a delegated license server (DLS) on site. [pdf p.617] In an air gap, only a DLS works. [field]
3. The token operator app, **before** the vGPU node pool. [pdf p.611, p.614]
4. The vGPU node pool (skill `nkp-cluster-lifecycle`, V6), then the GPU operator (SKILL.md step 3).

**The token operator.** The guide pastes the token in the UI. [pdf p.617] With the CLI, use the chart values. [live 2.19.0] The chart needs a Secret with the key `client_configuration_token.tok` in the namespace of the app on the target cluster (`kommander` on the management cluster, the workspace namespace on a workload cluster). [field]

1. The user copies the `.tok` file to the operator host and runs `chmod 600` on it. Ask for the path; append `VGPU_TOKEN_FILE` (rule 4).
2. Make the Secret on each target cluster. Set `ns` to the app namespace. Show the plan, stop for "yes":

```bash
# CHANGES  (creates or replaces the Secret vgpu-client-token with the vGPU token on the target cluster)
source ~/nkp-<cluster>.env 2>/dev/null
ns=''; : "${ns:?}" "${VGPU_TOKEN_FILE:?}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" create secret generic vgpu-client-token --from-file=client_configuration_token.tok="$VGPU_TOKEN_FILE" --dry-run=client -o yaml | kubectl --kubeconfig "$CLUSTER_KUBECONFIG" apply -f -
```

3. Enable the app with skill `nkp-platform-apps-gitops`, step 2: `name` `vgpu-token-operator`, `app` `vgpu-token-operator-1.0.8`. The override values (O3 there, `APP_ID` `vgpu-token-operator`, a new ConfigMap name such as `vgpu-token-operator-overrides-ws`):

```yaml
vgpuTokenObjects:
  - tokenName: vgpu-token
    tokenSecretName: vgpu-client-token
```

   The chart makes a `VGPUToken` (`vgpu-token.nutanix.com/v1alpha1`). Its default node selector is `nvidia.com/vgpu.present: "true"`. The token goes to `/etc/nvidia/ClientConfigToken/` on the node. [live 2.19.0] GFD of the GPU operator sets that label [pdf p.618], so the token reaches the nodes after the GPU operator runs (item 4 of the order).

UNKNOWN (D-46): whether the NKP UI field of the vGPU token operator (the token text) makes the same Secret and `VGPUToken` as the chart values. Find out with: `source ~/nkp-<cluster>.env 2>/dev/null && kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get vgputokens -A -o yaml | grep -E '^ +(name|tokenSecretRef|hostDirectoryPath):'` after a UI enable.

4. Check (READ-ONLY): `kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get vgputokens -A`, and the node label `nvidia.com/vgpu.present=true` (SKILL.md step 1). Then the step 4 test pod: "License Status" `Licensed`. [pdf p.618-619]

- A new token (expired license): replace the Secret (block 2). The operator copies it again. [field]
- MIG does not work with vGPU (N5).

## N7. GPU metrics (DCGM)

- The app runs the DCGM exporter with a ServiceMonitor that has the label `prometheus.kommander.d2iq.io/select: "true"`, and a Grafana dashboard ConfigMap `grafana-dashboards-gpu-operator`. [live 2.19.0] The Kommander Grafana has the dashboard "NVIDIA DCGM Exporter Dashboard". [pdf p.619]
- This needs the Prometheus monitoring app (Pro or Ultimate). Prometheus and Grafana: skill `nkp-observability`.
- No GPU metrics: check that the exporter pods run on every GPU node, the ServiceMonitor exists, and no network policy blocks Prometheus. [pdf p.619-620]

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get pods -A -o wide | grep -E 'NAMESPACE|dcgm-exporter'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get servicemonitors -A | grep -E 'NAMESPACE|dcgm'
```

## N8. Kubernetes upgrade of a GPU cluster

The upgrade steps are in skill `nkp-upgrade`. Before the upgrade of a cluster with GPU nodes:

1. Driver mode A: build a new GPU image for the new Kubernetes version (N1). Give it to the GPU pool with `WORKER_VM_IMAGES` (skill `nkp-upgrade`).
2. Driver mode B: the new image has a new kernel. Check that a driver image for that kernel is in the registry (N2).
3. NAI on the cluster: [ai-apps.md](ai-apps.md), A5 (replicas before the upgrade).
4. Replace the GPU nodes one at a time. GPU capacity is often small: a new GPU node needs a free GPU in Prism Element (skill `nkp-cluster-lifecycle`, V6). [field]
5. An old install with the device plugin keeps the device plugin after the platform apps upgrade. The pre-install job makes the ConfigMap `nvidia-gpu-operator-config-deviceplugin-defaults` for it, and that ConfigMap turns the DRA driver off. [live 2.19.0] A move from the device plugin to DRA on a running cluster is not in the skills.
