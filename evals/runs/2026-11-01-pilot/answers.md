I could only read files under `skills/` this session (two skills are installed: `nkp`, `nkp-install`). **I have no write tool**, so per the task instructions the full `answers.md` content is below.

Files available and used:
- `skills/nkp/SKILL.md`, `skills/nkp/references/components.md`
- `skills/nkp-install/SKILL.md`, `skills/nkp-install/references/nutanix.md`

Not installed (checked): `nkp-cluster-lifecycle`, `nkp-observability`, `nkp-storage-backup`, `nkp-networking`, `nkp-troubleshooting`, `nkp-airgap`, `nkp-gpu-ai`. Every answer that needs one says so and falls back to the router map + READ-ONLY commands, as the rules require.

---

# answers.md

## nkp E1

**Skill files read:** `nkp/SKILL.md`, `nkp/references/components.md`.

**Two skills are missing:** the day-2 steps for node pools live in `nkp-cluster-lifecycle`, and the GPU operator steps in `nkp-gpu-ai`.
> Skill `nkp-cluster-lifecycle` is not installed. Skill `nkp-gpu-ai` is not installed.

So I can give you the map facts and the read-only commands that find the edit. I cannot give you a tested edit recipe.

**Short answer:** not the `Cluster` object. Edit the **NKPCluster**.

- `NKPCluster` (`clusters.nkp.nutanix.com/v1alpha1`) owns the CAPI `Cluster` and the `KommanderCluster`. [live 2.19.0]
- A direct edit of `Cluster.spec.topology` is rejected by the webhook: "CAPI Cluster topology spec is managed by NKPCluster". [pdf p.1048]
- The node-pool surface is the ClusterClass variables `clusterConfig` and `workerConfig`, class `nkp-nutanix-v2.19.0`. [live 2.19.0]

**Before I plan anything:**

1. Which tier is the site? GPU operators are a **Pro** feature; Starter is AHV only with no add-on apps. [pdf p.26-28]
2. Which namespace is the workload cluster in (workspace namespace, for example `kommander-default-workspace`)?
3. NVIDIA or AMD? (Two different operators. [pdf p.295-297])
4. Does the new pool need the whole GPU or MIG / time-slicing?

**Read-only facts I would collect (tell me what each shows and stop):**

```bash
# READ-ONLY
kubectl --kubeconfig <MGMT_KUBECONFIG> get licenses.kommander.mesosphere.io -o jsonpath='{.items[*].status.dkpLevel}{"\n"}'
kubectl --kubeconfig <MGMT_KUBECONFIG> get nkpclusters -A
kubectl --kubeconfig <MGMT_KUBECONFIG> -n <WORKSPACE_NS> get nkpcluster <CLUSTER_NAME> -o yaml
kubectl --kubeconfig <MGMT_KUBECONFIG> -n <WORKSPACE_NS> get clusterclass nkp-nutanix-v2.19.0 -o yaml
kubectl --kubeconfig <MGMT_KUBECONFIG> explain nkpcluster.spec
kubectl --kubeconfig <MGMT_KUBECONFIG> get clusterapps -o custom-columns='NAME:.metadata.name,TIER:.metadata.annotations.apps\.kommander\.d2iq\.io/licensing' | grep -i -E 'nvidia|gpu'
kubectl --kubeconfig <MGMT_KUBECONFIG> -n <WORKSPACE_NS> get machinepools,machinedeployments
```

What I check in each:
- `licenses` → if it prints `Starter`, stop here: no GPU operator. The fix is a Pro license, and the tier is fixed at registration, you cannot go down later. [pdf p.26]
- `get nkpclusters` → the NKP VERSION / KUBERNETES VERSION / PHASE columns; PHASE must be `Reconciled` before an edit.
- `clusterclass ... -o yaml` → the `workerConfig` variable schema: that is where the node pool list lives.
- `explain nkpcluster.spec` → the exact field names on your version. `UNKNOWN (E1-A): the exact NKPCluster field path for an extra worker pool. Find out with: kubectl --kubeconfig <MGMT_KUBECONFIG> explain nkpcluster.spec`. I will not invent that path.
- `clusterapps` → whether an NVIDIA/GPU ClusterApp exists on your cluster and which tier it needs.
- `machinepools`/`machinedeployments` → the pools that exist today, so a new one is additive.

**Where I stop:** after those commands. The edit itself (a YAML patch to `spec.workerConfig` + the GPU ClusterApp/AppDeployment) is `# CHANGES`, it needs the missing `nkp-cluster-lifecycle` skill, and it needs your "yes" after I show you the plan: the target cluster, the namespace, the patch, and the expected result (new `MachineDeployment` Ready, NFD labels on the new nodes, GPU operator pods Running).

## nkp E2

**Skill files read:** `nkp/SKILL.md`, `nkp/references/components.md`.

> Skill `nkp-observability` is not installed. Skill `nkp-storage-backup` is not installed. Skill `nkp-platform-apps-gitops` is not installed.

**Answer: no, not on the tier they have.** On **Starter**:

- Only Nutanix AHV is supported, and **monitoring and logging apps are not available**. [pdf p.26-28, p.715]
- Velero is a **Pro** app. kube-prometheus-stack (Prometheus/Grafana) is **Pro**. Central Grafana is **Ultimate**. [pdf p.295-297]
- You cannot go to a lower tier after registration, but you can go up to Pro. [pdf p.26]

**Read-only check — proves it on their cluster instead of trusting me:**

```bash
# READ-ONLY
kubectl --kubeconfig ~/mgmt.conf -n kommander get licenses.kommander.mesosphere.io -o jsonpath='{.items[*].status.dkpLevel}{"\n"}'
kubectl --kubeconfig ~/mgmt.conf get clusterapps -o custom-columns='NAME:.metadata.name,TIER:.metadata.annotations.apps\.kommander\.d2iq\.io/licensing' | grep -i -E 'velero|prometheus|grafana|loki'
kubectl --kubeconfig ~/mgmt.conf get appdeployments -A
```

What I check:
- First command prints the tier, not the name I was told. If it prints `Starter`, the next two lines decide the rest.
- Second command: the `TIER` column of `velero`, `kube-prometheus-stack`, `grafana`. If those apps are not in the list at all on Starter, there is nothing to enable.
- Third command: only apps already deployed. An empty line for `velero`/`kube-prometheus-stack` confirms they are off.

**What to tell the customer:** get a Pro license first. Two side conditions, so they are not surprised:
- After a license upgrade to Pro, the Starter minimum of **2 workers is too small** and the Pro apps fail; the Pro minimum is 3 control-plane (4 vCPU, 16 GiB) and 4 workers (8 vCPU, 32 GiB). [pdf p.695-696]
- Air-gapped does not change the tier answer. The apps come from the bundle in either case.

**Nothing to approve:** no CHANGES command is possible or useful here. If they buy Pro, the enable steps are `# CHANGES` and belong to the skills that are not installed; I would say so and not guess them.

## nkp E3

**Skill files read:** `nkp/SKILL.md`, `nkp/references/components.md`.

I will not give you numbers from memory. The NGP rules say read versions from the cluster or from `nkp version`, and in NKP **the catalog version, the chart version, and the image version of one app can all be different**. [live 2.19.0]

```bash
# READ-ONLY
nkp version
kubectl --kubeconfig <MGMT_KUBECONFIG> get clusterapps | grep -E 'cert-manager|traefik'
kubectl --kubeconfig <MGMT_KUBECONFIG> get helmreleases -A | grep -E 'cert-manager|traefik'
kubectl --kubeconfig <MGMT_KUBECONFIG> get helmchartproxies -A
kubectl --kubeconfig <MGMT_KUBECONFIG> get pods -A -o jsonpath='{range .items[*]}{range .spec.containers[*]}{.image}{"\n"}{end}{end}' | sort -u | grep -E 'cert-manager|traefik'
```

What I read out of it, and which number answers which question:
- `clusterapps` → the **catalog** version, cluster-scoped. This is the version NKP 2.19 ships.
- `helmreleases` → the **chart** version, in the status text. This is the running chart.
- `helmchartproxies` → the CAREN add-on charts (the ones CAREN installs, not the Kommander platform apps).
- the image jsonpath → the **image tag**, which is what "are we really running X" means.

Two things to note while I read them:
- Traefik exists twice in some outputs: the platform app (`kommander` namespace, chart) and the Kommander UI ingress service `kommander/kommander-traefik`. The service is not a version. [live 2.19.0]
- cert-manager also appears in `cert-manager` namespace as the cluster add-on. Report both if both appear.

`UNKNOWN (E3-A): the installed cert-manager and Traefik versions on this cluster. Find out with: the four commands above.` If your cluster is not reachable from this session, give me the `helmreleases` output and I will read the versions off it. Nothing else is confirmed offline — the bundle's release spec is the only offline second source, and `nkp-airgap` (bundle contents) is not installed here.

## nkp E4

**Skill files read:** `nkp/SKILL.md`, `nkp/references/components.md`.

> Skill `nkp-networking` is not installed. Skill `nkp-troubleshooting` is not installed.

**No. It is MetalLB.**

- Service `LoadBalancer` IPs on AHV come from **MetalLB**. The pool is the `--kubernetes-service-load-balancer-ip-range` you gave at create time. [live 2.19.0]
- The **Nutanix CCM** only gives node metadata (zone, region, host). It does not allocate service IPs. [live 2.19.0]
- **kube-vip** holds only the control-plane VIP. Do not chase it. [live 2.19.0]

`EXTERNAL-IP: <pending>` therefore means MetalLB has no free address or is not speaking. Usual causes, in order:

1. Pool exhausted (each `LoadBalancer` service takes one IP; extra apps such as NDK need more). [pdf p.693]
2. No `IPAddressPool` / no `L2Advertisement` for the node subnet.
3. MetalLB speakers not running (they must run on the workers that own that L2 segment).
4. The service asks for a specific IP or a class that does not exist in the pool.

```bash
# READ-ONLY
kubectl --kubeconfig <CLUSTER_KUBECONFIG> -n <NAMESPACE> get svc <SERVICE_NAME> -o wide
kubectl --kubeconfig <CLUSTER_KUBECONFIG> -n <NAMESPACE> describe svc <SERVICE_NAME>
kubectl --kubeconfig <CLUSTER_KUBECONFIG> -n <NAMESPACE> get events --field-selector involvedObject.name=<SERVICE_NAME>
kubectl --kubeconfig <CLUSTER_KUBECONFIG> -n metallb-system get pods -o wide
kubectl --kubeconfig <CLUSTER_KUBECONFIG> -n metallb-system get ipaddresspools,l2advertisements -o yaml
kubectl --kubeconfig <CLUSTER_KUBECONFIG> get ipaddresspool -A -o yaml | grep -E 'addresses|allocated|autoAssign'
kubectl --kubeconfig <CLUSTER_KUBECONFIG> -n kube-system get pods | grep -i -E 'ccm|cloud-controller'
kubectl --kubeconfig <MGMT_KUBECONFIG> -n <WORKSPACE_NS> get nkpcluster <CLUSTER_NAME> -o yaml | grep -A2 loadBalancer
```

What I check:
- `describe svc` events say `MetalLB` or say nothing → MetalLB side. If it names the CCM → different path, and then the CCM pods matter.
- `ipaddresspools -o yaml` → the `addresses` range. Count how many `LoadBalancer` services already exist against the range size. A pool of N IPs and N services = the next one stays `pending` forever.
- `l2advertisements -o yaml` → is the node subnet covered, and are the node selectors right?
- `metallb-system` pods → `controller` `Running`, `speaker` `Running` on the worker nodes, and check the speaker logs for "no available IP".
- `grep -A2 loadBalancer` on the NKPCluster → the range the cluster was **created** with. If the range is smaller than the site needs, that is not a bug; it needs a range change, which is a `# CHANGES` action on the NKPCluster and outside the installed files.

**Where I stop:** after those commands. I show you the finding (pool full, or no advertisement, or speakers down) and the plan, then wait for "yes" before any `# CHANGES` command.

## nkp E5

**Skill files read:** `nkp/SKILL.md`, `nkp/references/components.md`.

Both are part of the Cluster API stack on the management cluster, because the management cluster holds the CAPI objects for itself **and** for its workload clusters. [live 2.19.0]

**`capx-system` — CAPX, the Nutanix AHV infrastructure provider.** [live 2.19.0]
- It is the controller that calls the **Prism Central API**.
- It reconciles `NutanixCluster` and `NutanixMachineTemplate` (`infrastructure.cluster.x-k8s.io`) into real VMs: create, delete, and the machine addresses.
- Version seen on one live 2.19.0 cluster: v1.10.15. Read yours, do not quote mine.

**`caren-system` — CAREN, the Cluster API Runtime Extensions for Nutanix.** [live 2.19.0]
- Deployment `cluster-api-runtime-extensions-nutanix` (v0.62.7 on one live 2.19.0 cluster).
- It takes the two ClusterClass variables `clusterConfig` and `workerConfig` and patches them into the real CAPI objects.
- It installs the **cluster add-ons** through CAAPH `HelmChartProxy` objects: Cilium, MetalLB, Nutanix CCM, Nutanix CSI, snapshot controller, NFD, cluster autoscaler, COSI, konnector-agent.
- It also runs the **in-cluster add-on chart registry** `helm-repository` in that namespace. The add-on charts come from there.

```bash
# READ-ONLY
kubectl --kubeconfig <MGMT_KUBECONFIG> -n caren-system get all,cm
kubectl --kubeconfig <MGMT_KUBECONFIG> -n caren-system get deploy -o jsonpath='{range .items[*]}{.metadata.name} {.spec.template.spec.containers[*].image}{"\n"}{end}'
kubectl --kubeconfig <MGMT_KUBECONFIG> -n capx-system get all
kubectl --kubeconfig <MGMT_KUBECONFIG> -n capx-system get deploy -o jsonpath='{range .items[*]}{.metadata.name} {.spec.template.spec.containers[*].image}{"\n"}{end}'
kubectl --kubeconfig <MGMT_KUBECONFIG> get helmchartproxies -A
kubectl --kubeconfig <MGMT_KUBECONFIG> -n caaph-system get pods
```

What I check: the image tag of each Deployment (that is the version, read from **your** cluster, per rule 6); that `caren-system` pods are `Running` before you edit any node pool, because a broken CAREN means a cluster edit that never reaches the add-ons; and that the `HelmChartProxy` names follow `<addon>-<cluster-uid>`.

Read-only skill: `components.md` is the map for every other namespace on that cluster.

## nkp-install E1

**Skill files read:** `nkp-install/SKILL.md`, `nkp-install/references/nutanix.md`.

> Skill `nkp-airgap` is not installed. The Nutanix file has the `--bundle` steps, so I can still give you the create command; for registry/mirror design later, say the word and I will flag what is unconfirmed.

**Case:** first cluster = management cluster, air-gapped, **no site registry** → nutanix.md section **4B** (internal registry mirror via `--bundle`). Do not combine `--bundle` with `--registry-mirror-*`. [pdf p.725]

**Values you gave:** PC `pc.example.local`, PE cluster `PE01`, subnet `k8s-vlan`, storage container `default-container`, image `nkp-rocky-9.8-release-1.36.2`, bundle `/opt/nkp-v2.19.0`.

**I still need (rule 3, I do not guess these):**

1. Cluster name (`<CLUSTER_NAME>`, only `a-z 0-9 . -`). [pdf p.718]
2. Control-plane VIP (`<CP_VIP>`): a free static IP in `k8s-vlan`, **outside** the IPAM/DHCP pool. [pdf p.720]
3. Service LB range (`<LB_IP_RANGE>` as `<first>-<last>`): same L2 segment as the workers, outside the pool. The NKP UI takes the first IP. [pdf p.694, p.721]
4. SSH public key file (`<SSH_PUBKEY_FILE>`): the user `konvoy` gets this key on every node.
5. NTP servers (`<NTP_SERVERS>`): **mandatory on an air-gapped site**. [pdf p.724]
6. Is the Prism Central certificate trusted by this bastion? If not, `<PC_CA_FILE>` (the PC certificate only, not a full CA bundle). [pdf p.719]
7. Prism Central project (`<PC_PROJECT>`)? Optional.
8. Exported in your own shell, never shown to me: `NUTANIX_USER`, `NUTANIX_PASSWORD`.

Also: the image name must contain the Kubernetes version [pdf p.726]. `nkp-rocky-9.8-release-1.36.2` does. Preflight will confirm it exists in PC and reaches `PE01`.

**Step A — checks (READ-ONLY):**

```bash
# READ-ONLY
/opt/nkp-v2.19.0/cli/nkp version
docker version --format '{{.Server.Version}}'
stat -fc %T /sys/fs/cgroup
nproc; free -g; df -h "${TMPDIR:-/tmp}"
curl -sk -o /dev/null -w '%{http_code}\n' https://pc.example.local:9440
ping -c 2 <CP_VIP>
ls /opt/nkp-v2.19.0/container-images/
```

What I check: the `nkp` line shows 2.19.0 (else use the bundle binary and stop) [live 2.19.0]; Docker 27.4.0 or later [pdf p.48-49]; `cgroup2fs`; 4 CPU and 4 GB free for the bootstrap; `/tmp` has room for the bundle push (else `export TMPDIR=<big dir>`) [pdf p.694]; `curl` returns any HTTP code but not `000`; `ping` to the VIP gets no reply; the `container-images/` list shows the image bundle tar names — I use the names `ls` prints, not the ones from another release.

**Step B — load the bootstrap image (CHANGES, one line):**

```bash
# CHANGES
docker load --input /opt/nkp-v2.19.0/konvoy-bootstrap-image-v2.19.0.tar
```

**Step C — dry run first (READ-ONLY, writes a local file only):**

```bash
# READ-ONLY
/opt/nkp-v2.19.0/cli/nkp create cluster nutanix \
  --self-managed \
  --cluster-name <CLUSTER_NAME> \
  --endpoint https://pc.example.local:9440 \
  --control-plane-endpoint-ip <CP_VIP> \
  --control-plane-prism-element-cluster PE01 \
  --control-plane-subnets k8s-vlan \
  --control-plane-vm-image nkp-rocky-9.8-release-1.36.2 \
  --worker-prism-element-cluster PE01 \
  --worker-subnets k8s-vlan \
  --worker-vm-image nkp-rocky-9.8-release-1.36.2 \
  --csi-storage-container default-container \
  --kubernetes-service-load-balancer-ip-range <LB_IP_RANGE> \
  --ssh-public-key-file <SSH_PUBKEY_FILE> \
  --ntp-servers <NTP_SERVERS> \
  --dry-run --output yaml > <CLUSTER_NAME>.yaml
```

**Step D — the plan I show you, then wait for "yes":**

```
Target: a new kind bootstrap cluster on this bastion, then VMs in Prism Central
        (PE01, subnet k8s-vlan), then the pivot. Management cluster, self-managed.
Effect: 3 control-plane nodes + 4 workers by default [live 2.19.0], your NKPCluster
        in namespace kommander, and Kommander installed for you on AHV [pdf p.47].
Runs  : nkp create cluster nutanix --self-managed ... --airgapped --bundle <3 tars>
Waits : until the cluster is Ready and the pivot is done (default --timeout 30m;
        add --timeout 60m on a slow site).
```

**Step E — the create (CHANGES, only after "yes"):**

```bash
# CHANGES
/opt/nkp-v2.19.0/cli/nkp create cluster nutanix \
  --self-managed \
  --cluster-name <CLUSTER_NAME> \
  --endpoint https://pc.example.local:9440 \
  --control-plane-endpoint-ip <CP_VIP> \
  --control-plane-prism-element-cluster PE01 \
  --control-plane-subnets k8s-vlan \
  --control-plane-vm-image nkp-rocky-9.8-release-1.36.2 \
  --worker-prism-element-cluster PE01 \
  --worker-subnets k8s-vlan \
  --worker-vm-image nkp-rocky-9.8-release-1.36.2 \
  --csi-storage-container default-container \
  --kubernetes-service-load-balancer-ip-range <LB_IP_RANGE> \
  --ssh-public-key-file <SSH_PUBKEY_FILE> \
  --ntp-servers <NTP_SERVERS> \
  --airgapped \
  --bundle /opt/nkp-v2.19.0/container-images/konvoy-image-bundle-v2.19.0.tar,/opt/nkp-v2.19.0/container-images/kommander-image-bundle-v2.19.0.tar,/opt/nkp-v2.19.0/container-images/nkp-release-specs-v2.19.0.tar
```

Notes: the `konvoy` and `kommander` bundles are mandatory; add the product-catalog bundle only if you want NDK. [live 2.19.0] If PC uses a self-signed certificate, add `--additional-trust-bundle "$(base64 < <PC_CA_FILE> | tr -d '\n')"` and check it in the dry-run YAML first. [pdf p.719] Add `--pc-project <PC_PROJECT>` if you use one.

**Step F — verify (READ-ONLY):**

```bash
# READ-ONLY
/opt/nkp-v2.19.0/cli/nkp get kubeconfig --cluster-name <CLUSTER_NAME> --namespace kommander > <CLUSTER_NAME>.conf
/opt/nkp-v2.19.0/cli/nkp describe cluster --cluster-name <CLUSTER_NAME> --namespace kommander --kubeconfig <CLUSTER_NAME>.conf
kubectl --kubeconfig <CLUSTER_NAME>.conf get nodes
kubectl --kubeconfig <CLUSTER_NAME>.conf get pods -A | grep -v -E 'Running|Completed'
kubectl --kubeconfig <CLUSTER_NAME>.conf -n kommander get helmreleases
```

Pass: `True` for the cluster, control plane, and every machine; PHASE `Reconciled`; all nodes `Ready`; the filtered pod list empty; HelmReleases `Ready`.

## nkp-install E2

**Skill files read:** `nkp-install/SKILL.md`, `nkp-install/references/nutanix.md`.

**Ubuntu 24.04: no, not on Starter.** Starter supports **only the Nutanix Rocky Linux image**. Ubuntu needs Pro or Ultimate. [pdf p.715] Use the pre-built Nutanix Rocky Linux 9.8 image; do not rename an image that came from the Nutanix portal. [pdf p.55-56, p.715]

**Smallest management cluster on Starter** — the CLI defaults (3 control-plane 4 vCPU/16 GiB, 4 workers 8 vCPU/32 GiB) are the Pro/Ultimate minimum, not the Starter one. [live 2.19.0] Add these [pdf p.695]:

```
--control-plane-vcpus 2 --control-plane-memory 8 --worker-replicas 2 --worker-vcpus 4 --worker-memory 8
```

Two things to know before you pick that:
- **2 workers is a dead end if you ever buy Pro.** Pro/Ultimate apps fail on a 2-worker cluster after the license upgrade. [pdf p.695] If Pro is likely, keep 4 workers now.
- Pod CIDR (`192.168.0.0/16`) and service CIDR (`10.96.0.0/12`) cannot be changed after the create. [pdf p.724] Check the overlap now, not later.

**Then the normal first-cluster questions** (I cannot fill these for you, rule 3): cluster name, `<PC_ENDPOINT>`, `<PE_CLUSTER>`, `<SUBNET>`, `<STORAGE_CONTAINER>`, `<VM_IMAGE>` (the Rocky 9.8 image — its name must contain the Kubernetes version), `<CP_VIP>`, `<LB_IP_RANGE>`, `<SSH_PUBKEY_FILE>`, and `<NTP_SERVERS>` if the site is air-gapped (mandatory there). [pdf p.724] Plus the case: connected, air-gapped with `--bundle`, or site registry mirror. Tell me which and I give you the exact `nkp create cluster nutanix --self-managed ...` line, dry-run first, then wait for "yes".

`UNKNOWN (I-E2-A): the exact Kubernetes version string in your Rocky image name. Find out with: ls of the Prism Central image list, or ask the PC admin.` The name must contain the version, for example `1.36.2`. [pdf p.726]

## nkp-install E3

**Skill files read:** `nkp-install/SKILL.md`, `nkp-install/references/nutanix.md`.

**This is a value problem, not a bug. Do not use `--skip-preflight-checks`.** [pdf p.726]

The error names the check and the flag: `Check: NutanixVMImage`, `Flag: --worker-vm-image`. [pdf p.725] Three rules decide it:

1. The image name **must contain the Kubernetes version** (for example `1.36.2`). [pdf p.726]
2. The name must be the **exact** name in Prism Central. Images from the Nutanix portal must not be renamed. [pdf p.715]
3. The **image placement policy** must allow that image on your PE cluster. [pdf p.713]

`rocky-nkp` breaks rule 1. That alone explains `found 0`: the check looks for an image whose name carries the version NKP deploys.

**Read-only facts to confirm it:**

```bash
# READ-ONLY
nkp create cluster nutanix --help | grep -E -- '--(kubernetes-version|worker-vm-image|control-plane-vm-image) '
nkp create cluster nutanix --help | grep -i 'vm-image'
```

What I check: the default `--kubernetes-version` for this CLI, and whether both `--worker-vm-image` and `--control-plane-vm-image` exist as flags (2.19 has both, and both must point at an image that exists).

Then get the **exact** image name from Prism Central (the PC image list, or your PC admin): `UNKNOWN (I-E3-A): the exact VM image names in Prism Central and their placement. Find out with: the Prism Central image list, or ask the PC admin.` I will not guess a name and I will not derive it from memory.

**Then retry** with the corrected name on both flags. Keep the rest of your flags, dry-run first:

```bash
# READ-ONLY
nkp create cluster nutanix ... --control-plane-vm-image <VM_IMAGE> --worker-vm-image <VM_IMAGE> --dry-run --output yaml > retry.yaml
```

```bash
# CHANGES  (re-runs preflight, then creates; I show the plan and wait for "yes")
nkp create cluster nutanix ... --control-plane-vm-image <VM_IMAGE> --worker-vm-image <VM_IMAGE>
```

If the exact name is still rejected, the next suspect is the **placement policy** (image not allowed on that PE cluster), not the name. [pdf p.713] If the image is a custom build, that build belongs to the air-gap image path and `nkp-airgap` is not installed, so I would tell you that instead of improvising.

## nkp-install E4

**Skill files read:** `nkp-install/SKILL.md`, `nkp-install/references/nutanix.md`.

**Case:** nutanix.md section **5** — a workload cluster from an existing management cluster. No `--self-managed`. Namespace is the **workspace**, not `kommander` (which is for the management cluster only). [live 2.19.0]

**Read-only first — confirm the workspace and the mirror the management cluster actually uses:**

```bash
# READ-ONLY
kubectl --kubeconfig ~/mgmt.conf get workspaces -A
kubectl --kubeconfig ~/mgmt.conf -n kommander get nkpclusters -o jsonpath='{.items[*].spec.kommanderCluster.spec.ociRegistry.mirrorURL}{"\n"}'
nkp version
```

What I check: a `kommander-default-workspace` namespace exists (that is the default workspace [live 2.19.0]); the second command prints your Harbor URL — an **empty line means no site mirror**, and then the create must not be given mirror flags. If the management cluster was built with `--bundle` (no site mirror), this skill has **no tested steps** for a workload cluster: I would stop and tell you that, not improvise. [nutanix.md §5]

**Values I need** (rule 3): a **new** `<CP_VIP>` and a **new** `<LB_IP_RANGE>` — never the management cluster's. [nutanix.md §5] Plus `<STORAGE_CONTAINER>`, `<VM_IMAGE>`, `<SSH_PUBKEY_FILE>`, `<NTP_SERVERS>` (mandatory air-gapped), `<REGISTRY_CA_FILE>`, and `REGISTRY_MIRROR_USERNAME` / `REGISTRY_MIRROR_PASSWORD` exported in your shell, not typed here.

**Plan I show, then wait for "yes":**

```
Target: management cluster (kubeconfig ~/mgmt.conf)
Namespace: kommander-default-workspace   <- the workspace, not kommander
Effect: new VMs in Prism Central for the workload cluster dev-01; first MetalLB
        service IP = first address of its LB range.
Waits : until the workload cluster is Ready (raise with --timeout 60m if slow).
```

```bash
# CHANGES
nkp create cluster nutanix \
  --kubeconfig ~/mgmt.conf \
  --namespace kommander-default-workspace \
  --cluster-name dev-01 \
  --endpoint <PC_ENDPOINT> \
  --control-plane-endpoint-ip <CP_VIP> \
  --control-plane-prism-element-cluster <PE_CLUSTER> \
  --control-plane-subnets <SUBNET> \
  --control-plane-vm-image <VM_IMAGE> \
  --worker-prism-element-cluster <PE_CLUSTER> \
  --worker-subnets <SUBNET> \
  --worker-vm-image <VM_IMAGE> \
  --csi-storage-container <STORAGE_CONTAINER> \
  --kubernetes-service-load-balancer-ip-range <LB_IP_RANGE> \
  --ssh-public-key-file <SSH_PUBKEY_FILE> \
  --ntp-servers <NTP_SERVERS> \
  --control-plane-vcpus 2 --control-plane-memory 6 --worker-replicas 2 --worker-vcpus 3 --worker-memory 6 \
  --airgapped \
  --registry-mirror-url <REGISTRY_URL> \
  --registry-mirror-cacert <REGISTRY_CA_FILE> \
  --registry-mirror-username "$REGISTRY_MIRROR_USERNAME" \
  --registry-mirror-password "$REGISTRY_MIRROR_PASSWORD" \
  --dry-run --output yaml > dev-01.yaml
```

(That last line makes it READ-ONLY; I run it first. The CHANGES run is the same command without `--dry-run`, after your "yes".)

The sizing flags are the **Starter** managed-cluster minimum [pdf p.695-696]. Drop them if your tier is Pro or Ultimate, which need the 4-worker sizing.

**Verify (READ-ONLY):**

```bash
# READ-ONLY
nkp get kubeconfig --cluster-name dev-01 --namespace kommander-default-workspace --kubeconfig ~/mgmt.conf > dev-01.conf
kubectl --kubeconfig ~/mgmt.conf -n kommander-default-workspace get nkpclusters
kubectl --kubeconfig dev-01.conf get nodes
kubectl --kubeconfig dev-01.conf get storageclass
kubectl --kubeconfig dev-01.conf get pods -A | grep -v -E 'Running|Completed'
```

Pass: NKPCluster PHASE `Reconciled`; nodes `Ready`; `nutanix-volume` is the default StorageClass; the filtered pod list empty. [live 2.19.0]

## nkp-install E5

**Skill files read:** `nkp-install/SKILL.md`, `nkp-install/references/nutanix.md`.

**Probably not — check first, do not just run it.**

On **Nutanix AHV**, `nkp create cluster nutanix --self-managed` installs Kommander for you. [pdf p.47] If that is how you created the management cluster, there is nothing to install; running the installer again is wasted time at best.

If you did the **manual** flow (`create bootstrap` → `create cluster` → `capi-components` → `move capi-resources` → `delete bootstrap`) or a non-AHV provider, Kommander is **not** installed and you must install it. [pdf p.667]

```bash
# READ-ONLY
kubectl --kubeconfig ~/mgmt.conf get ns kommander-flux
kubectl --kubeconfig ~/mgmt.conf -n kommander get helmreleases
kubectl --kubeconfig ~/mgmt.conf get storageclass
nkp describe cluster --cluster-name <CLUSTER_NAME> --namespace kommander --kubeconfig ~/mgmt.conf
```

What decides it:
- `kommander-flux` exists **and** the HelmReleases are `Ready` → already installed. Done. Skip to verify (below).
- namespace missing, or HelmReleases not `Ready` → Kommander is missing or half-installed.
- **No default StorageClass** → fix storage first; Kommander needs one.
- `nkp describe cluster` not `True` for cluster, control plane, and every machine → fix that before touching Kommander.

**If it is missing, the plan (CHANGES, I wait for "yes"):**

```bash
# READ-ONLY  (writes a local file only)
nkp install kommander --init --airgapped > kommander.yaml
```

I show you `kommander.yaml` before anything runs. Change it only for what you ask (domain, certificate, proxy). Note: on an air-gapped site AI Navigator is not installed. [pdf p.942]

```bash
# CHANGES  (installs Kommander and the platform apps; default wait 1h15m [live 2.19.0])
nkp install kommander --installer-config kommander.yaml --kubeconfig ~/mgmt.conf
```

If it fails or times out, run the same command again — it continues. [pdf p.944] Add `--wait-timeout 2h` on a slow site.

**Then verify (READ-ONLY):**

```bash
# READ-ONLY
kubectl --kubeconfig ~/mgmt.conf -n kommander wait --for condition=Ready helmreleases --all --timeout 15m
kubectl --kubeconfig ~/mgmt.conf get appdeployments -A
nkp get dashboard --kubeconfig ~/mgmt.conf   # prints the admin password: run it in your own terminal, do not paste the output
```

---

## Summary

- Wrote all 10 replies. **`answers.md` could not be created: this session has no write tool** (only `read` and `caller_ping`), so the full file content is the body above, under the `# answers.md` heading.
- Probed `skills/` and found only **`nkp`** (`SKILL.md` + `references/components.md`) and **`nkp-install`** (`SKILL.md` + `references/nutanix.md`) installed. `nkp-cluster-lifecycle`, `nkp-observability`, `nkp-storage-backup`, `nkp-networking`, `nkp-troubleshooting`, `nkp-airgap`, `nkp-gpu-ai` are **not installed**, so E1 (nkp), E2 (nkp), E4 (nkp) and parts of E1/E3 (nkp-install) say so explicitly and answer only from the router map plus READ-ONLY commands.
- Every command block carries `# READ-ONLY` / `# CHANGES`, every CHANGES block shows target + effect + result and waits for "yes", credentials stay as environment variable names, and no version was given from memory (E3 and E5 read versions from the cluster).

Skipped: I did not attempt to write the file by any other means, and I did not verify how the missing skills were meant to phrase the node-pool edit. Risk: three of ten answers are deliberately partial because their owning skill does not exist — that is the installed-state behaviour, not a gap in the answers.