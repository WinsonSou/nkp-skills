# AI apps: AI Catalog, AMD, NAI, AI Navigator

Use this file from skill `nkp-gpu-ai`. All apps here need Pro or Ultimate. [pdf p.624][live 2.19.0] How to add a catalog and how to enable a catalog app: skill `nkp-platform-apps-gitops` (file `catalogs.md`, K1-K3; SKILL.md step 2). Catalog bundles in a closed site: skill `nkp-airgap` (file `catalogs.md`, C1-C2).

## A1. The AI Catalog

The 2.19.0 bundle has `container-images/nkp-ai-applications-catalog-image-bundle-2.19.tar` with the catalog `nutanix-cloud-native/nkp-ai-applications-catalog/collection:2.19`. [live 2.19.0]

| App | Version in the 2.19.0 bundle | Use | Needs |
|---|---|---|---|
| `kueue` | 0.18.0 | job queues, quotas, gang admission | no queues after the install (A3) |
| `kai-scheduler` | 0.15.2 | GPU-aware scheduler with queues and fair share | GPU operator, node isolation, monitoring first [pdf p.624] |
| `slurm-operator` | 1.1.1 | Slurm clusters on Kubernetes (HPC jobs) | `cert-manager` |
| `kubeflow-pipelines` | 2.15.0 | ML pipelines | scope workspace or project |
| `jupyterhub` | 4.3.2 | notebooks, NKP login through Dex | |
| `milvus-operator` | 1.3.6 | vector database | |

[live 2.19.0][pdf p.622-627] All six are `nkpVersionSupport >=2.18.0`. [live 2.19.0]

Order [pdf p.623-624]:
1. A managed or attached cluster in a workspace (not the management cluster workspace for a workload cluster).
2. Platform apps: the NVIDIA GPU operator (SKILL.md step 3) for GPU work, Prometheus monitoring, cert-manager, and ingress or a gateway when users reach the app from outside.
3. Node labels and taints for the GPU nodes (skill `nkp-cluster-lifecycle`).
4. The catalog (A2), then the app.

Pick one scheduler [pdf p.623]: Kueue for queue admission and gang start of distributed jobs, Slurm for HPC jobs with Slurm commands, KAI for fair share of a GPU pool between teams. KAI can run next to the default scheduler. [pdf p.623] Kueue does not place pods: it admits them, then the default scheduler places them. [pdf p.625]

## A2. Add the AI catalog and enable an app

1. Read the catalogs (skill `nkp-platform-apps-gitops`, file `catalogs.md`, K1). An `OCIRepository` with `ai-applications-catalog` in the URL: the catalog is there. Go to item 3.
2. Air-gapped: push the bundle and create the catalog (skill `nkp-airgap`, file `catalogs.md`, C1). Connected site: add the catalog with K2 of the gitops file. Ask the user for the URL and the tag; the catalog repository is `nutanix-cloud-native/nkp-ai-applications-catalog/collection`, tag `2.19`. [live 2.19.0]
3. Read the App names in the workspace (K1, `get apps`), for example `kueue-0.18.0`.
4. Values: write them as an override (skill `nkp-platform-apps-gitops`, file `overrides.md`, O3). Most AI apps have empty defaults: the upstream chart defaults apply. [live 2.19.0]
5. Enable with skill `nkp-platform-apps-gitops`, step 2 (`name` = the app ID, `app` = the App name). `slurm-operator`: enable `cert-manager` first. [live 2.19.0]
6. Check: the HelmRelease is Ready in the workspace namespace of the target cluster. [pdf p.623]

Kueue: the catalog app `kueue:0.18.0` HelmRelease has `targetNamespace: kueue-system`. [field: catalog app tree]

UNKNOWN (D-43): the namespace that each other AI Catalog app (KAI, Slurm, Kubeflow Pipelines, JupyterHub, Milvus) uses on the target cluster. Find out with: `source ~/nkp-<cluster>.env 2>/dev/null && kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get helmreleases -A -o custom-columns='NS:.metadata.namespace,NAME:.metadata.name,TARGET:.spec.targetNamespace'`.

Done when: the HelmRelease of the app shows READY `True`.

## A3. Kueue: queues and GPUs

After the install, Kueue has no queues. [live 2.19.0] An admin makes a `ResourceFlavor`, a `ClusterQueue` (cluster-wide quota), and a `LocalQueue` (one namespace). A Job uses the queue with the label `kueue.x-k8s.io/queue-name: <local queue>`. Kueue 0.18 serves `kueue.x-k8s.io/v1beta2`. [field: chart 0.18.0 CRDs] The lab has no Kueue.

Ask the user for: the flavor name, the quota of CPU, memory, and GPU, the namespaces, and the GPU node labels. Write the YAML with the user values, show it, then apply it after "yes" (CHANGES, `kubectl --kubeconfig "$CLUSTER_KUBECONFIG" apply -f <file>`).

```yaml
apiVersion: kueue.x-k8s.io/v1beta2
kind: ResourceFlavor
metadata:
  name: gpu-flavor
spec:
  nodeLabels:
    nvidia.com/gpu.present: "true"
---
apiVersion: kueue.x-k8s.io/v1beta2
kind: ClusterQueue
metadata:
  name: team-a-cq
spec:
  namespaceSelector: {}
  resourceGroups:
  - coveredResources: ["cpu", "memory", "nvidia.com/gpu"]
    flavors:
    - name: gpu-flavor
      resources:
      - name: cpu
        nominalQuota: "16"
      - name: memory
        nominalQuota: 64Gi
      - name: nvidia.com/gpu
        nominalQuota: "2"
---
apiVersion: kueue.x-k8s.io/v1beta2
kind: LocalQueue
metadata:
  name: team-a
  namespace: team-a
spec:
  clusterQueue: team-a-cq
```

The numbers above are an example. Use the user values.

- The quota name `nvidia.com/gpu` counts pods that ask with limits: device plugin mode (file `nvidia.md`, N4). [live 2.19.0]
- DRA mode (claims for `gpu.nvidia.com`): Kueue needs `resources.deviceClassMappings` in its manager configuration, and the quota name is then `gpu.nvidia.com`. The Helm value `managerConfig.controllerManagerConfigYaml` replaces the full configuration, so the override must hold the full current file plus the mapping. [field: chart 0.18.0] Read the current file first (READ-ONLY): `kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n kueue-system get configmap kueue-system-kueue-manager-config -o jsonpath='{.data.controller_manager_config\.yaml}'`. Flux names the release `kueue-system-kueue`, so the ConfigMap is `kueue-system-kueue-manager-config`. [field: catalog app tree] The mapping:

```yaml
resources:
  deviceClassMappings:
  - name: gpu.nvidia.com
    deviceClassNames:
    - gpu.nvidia.com
```

- Check (READ-ONLY): `kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get clusterqueues,localqueues -A` and `get workloads -A` (ADMITTED column).

## A4. AMD GPUs

- The 2.19 guide names `amd-gpu-operator` (driver build and load, DRA, metrics) and `amd-kmm-operator` (Kernel Module Management for it). [pdf p.296, p.308] AMD Instinct MI350 is validated. [field]
- **On 2.19.0, neither app is a ClusterApp, and neither is in the 2.19.0 AI catalog bundle.** [live 2.19.0] A later version of the online AI catalog adds `amd-kmm-operator` 1.0.0 and `amd-gpu-operator` 1.5.1. [field]

UNKNOWN (D-44): where a 2.19.0 site gets the AMD GPU operator app (a newer AI catalog bundle or another bundle) and its air-gapped steps. Find out with: `source ~/nkp-site.env 2>/dev/null && kubectl --kubeconfig "$MGMT_KUBECONFIG" get apps -A | grep -E 'NAME|amd'`.

If the `amd-*` apps are in `get apps`: enable `amd-kmm-operator` first, then `amd-gpu-operator` (skill `nkp-platform-apps-gitops`, step 2). [field] Facts from the app metadata [field]:
- DRA is on and the device plugin is off by default. The two are mutually exclusive.
- The default `DeviceConfig` named `default` selects nodes with `feature.node.kubernetes.io/amd-gpu: "true"` (from NFD).
- The operator builds the driver in the cluster and needs a registry for the driver image: a Secret `kmm-registry-credentials` in the workspace namespace, and the override `deviceConfig.spec.driver.image` with that registry. The Secret holds a registry password: the user makes it (rule 5).
- Upgrade the operator first and the driver later, in two separate changes.

The detailed AMD values are not in the skills.

## A5. Nutanix Enterprise AI (NAI)

NAI runs LLM inference endpoints. NAI 2.8.0 and 2.8.1 run on NKP 2.19, on management and workload clusters. [pdf p.327-330] Pro or Ultimate. [pdf p.328]

**NAI is not in the 2.19.0 bundle.** The `nkp-nutanix-product-catalog` bundle has only NDK 2.3.0. [live 2.19.0] On a connected site, the NKP UI shows NAI from the online Nutanix product catalog. [pdf p.329] The guide sends air-gapped sites to the separate NAI guide. [pdf p.328]

UNKNOWN (D-45): the air-gapped steps for NAI 2.8 on NKP 2.19 (the NAI bundle, its catalog, and the image overrides). Find out with: `source ~/nkp-site.env 2>/dev/null && kubectl --kubeconfig "$MGMT_KUBECONFIG" get apps -A | grep -E 'NAME|nutanix-ai|kserve|envoy-gateway-nai|leaderworkerset|opentelemetry'`.

Prerequisites on the target cluster, in this order [pdf p.329]:
1. Platform apps: cert-manager, Prometheus monitoring, the NVIDIA GPU operator (SKILL.md step 3), CloudNativePG (skill `nkp-platform-apps-gitops`, file `catalogs.md`, K5).
2. Catalog apps: NAI-Envoy Gateway 1.8.2, KServe 0.19.0, OpenTelemetry Operator 0.114.1, LeaderWorkerSet 0.8.0.
3. A Nutanix Files StorageClass `nai-nfs-storage`: skill `nkp-storage-backup` (file `csi.md`, C5).
4. The Nutanix Docker Hub pull Secret `nai-regcred` in the namespaces `nai-system` and `envoy-gateway-system` (block below). [pdf p.329-330]

The pull Secret uses the Nutanix Docker Hub token (`NUTANIX_REGISTRY_USERNAME`, `NUTANIX_REGISTRY_TOKEN`; skill `nkp-airgap`, step 3). The guide uses `--docker-password` on the command line; this block reads the token from a file in a pipe, so it is not in the process list. Show the plan, stop for "yes":

```bash
# CHANGES  (creates namespace nai-system and the Secret nai-regcred in nai-system and envoy-gateway-system)
source ~/nkp-<cluster>.env 2>/dev/null
k=$(printenv NUTANIX_REGISTRY_USERNAME >/dev/null && printenv NUTANIX_REGISTRY_TOKEN >/dev/null && echo ok); : "${k:?NUTANIX_REGISTRY_USERNAME or NUTANIX_REGISTRY_TOKEN MISSING, see skill nkp-airgap step 3}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" create namespace nai-system --dry-run=client -o yaml | kubectl --kubeconfig "$CLUSTER_KUBECONFIG" apply -f -
for ns in nai-system envoy-gateway-system; do
  printf '{"auths":{"https://index.docker.io/v1/":{"auth":"%s"}}}' "$(printf '%s:%s' "$(printenv NUTANIX_REGISTRY_USERNAME)" "$(printenv NUTANIX_REGISTRY_TOKEN)" | base64 | tr -d '\n')" | kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" create secret generic nai-regcred --type=kubernetes.io/dockerconfigjson --from-file=.dockerconfigjson=/dev/stdin --dry-run=client -o yaml | kubectl --kubeconfig "$CLUSTER_KUBECONFIG" apply -f -
done
```

- `envoy-gateway-system` exists after the NAI-Envoy Gateway app. [pdf p.330]

**Enable NAI.** The guide enables it in the UI (Applications, Nutanix Enterprise AI, Enable, version 2.8.0 or 2.8.1). [pdf p.330] With the CLI, use skill `nkp-platform-apps-gitops`, step 2, with the `nutanix-ai-*` App name from `get apps`. The override (O3 there) has at least [pdf p.330]:

```yaml
global:
  imagePullSecrets:
    - name: nai-regcred
naiDatabase:
  enablePDB: false
```

- Profiles: default (300 concurrent requests, 100 API keys), `c1k_k200` (1000, 200), `c5k_k1k` (5000, 1000). The profile values are long. They are in the guide (Table 37 and the two overrides). [pdf p.331-335] Not in the skills.
- After the enable: the NAI dashboard uses the service external IP. The user makes a DNS record for it. NAI uses a self-signed certificate by default. [pdf p.331]
- Check (READ-ONLY): `kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n nai-system get pods` (all `Running`) and `-n envoy-gateway-system get pods`. [pdf p.336]

**Upgrade NAI.** Only from NAI 2.7.0 to 2.8.x. [pdf p.335] Edit the app, select the version, keep the override. [pdf p.336]

**Kubernetes upgrade of a cluster with NAI.** The guide adds replicas before the upgrade. [pdf p.336-337] Reason: with the default (non-profile) config, single NAI pods can block the node drain. [field] Before the upgrade, add the replica values of the guide to the override (`naiApi.replicaCount: 2`, `gateway.replicaCount: 2`, and the CPU requests on p.336). After the upgrade, go back to the default override. [pdf p.336-337] Profile configs already have more replicas. [pdf p.337]

## A6. AI Navigator

AI Navigator is a chat assistant in the NKP UI. It needs internet: it uses Azure OpenAI through Nutanix, or your own Azure OpenAI. **Nutanix does not support it in an air gap.** [pdf p.1073] NKP installs it by default with Pro or Ultimate; from 2.19, the NKP MCP Server comes with it. [pdf p.1074-1075] It needs CloudNativePG (gate G6: skill `nkp-platform-apps-gitops`, file `catalogs.md`, K5).

To disable it (CHANGES, plan and "yes"): skill `nkp-platform-apps-gitops`, step 2, "Disable", with `name` `ai-navigator-app` on the management cluster. [pdf p.1075]
