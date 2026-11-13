# nkp-skills pilot test run 2 — 16 answers

Skills installed in this session: `nkp` (SKILL.md + references/components.md), `nkp-install` (SKILL.md + references/nutanix.md + references/kommander.md).
Every other skill named by the router (`nkp-airgap`, `nkp-cluster-lifecycle`, `nkp-upgrade`, `nkp-troubleshooting`, `nkp-networking`, `nkp-platform-apps-gitops`, `nkp-identity-security`, `nkp-storage-backup`, `nkp-observability`, `nkp-gpu-ai`, `nkp-flow-cni`, `nkp-vpc`, `nkp-ndk`, `kubernetes-core`) is **not installed** here.

---

## nkp E1

**Files read:** `nkp/SKILL.md`, `nkp/references/components.md`

**Which skill:** the job ("NKPCluster edits, node pools") is skill `nkp-cluster-lifecycle`.

**Skill `nkp-cluster-lifecycle` is not installed.** So I give you only READ-ONLY checks from the `nkp` skill, and no CHANGES command.

What I can tell you from `nkp`:

- You do **not** edit the CAPI `Cluster` object. NKPCluster (`clusters.nkp.nutanix.com/v1alpha1`) owns the `Cluster` and the `KommanderCluster`. A webhook rejects a direct edit of `Cluster.spec.topology` with "CAPI Cluster topology spec is managed by NKPCluster". [pdf p.1048][live 2.19.0]
- So you edit the **NKPCluster**, in the workspace namespace of that workload cluster (for example `kommander-default-workspace`), not in `kommander` (that namespace holds the management NKPCluster). [live 2.19.0]
- The node-pool shape comes from the ClusterClass variables `clusterConfig` and `workerConfig` (the CAREN variable surface). Class name is `nkp-nutanix-v2.19.0`, worker class `default-worker`. [live 2.19.0] The exact `workerConfig` fields for a GPU pool are in `nkp-cluster-lifecycle`. They are not in the skills installed here.
- Check your tier before you plan the pool: the GPU operators are in the **Pro** app list [pdf p.295-297]. Starter has no Pro apps.
- NFD (node labels for the GPU operators) and cluster autoscaler are CAREN addons on AHV. [live 2.19.0]

READ-ONLY checks that I can give now:

```bash
# READ-ONLY
source ~/nkp-site.env
kubectl --kubeconfig "$MGMT_KUBECONFIG" get nkpclusters -A
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get nkpcluster "$CLUSTER_NAME" -o yaml
kubectl --kubeconfig "$MGMT_KUBECONFIG" get clusterclass
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get nodes -L nvidia.com/gpu.present
```

What I look for in the output: `WORKSPACE_NS` and the NKPCluster name (the object you edit), the `CLUSTERCLASS` value, and whether any node already has the GPU label.

If `WORKSPACE_NS` is not in `~/nkp-site.env`, tell me the workspace namespace and I add it (CHANGES, I show the plan and wait for your "yes").

I stop here. No edit. To get the edit steps, install the `nkp-cluster-lifecycle` skill.

---

## nkp E2

**Files read:** `nkp/SKILL.md`, `nkp/references/components.md`

**No.** On Starter you cannot turn on Velero and you cannot turn on the Grafana monitoring stack.

- Starter: Nutanix AHV only, one provider, **only the Nutanix Rocky Linux image, no monitoring apps, no logging apps**. [pdf p.26-28, p.715]
- Pro adds observability, logging, Harbor, **Velero**, Istio, **GPU operators**, Headlamp. [pdf p.295-297]
- Ultimate adds Thanos, Karma, central Grafana, OpenCost, NKP Insights. [pdf p.295-297]

So both apps need at least Pro. A license **upgrade** is possible. You cannot go to a **lower** tier after registration. [pdf p.26] The apply/change steps are skill `nkp-identity-security` — **that skill is not installed** here, so I give no license change command.

Two more points for your site:

- Air-gapped: after a license upgrade, the Pro app images must also be in your registry mirror. The mirror work is skill `nkp-airgap` — **not installed** here.
- The enable steps for Velero are skill `nkp-storage-backup`, and for Grafana/monitoring are skill `nkp-observability` — **not installed** here. So I cannot give you the CHANGES steps.

First, read the real tier from the cluster, do not trust the paper. You gave me `~/mgmt.conf`. That path must go in the site env file. I show the plan and stop:

```bash
# CHANGES  (adds the kubeconfig path to ~/nkp-site.env)
source ~/nkp-site.env
echo "export MGMT_KUBECONFIG='$HOME/mgmt.conf'" >> ~/nkp-site.env
```

Plan: target is the file `~/nkp-site.env` on the operator host. Result is one new line. No cluster change. Type "yes" and I run it, then I run the READ-ONLY check below.

Then this check (it prints the tier, never a secret):

```bash
# READ-ONLY
source ~/nkp-site.env
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n kommander get licenses.kommander.mesosphere.io -o jsonpath='{.items[*].status.dkpLevel}{"\n"}'
kubectl --kubeconfig "$MGMT_KUBECONFIG" get clusterapps -o custom-columns='NAME:.metadata.name,TIER:.metadata.annotations.apps\.kommander\.d2iq\.io/licensing'
```

What I look for: the first command prints `Starter` (or `Pro`/`Ultimate`). The second shows the tier annotation of `velero` and of the monitoring app.

Then tell me: do you want to upgrade the license, or keep Starter? With Starter the answer stays "no".

---

## nkp E3

**Files read:** `nkp/SKILL.md`, `nkp/references/components.md`

I do not have the version numbers in the skills. `components.md` holds example versions from **one** live cluster, and it says to read the version from the user's cluster before you give a number. So read them from your cluster.

```bash
# READ-ONLY
source ~/nkp-site.env
kubectl --kubeconfig "$MGMT_KUBECONFIG" get clusterapps
kubectl --kubeconfig "$MGMT_KUBECONFIG" get appdeployments -A
kubectl --kubeconfig "$MGMT_KUBECONFIG" get helmreleases -A
kubectl --kubeconfig "$MGMT_KUBECONFIG" get helmchartproxies -A
kubectl --kubeconfig "$MGMT_KUBECONFIG" get pods -A -o jsonpath='{range .items[*]}{range .spec.containers[*]}{.image}{"\n"}{end}{end}' | sort -u
```

If you only want the two apps, use this narrower check:

```bash
# READ-ONLY
source ~/nkp-site.env
kubectl --kubeconfig "$MGMT_KUBECONFIG" get pods -A -o jsonpath='{range .items[*]}{range .spec.containers[*]}{.image}{"\n"}{end}{end}' | sort -u | grep -E 'cert-manager|traefik'
```

Which number you want? One app has three: the catalog version, the chart version, and the image version. The image tag is the upstream version. [live 2.19.0]

- `clusterapps` gives the catalog version.
- `helmreleases` status text gives the chart version.
- The pod image list gives the upstream version.
- `helmchartproxies` covers the CAREN addon charts.

Send me the output lines and I name the upstream cert-manager and Traefik versions for you. I do not guess them.

---

## nkp E4

**Files read:** `nkp/SKILL.md`, `nkp/references/components.md`

**No, that is not the Nutanix CCM's job.**

- On AHV, **MetalLB** gives the service `LoadBalancer` IPs. [live 2.19.0]
- The **Nutanix CCM** gives node metadata only. [live 2.19.0]
- **kube-vip** holds only the control-plane VIP. It is not a service load balancer. [live 2.19.0]

So look at MetalLB. The debug ladder for MetalLB is skill `nkp-networking` — **that skill is not installed** here. I give only READ-ONLY checks, no CHANGES command.

I need two values that are not in the site env table: `SVC_NAME` and `SVC_NS`. Tell me the service name and its namespace.

```bash
# READ-ONLY
source ~/nkp-site.env
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$SVC_NS" describe svc "$SVC_NAME"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get svc -A -o wide
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n metallb-system get pods
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n metallb-system get ipaddresspools -o yaml
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$SVC_NS" get events --sort-by=.lastTimestamp
```

What I look for:

- The `Events` line in `describe svc`: an `AddressPool` or `no available IPs` message means the pool is used up.
- The controller and every speaker pod in `metallb-system`: all must be `Running` and ready.
- One `IPAddressPool`, with a range equal to the create-time `--kubernetes-service-load-balancer-ip-range` (`LB_IP_RANGE`). [live 2.19.0]
- The EXTERNAL-IP list of all services against that range: each `LoadBalancer` service uses one IP. [pdf p.693]

Send me the output and I tell you the next step. If the fix turns out to be a pool change, that is a CHANGES command from `nkp-networking`, which is not installed here.

---

## nkp E5

**Files read:** `nkp/SKILL.md`, `nkp/references/components.md`

Both namespaces are on the management cluster, and both are part of the lifecycle layer (Konvoy). [live 2.19.0]

**`caren-system`** — CAREN (Cluster API Runtime Extensions Nutanix).

- Deployment `cluster-api-runtime-extensions-nutanix`. [live 2.19.0]
- It patches the ClusterClass variables `clusterConfig` and `workerConfig` and it installs the cluster addons. [live 2.19.0]
- It also holds the in-cluster addon chart registry `helm-repository`. The addon charts come from that in-cluster OCI registry. [live 2.19.0]
- CAAPH (in `caaph-system`) then installs those charts through `HelmChartProxy` objects, name pattern `<addon>-<cluster-uid>`. [live 2.19.0]

**`capx-system`** — CAPX, the Nutanix AHV infrastructure provider.

- It calls the Prism Central API and creates the VMs, the `NutanixCluster`, and the `NutanixMachineTemplate` objects. [live 2.19.0]
- API group for its objects: `infrastructure.cluster.x-k8s.io`. [live 2.19.0]

Compare with the CAPI core in `capi-system`, and the operator that installs CAPI + providers + CAREN as one stack in `capi-operator-system` / `capi-stack-operator`. [live 2.19.0]

```bash
# READ-ONLY
source ~/nkp-site.env
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n caren-system get deploy,pods
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n capx-system get deploy,pods
kubectl --kubeconfig "$MGMT_KUBECONFIG" get helmchartproxies -A
kubectl --kubeconfig "$MGMT_KUBECONFIG" get nutanixclusters -A
```

What I look for: the CAREN and CAPX deployments are ready, the `HelmChartProxy` list shows one proxy per addon per cluster, and one `NutanixCluster` per AHV cluster.

The example versions in `components.md` (CAREN v0.62.7, CAPX v1.10.15) are from one live cluster. Read your own from the pods.

---

## nkp E6

**Files read:** `nkp/SKILL.md`, `nkp/references/components.md`

**Not in the skills.** No maximum number of workload clusters per NKP 2.19 management cluster is in the installed skills. I will not make up a number.

What the skills do say, which you need for a 40-cluster plan:

- One NKPCluster object per cluster, in its workspace namespace. CAPI on the management cluster reconciles all of them. [live 2.19.0]
- CLI default node size: 3 control-plane nodes (4 vCPU, 16 GiB, 80 GiB disk) and 4 workers (8 vCPU, 32 GiB, 80 GiB disk) per cluster. [live 2.19.0] With the defaults, 40 clusters = 120 control-plane VMs and 280 worker VMs (arithmetic, not a limit).
- Each cluster needs its own `CP_VIP` and its own `LB_IP_RANGE`, outside the IPAM/DHCP pool, in the node subnet. [pdf p.693-694, p.720] So 40 clusters need 40 VIPs and 40 LB ranges.
- Each node takes one IP from the subnet pool. [pdf p.693]
- The management cluster also holds Kommander, Flux, and the CAPI controllers, so its own nodes must have headroom.

READ-ONLY checks that tell you what you have now:

```bash
# READ-ONLY
source ~/nkp-site.env
kubectl --kubeconfig "$MGMT_KUBECONFIG" get nkpclusters -A
kubectl --kubeconfig "$MGMT_KUBECONFIG" get clusters -A
kubectl --kubeconfig "$MGMT_KUBECONFIG" get machines -A --no-headers | wc -l
kubectl --kubeconfig "$MGMT_KUBECONFIG" get nodes -o wide
kubectl --kubeconfig "$MGMT_KUBECONFIG" describe nodes | grep -A5 'Allocated resources'
```

What I look for: the current cluster count, the machine count, and the CPU/memory requests already allocated on the management cluster nodes.

For a supported maximum, ask Nutanix support and give them the PC/PE capacity. That check is outside these skills.

---

## nkp-install E1

**Files read:** `nkp-install/SKILL.md`, `nkp-install/references/nutanix.md`, `nkp/SKILL.md`

Your case is **4B: air-gapped, no site registry**. NKP pushes the bundle images into an internal registry inside the new cluster. [pdf p.722-723] You do not need a registry now. (Seeding a mirror later is skill `nkp-airgap` — not installed here.)

Before I give the create command, I need these values. They are not in the site env file yet.

| Variable | Value I have | What I need |
|---|---|---|
| `CLUSTER_NAME` | — | the management cluster name (`a-z`, `0-9`, `.`, `-`) |
| `PC_ENDPOINT` | `pc.example.local` | confirm `https://pc.example.local:9440` |
| `PE_CLUSTER` | `PE01` | ok |
| `SUBNET` | `k8s-vlan` | ok |
| `STORAGE_CONTAINER` | `default-container` | ok |
| `VM_IMAGE` | `nkp-rocky-9.8-release-1.36.2` | ok, the name holds the Kubernetes version [pdf p.726] |
| `CP_VIP` | — | one free IP in `k8s-vlan`, outside the IPAM/DHCP pool |
| `LB_IP_RANGE` | — | `<first-ip>-<last-ip>` in `k8s-vlan`, outside the pool |
| `SSH_PUBKEY_FILE` | — | path of your SSH public key file |
| `NTP_SERVERS` | — | comma-separated NTP servers (mandatory on an air-gapped site) [pdf p.724] |
| `BUNDLE_DIR` | `/opt/nkp-v2.19.0` | ok |
| `PC_CA_FILE` | none | only if Prism Central uses a self-signed certificate |

Secrets: you write `NUTANIX_USER` and `NUTANIX_PASSWORD` into the file with an editor. Do not type them in this chat.

Also tell me your tier (Starter or Pro). Starter needs smaller nodes than the defaults (see `nkp-install E2`).

### Step 1 — operator host (READ-ONLY)

```bash
# READ-ONLY
source ~/nkp-site.env
nkp version
docker version --format '{{.Server.Version}}'
kubectl version --client
stat -fc %T /sys/fs/cgroup
nproc; free -g; df -h "${TMPDIR:-/tmp}"
```

What I check: the `nkp` line shows 2.19.0 (else use `cli/nkp` from the bundle), Docker 27.4.0 or Podman 4.0+, `cgroup2fs`, 4 CPU and 4 GB free. [pdf p.48, p.718]

### Step 2 — bundle files (READ-ONLY)

```bash
# READ-ONLY
source ~/nkp-site.env
ls "$BUNDLE_DIR"/container-images/ "$BUNDLE_DIR"/konvoy-bootstrap-image-*.tar
nkp create cluster nutanix --help | grep -A3 -- '--bundle '
```

What I check: exactly one `konvoy-image-bundle-*.tar`, one `kommander-image-bundle-*.tar`, one `nkp-release-specs-*.tar`, and one bootstrap image tar. [live 2.19.0][pdf p.722-723]

### Step 3 — site env file

Plan: target is `~/nkp-site.env` on the operator host. Result is the site values as lines. No cluster change.

```bash
# CHANGES  (adds the site values to ~/nkp-site.env)
cat >> ~/nkp-site.env <<'EOF'
export CLUSTER_NAME=''
export PC_ENDPOINT='https://pc.example.local:9440'
export PE_CLUSTER='PE01'
export SUBNET='k8s-vlan'
export STORAGE_CONTAINER='default-container'
export VM_IMAGE='nkp-rocky-9.8-release-1.36.2'
export CP_VIP=''
export LB_IP_RANGE=''
export SSH_PUBKEY_FILE=''
export NTP_SERVERS=''
export BUNDLE_DIR='/opt/nkp-v2.19.0'
EOF
```

Wait for your "yes" **and** the missing values. Then you add the two secret lines with `vi ~/nkp-site.env`.

### Step 4 — the check (READ-ONLY)

```bash
# READ-ONLY
source ~/nkp-site.env
for v in CLUSTER_NAME PC_ENDPOINT PE_CLUSTER SUBNET STORAGE_CONTAINER VM_IMAGE CP_VIP LB_IP_RANGE SSH_PUBKEY_FILE NUTANIX_USER NUTANIX_PASSWORD; do if test -n "${!v}"; then echo "set: $v"; else echo "MISSING: $v"; fi; done
for v in NTP_SERVERS BUNDLE_DIR; do if test -n "${!v}"; then echo "set: $v"; else echo "MISSING: $v"; fi; done
```

Done when no line starts with `MISSING`.

### Step 5 — infrastructure (READ-ONLY)

```bash
# READ-ONLY
source ~/nkp-site.env
curl -sk -o /dev/null -w '%{http_code}\n' "$PC_ENDPOINT"
ping -c 2 "$CP_VIP"
test -f "$SSH_PUBKEY_FILE" && echo "ssh key file found"
```

What I check: an HTTP code that is not `000`, no ping reply from `CP_VIP` (or you confirm no host uses it), and `ssh key file found`.

### Step 6 — the image bundles variable

Plan: appends one line to `~/nkp-site.env`. No cluster change.

```bash
# CHANGES  (adds IMAGE_BUNDLES to the site env file)
source ~/nkp-site.env
b="$BUNDLE_DIR/container-images"
echo "export IMAGE_BUNDLES='$(ls "$b"/konvoy-image-bundle-*.tar),$(ls "$b"/kommander-image-bundle-*.tar),$(ls "$b"/nkp-release-specs-*.tar)'" >> ~/nkp-site.env
```

### Step 7 — dry run first

Plan: target is the operator host and Prism Central (read only, it only prints objects). Result is `$PWD/<cluster>-dryrun.yaml`. It holds Secrets, so I set mode 600 and I never print it.

```bash
# CHANGES  (writes a local dry-run file)
source ~/nkp-site.env
nkp create cluster nutanix \
  --self-managed \
  --airgapped \
  --bootstrap-cluster-image "$(ls "$BUNDLE_DIR"/konvoy-bootstrap-image-*.tar)" \
  --bundle "$IMAGE_BUNDLES" \
  --cluster-name "$CLUSTER_NAME" \
  --endpoint "$PC_ENDPOINT" \
  --control-plane-endpoint-ip "$CP_VIP" \
  --control-plane-prism-element-cluster "$PE_CLUSTER" \
  --control-plane-subnets "$SUBNET" \
  --control-plane-vm-image "$VM_IMAGE" \
  --worker-prism-element-cluster "$PE_CLUSTER" \
  --worker-subnets "$SUBNET" \
  --worker-vm-image "$VM_IMAGE" \
  --csi-storage-container "$STORAGE_CONTAINER" \
  --kubernetes-service-load-balancer-ip-range "$LB_IP_RANGE" \
  --ssh-public-key-file "$SSH_PUBKEY_FILE" \
  --ntp-servers "$NTP_SERVERS" \
  --dry-run --output yaml > "$PWD/$CLUSTER_NAME-dryrun.yaml"
chmod 600 "$PWD/$CLUSTER_NAME-dryrun.yaml"
```

Then this READ-ONLY check shows the parts I want to see (names, image, addresses):

```bash
# READ-ONLY
source ~/nkp-site.env
grep -n -E '^kind:|^  name:|image:|host:|addressRanges|start:|end:|url:' "$PWD/$CLUSTER_NAME-dryrun.yaml"
```

### Step 8 — the create command

Plan: target is the operator host (kind bootstrap cluster), Prism Central (new VMs in `PE01`), then the pivot. Result is one self-managed management cluster with Kommander. [pdf p.22-23, p.47] This command takes up to 30 minutes. I run it only after your "yes" to this plan.

```bash
# CHANGES  (creates a kind bootstrap cluster and VMs in Prism Central, pushes the images, pivots, installs Kommander)
source ~/nkp-site.env
nkp create cluster nutanix \
  --self-managed \
  --airgapped \
  --bootstrap-cluster-image "$(ls "$BUNDLE_DIR"/konvoy-bootstrap-image-*.tar)" \
  --bundle "$IMAGE_BUNDLES" \
  --cluster-name "$CLUSTER_NAME" \
  --endpoint "$PC_ENDPOINT" \
  --control-plane-endpoint-ip "$CP_VIP" \
  --control-plane-prism-element-cluster "$PE_CLUSTER" \
  --control-plane-subnets "$SUBNET" \
  --control-plane-vm-image "$VM_IMAGE" \
  --worker-prism-element-cluster "$PE_CLUSTER" \
  --worker-subnets "$SUBNET" \
  --worker-vm-image "$VM_IMAGE" \
  --csi-storage-container "$STORAGE_CONTAINER" \
  --kubernetes-service-load-balancer-ip-range "$LB_IP_RANGE" \
  --ssh-public-key-file "$SSH_PUBKEY_FILE" \
  --ntp-servers "$NTP_SERVERS"
```

What I check: the command ends without an error, and `--self-managed` waits until the cluster is ready and the pivot is done. [live 2.19.0]

Send me `CLUSTER_NAME`, `CP_VIP`, `LB_IP_RANGE`, `SSH_PUBKEY_FILE`, `NTP_SERVERS`, and your tier. Then I start with Step 1.

---

## nkp-install E2

**Files read:** `nkp-install/SKILL.md`, `nkp-install/references/nutanix.md`, `nkp/SKILL.md`

**Ubuntu 24.04: no.** Starter supports only the Nutanix Rocky Linux image. Ubuntu needs Pro or Ultimate. [pdf p.715] It is also a known failure row: "Ubuntu image on Starter". Use `nkp-rocky-9.8-release-1.36.2` (Rocky Linux 9.8, no FIPS). [pdf p.55-56]

**1 control plane node: yes, but only for a test.** `--control-plane-replicas 1` works. The cluster is lost when that node fails. [pdf p.696]

**Smallest Starter management cluster.** Add these lines to your create block (not a command block by itself; they go before the last line of the case block, N4A/N4B/N4C):

- `--control-plane-vcpus 2`
- `--control-plane-memory 8`
- `--worker-replicas 2`
- `--worker-vcpus 4`
- `--worker-memory 8`
- and for the test-only single control plane: `--control-plane-replicas 1`

That is the Starter minimum from [pdf p.695]. Keep this in mind: with 2 workers the Pro and Ultimate apps fail after a license upgrade. [pdf p.695] A worker count below 2 is not in the skills, so I cannot size it for you.

Default sizes for comparison: 3 control-plane nodes at 4 vCPU / 16 GiB / 80 GiB, 4 workers at 8 vCPU / 32 GiB / 80 GiB. [live 2.19.0] Each node takes one IP from the subnet pool, and you still need a free `CP_VIP` and a free `LB_IP_RANGE`. [pdf p.693]

Checks that apply here (READ-ONLY):

```bash
# READ-ONLY
source ~/nkp-site.env
echo "VM_IMAGE=$VM_IMAGE"
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n kommander get licenses.kommander.mesosphere.io -o jsonpath='{.items[*].status.dkpLevel}{"\n"}'
```

What I check: `VM_IMAGE` is the Rocky image (no `ubuntu` in the name), and the tier line prints `Starter`. The second check needs `MGMT_KUBECONFIG`; on a first install there is no management cluster yet, so skip it.

To give you the full create command I need three answers plus the missing values:

1. Connected, air-gapped with the internal bundle registry (4B), or air-gapped with a seeded site mirror (4C)?
2. `CLUSTER_NAME`, `PC_ENDPOINT`, `CP_VIP`, `LB_IP_RANGE`, `SSH_PUBKEY_FILE`, and `NTP_SERVERS` (mandatory when air-gapped).

Then I show the dry-run plan first, per the rules.

---

## nkp-install E3

**Files read:** `nkp-install/references/nutanix.md`, `nkp-install/SKILL.md`

That is preflight check `NutanixVMImage`: it found no image with the name in `VM_IMAGE`. The row in the failure table says the image name is wrong, or the image is not in Prism Central. [pdf p.725]

`rocky-nkp` is the cause. **The image name must contain the Kubernetes version.** [pdf p.726] An example from the guide is `nkp-rocky-9.8-release-1.36.2`. `rocky-nkp` has no version in it.

Do these checks. The first is READ-ONLY. For the second, no CLI in these skills lists Prism Central images, so you read the name in the Prism Central UI.

```bash
# READ-ONLY
source ~/nkp-site.env
echo "VM_IMAGE=$VM_IMAGE"
nkp create cluster nutanix --help | grep -i -A2 'vm-image'
```

What I check: the current `VM_IMAGE` value, and the flag name in the help text. A value of `rocky-nkp` confirms the cause.

Then in Prism Central:

1. Images list: copy the **exact** name of the uploaded image. It must hold the version, for example `nkp-rocky-9.8-release-1.36.2`.
2. The image placement policy must allow the image on `PE_CLUSTER`. [pdf p.713]
3. Check that the image is in Prism Central, not only in Prism Element. [pdf p.726]

Then fix the value. Plan: target is `~/nkp-site.env` on the operator host. Result is a new last line; the last line wins. Then you run the same create command again.

```bash
# CHANGES  (adds a corrected VM_IMAGE line to ~/nkp-site.env)
source ~/nkp-site.env
echo "export VM_IMAGE='<exact-name-from-prism-central>'" >> ~/nkp-site.env
```

Send me the exact name and I put it in the block; type "yes" and I run it.

Do **not** add `--skip-preflight-checks=NutanixVMImage`. That flag is only for a check that is itself wrong, and never `all`. [pdf p.726]

---

## nkp-install E4

**Files read:** `nkp-install/references/nutanix.md` (N5), `nkp-install/SKILL.md`, `nkp/references/components.md`

This is a workload cluster (section N5). The management cluster creates it, so there is **no** `--self-managed` and there is `--kubeconfig "$MGMT_KUBECONFIG"`.

Step 1: find the workspace namespace and the mirror that the management cluster already uses (READ-ONLY).

```bash
# READ-ONLY
source ~/nkp-site.env
kubectl --kubeconfig "$MGMT_KUBECONFIG" get workspaces -A
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n kommander get nkpclusters -o jsonpath='{.items[*].spec.kommanderCluster.spec.ociRegistry.mirrorURL}{"\n"}'
```

What I check: the default workspace namespace (it is `kommander-default-workspace` on a live 2.19.0 cluster [live 2.19.0], but read it, do not assume it) and the registry mirror URL of the management cluster. An empty line means the management cluster has no site mirror, and then the create changes.

`MGMT_KUBECONFIG` must be in the env file. `~/mgmt.conf` becomes the value; you told me that path. I also need these new values for the workload cluster: a **new** `CP_VIP`, a **new** `LB_IP_RANGE` (each cluster needs its own), and `REGISTRY_URL` + `REGISTRY_CA_FILE` of the harbor mirror. `CLUSTER_NAME` is `dev-01`, `WORKSPACE_NS` is the default workspace namespace from the check above.

Plan for this file change: target is `~/nkp-site.env`, result is the workload cluster values as new last lines. No cluster change.

```bash
# CHANGES  (adds the workload cluster values to ~/nkp-site.env)
cat >> ~/nkp-site.env <<'EOF'
export MGMT_KUBECONFIG=''
export CLUSTER_NAME='dev-01'
export CP_VIP=''
export LB_IP_RANGE=''
export WORKSPACE_NS=''
export REGISTRY_URL=''
export REGISTRY_CA_FILE=''
EOF
```

Wait for your "yes" and the values. Then write the registry secrets with an editor: `REGISTRY_MIRROR_USERNAME`, `REGISTRY_MIRROR_PASSWORD` (empty `''` if the registry allows anonymous pulls).

Step 2: the check (READ-ONLY).

```bash
# READ-ONLY
source ~/nkp-site.env
for v in CLUSTER_NAME PC_ENDPOINT PE_CLUSTER SUBNET STORAGE_CONTAINER VM_IMAGE CP_VIP LB_IP_RANGE SSH_PUBKEY_FILE NUTANIX_USER NUTANIX_PASSWORD; do if test -n "${!v}"; then echo "set: $v"; else echo "MISSING: $v"; fi; done
for v in MGMT_KUBECONFIG WORKSPACE_NS REGISTRY_URL REGISTRY_CA_FILE; do if test -n "${!v}"; then echo "set: $v"; else echo "MISSING: $v"; fi; done
```

Done when no line starts with `MISSING`.

Step 3: dry run. Plan: writes `$PWD/dev-01-dryrun.yaml`, mode 600, never printed.

```bash
# CHANGES  (writes a local dry-run file)
source ~/nkp-site.env
nkp create cluster nutanix \
  --kubeconfig "$MGMT_KUBECONFIG" \
  --namespace "$WORKSPACE_NS" \
  --airgapped \
  --registry-mirror-url "$REGISTRY_URL" \
  --registry-mirror-cacert "$REGISTRY_CA_FILE" \
  --registry-mirror-username "$REGISTRY_MIRROR_USERNAME" \
  --registry-mirror-password "$REGISTRY_MIRROR_PASSWORD" \
  --cluster-name "$CLUSTER_NAME" \
  --endpoint "$PC_ENDPOINT" \
  --control-plane-endpoint-ip "$CP_VIP" \
  --control-plane-prism-element-cluster "$PE_CLUSTER" \
  --control-plane-subnets "$SUBNET" \
  --control-plane-vm-image "$VM_IMAGE" \
  --worker-prism-element-cluster "$PE_CLUSTER" \
  --worker-subnets "$SUBNET" \
  --worker-vm-image "$VM_IMAGE" \
  --csi-storage-container "$STORAGE_CONTAINER" \
  --kubernetes-service-load-balancer-ip-range "$LB_IP_RANGE" \
  --ssh-public-key-file "$SSH_PUBKEY_FILE" \
  --ntp-servers "$NTP_SERVERS" \
  --dry-run --output yaml > "$PWD/$CLUSTER_NAME-dryrun.yaml"
chmod 600 "$PWD/$CLUSTER_NAME-dryrun.yaml"
```

```bash
# READ-ONLY
source ~/nkp-site.env
grep -n -E '^kind:|^  name:|image:|host:|addressRanges|start:|end:|url:' "$PWD/$CLUSTER_NAME-dryrun.yaml"
```

Step 4: create. Plan: target is the management cluster, which creates the VMs in Prism Central for `dev-01` in `$WORKSPACE_NS`. Result is one workload cluster. I run it after your "yes" to this plan.

```bash
# CHANGES  (creates the VMs of a workload cluster from the management cluster)
source ~/nkp-site.env
nkp create cluster nutanix \
  --kubeconfig "$MGMT_KUBECONFIG" \
  --namespace "$WORKSPACE_NS" \
  --airgapped \
  --registry-mirror-url "$REGISTRY_URL" \
  --registry-mirror-cacert "$REGISTRY_CA_FILE" \
  --registry-mirror-username "$REGISTRY_MIRROR_USERNAME" \
  --registry-mirror-password "$REGISTRY_MIRROR_PASSWORD" \
  --cluster-name "$CLUSTER_NAME" \
  --endpoint "$PC_ENDPOINT" \
  --control-plane-endpoint-ip "$CP_VIP" \
  --control-plane-prism-element-cluster "$PE_CLUSTER" \
  --control-plane-subnets "$SUBNET" \
  --control-plane-vm-image "$VM_IMAGE" \
  --worker-prism-element-cluster "$PE_CLUSTER" \
  --worker-subnets "$SUBNET" \
  --worker-vm-image "$VM_IMAGE" \
  --csi-storage-container "$STORAGE_CONTAINER" \
  --kubernetes-service-load-balancer-ip-range "$LB_IP_RANGE" \
  --ssh-public-key-file "$SSH_PUBKEY_FILE" \
  --ntp-servers "$NTP_SERVERS"
```

Step 5: the workload kubeconfig. Plan: writes `$PWD/dev-01.conf`, mode 600, and appends one line to the env file. `nkp get kubeconfig` can change the local kubeconfig, so it is CHANGES. [live 2.19.0]

```bash
# CHANGES  (writes a local kubeconfig file and adds its path to the site env file)
source ~/nkp-site.env
nkp get kubeconfig --cluster-name "$CLUSTER_NAME" --namespace "$WORKSPACE_NS" --kubeconfig "$MGMT_KUBECONFIG" > "$PWD/$CLUSTER_NAME.conf"
chmod 600 "$PWD/$CLUSTER_NAME.conf"
echo "export CLUSTER_KUBECONFIG='$PWD/$CLUSTER_NAME.conf'" >> ~/nkp-site.env
```

Then the verify block (READ-ONLY):

```bash
# READ-ONLY
source ~/nkp-site.env
ns=kommander; test "$CLUSTER_KUBECONFIG" != "$MGMT_KUBECONFIG" && ns="$WORKSPACE_NS"
nkp describe cluster --cluster-name "$CLUSTER_NAME" --namespace "$ns" --kubeconfig "$MGMT_KUBECONFIG"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get nodes
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get pods -A --field-selector=status.phase!=Running,status.phase!=Succeeded
```

What I check: `True` for the cluster, the control plane and every machine; all nodes `Ready`; the pod list shows "No resources found".

If the harbor mirror allows anonymous pulls, remove the two `--registry-mirror-user*`/`-password` lines.

Send me `CP_VIP`, `LB_IP_RANGE`, `REGISTRY_URL`, `REGISTRY_CA_FILE`, and the default workspace namespace. Then I start.

---

## nkp-install E5

**Files read:** `nkp-install/SKILL.md` (step "Check or install Kommander"), `nkp-install/references/kommander.md`

**No.** On Nutanix AHV, `nkp create cluster nutanix --self-managed` installs Kommander. [pdf p.47] So `nkp install kommander` is not needed when the create succeeded.

Always check first, and do not skip the check:

```bash
# READ-ONLY
source ~/nkp-site.env
kubectl --kubeconfig "$MGMT_KUBECONFIG" get ns kommander-flux
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n kommander get helmreleases
kubectl --kubeconfig "$MGMT_KUBECONFIG" get storageclass
```

What I check:

- `kommander-flux` namespace exists, and the HelmReleases are there → Kommander is installed. Go to the verify step.
- No `kommander-flux` namespace or no HelmReleases → Kommander is missing. Then the install steps are in `references/kommander.md`: `nkp install kommander --init --airgapped > kommander.yaml`, then `nkp install kommander --installer-config kommander.yaml --kubeconfig "$MGMT_KUBECONFIG" --wait-timeout 2h`. Both are CHANGES and both wait for your "yes".
- One StorageClass must be `(default)`. [pdf p.942] If none is default, stop; that is skill `nkp-storage-backup` (not installed here).

Then the full verify (READ-ONLY):

```bash
# READ-ONLY
source ~/nkp-site.env
nkp describe cluster --cluster-name "$CLUSTER_NAME" --namespace kommander --kubeconfig "$MGMT_KUBECONFIG"
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n kommander get nkpclusters
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n kommander wait --for condition=Ready helmreleases --all --timeout 15m
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get nodes
```

Done when: `nkp describe cluster` shows `True` for the cluster, the control plane and every machine, the NKPCluster PHASE is `Reconciled` [live 2.19.0], all nodes are `Ready`, and the HelmRelease wait prints "condition met".

---

## nkp-install E6

**Files read:** `nkp-install/references/nutanix.md` (N4A), `nkp-install/SKILL.md`

Your case is **4A: connected, no registry mirror**. The cluster pulls the NKP images from `docker.io/nutanix` with the Nutanix Docker Hub token. [pdf p.675-677]

Secrets: you write `NUTANIX_REGISTRY_USERNAME` and `NUTANIX_REGISTRY_TOKEN` into `~/nkp-site.env` with an editor, for example `vi ~/nkp-site.env`. Do not type the token in this chat. Also `NUTANIX_USER` and `NUTANIX_PASSWORD` go in the same file.

Values that I need from you: `CLUSTER_NAME`, `PC_ENDPOINT`, `PE_CLUSTER`, `SUBNET`, `STORAGE_CONTAINER`, `VM_IMAGE`, `CP_VIP`, `LB_IP_RANGE`, `SSH_PUBKEY_FILE`. Add `NTP_SERVERS` if you use NTP.

Step 1: operator host (READ-ONLY).

```bash
# READ-ONLY
source ~/nkp-site.env
nkp version
docker version --format '{{.Server.Version}}'
kubectl version --client
stat -fc %T /sys/fs/cgroup
nproc; free -g; df -h "${TMPDIR:-/tmp}"
```

What I check: `nkp` shows 2.19.0, the engine is Docker 27.4.0 or Podman 4.0+, `cgroup2fs`, 4 CPU and 4 GB free. [pdf p.48, p.718]

Step 2: env file. Plan: target is `~/nkp-site.env`. Result is the site values as lines. No cluster change.

```bash
# CHANGES  (adds the site values to ~/nkp-site.env)
cat >> ~/nkp-site.env <<'EOF'
export CLUSTER_NAME=''
export PC_ENDPOINT=''
export PE_CLUSTER=''
export SUBNET=''
export STORAGE_CONTAINER=''
export VM_IMAGE=''
export CP_VIP=''
export LB_IP_RANGE=''
export SSH_PUBKEY_FILE=''
export NTP_SERVERS=''
EOF
```

Wait for your "yes" and the values. Then add the four secret lines with an editor.

Step 3: check (READ-ONLY).

```bash
# READ-ONLY
source ~/nkp-site.env
for v in CLUSTER_NAME PC_ENDPOINT PE_CLUSTER SUBNET STORAGE_CONTAINER VM_IMAGE CP_VIP LB_IP_RANGE SSH_PUBKEY_FILE NUTANIX_USER NUTANIX_PASSWORD; do if test -n "${!v}"; then echo "set: $v"; else echo "MISSING: $v"; fi; done
for v in NUTANIX_REGISTRY_USERNAME NUTANIX_REGISTRY_TOKEN; do if test -n "${!v}"; then echo "set: $v"; else echo "MISSING: $v"; fi; done
```

Done when no line starts with `MISSING`.

Step 4: dry run first. Plan: writes `$PWD/<cluster>-dryrun.yaml`, mode 600, never printed.

```bash
# CHANGES  (writes a local dry-run file)
source ~/nkp-site.env
nkp create cluster nutanix \
  --self-managed \
  --cluster-name "$CLUSTER_NAME" \
  --endpoint "$PC_ENDPOINT" \
  --control-plane-endpoint-ip "$CP_VIP" \
  --control-plane-prism-element-cluster "$PE_CLUSTER" \
  --control-plane-subnets "$SUBNET" \
  --control-plane-vm-image "$VM_IMAGE" \
  --worker-prism-element-cluster "$PE_CLUSTER" \
  --worker-subnets "$SUBNET" \
  --worker-vm-image "$VM_IMAGE" \
  --csi-storage-container "$STORAGE_CONTAINER" \
  --kubernetes-service-load-balancer-ip-range "$LB_IP_RANGE" \
  --ssh-public-key-file "$SSH_PUBKEY_FILE" \
  --nutanix-registry-username "$NUTANIX_REGISTRY_USERNAME" \
  --nutanix-registry-password "$NUTANIX_REGISTRY_TOKEN" \
  --dry-run --output yaml > "$PWD/$CLUSTER_NAME-dryrun.yaml"
chmod 600 "$PWD/$CLUSTER_NAME-dryrun.yaml"
```

```bash
# READ-ONLY
source ~/nkp-site.env
grep -n -E '^kind:|^  name:|image:|host:|addressRanges|start:|end:|url:' "$PWD/$CLUSTER_NAME-dryrun.yaml"
```

Step 5: create. Plan: target is the operator host (kind bootstrap cluster), Prism Central (new VMs), then the pivot. Result is one self-managed management cluster with Kommander. I run it only after your "yes".

```bash
# CHANGES  (creates a kind bootstrap cluster and VMs in Prism Central, pivots, installs Kommander)
source ~/nkp-site.env
nkp create cluster nutanix \
  --self-managed \
  --cluster-name "$CLUSTER_NAME" \
  --endpoint "$PC_ENDPOINT" \
  --control-plane-endpoint-ip "$CP_VIP" \
  --control-plane-prism-element-cluster "$PE_CLUSTER" \
  --control-plane-subnets "$SUBNET" \
  --control-plane-vm-image "$VM_IMAGE" \
  --worker-prism-element-cluster "$PE_CLUSTER" \
  --worker-subnets "$SUBNET" \
  --worker-vm-image "$VM_IMAGE" \
  --csi-storage-container "$STORAGE_CONTAINER" \
  --kubernetes-service-load-balancer-ip-range "$LB_IP_RANGE" \
  --ssh-public-key-file "$SSH_PUBKEY_FILE" \
  --nutanix-registry-username "$NUTANIX_REGISTRY_USERNAME" \
  --nutanix-registry-password "$NUTANIX_REGISTRY_TOKEN"
```

Warning: the token is on the command line, so other users on the operator host can see it in the process list. The CLI has no other input for it. [live 2.19.0]

What I check: the command ends without an error. Then the next step is "Set the kubeconfig variables" (the `./$CLUSTER_NAME.conf` file in the folder where the create ran).

Send me the nine values, then I start with Step 1.

---

## nkp-install E7

**Files read:** `nkp-install/references/nutanix.md` (N4C), `nkp-install/SKILL.md`

Your case is **4C: air-gapped, site registry mirror already seeded**. Two values are clear from your message: `REGISTRY_URL=https://registry.example.local/nkp` and `REGISTRY_CA_FILE=/etc/pki/harbor-ca.crt`.

I still need: `CLUSTER_NAME`, `PC_ENDPOINT`, `PE_CLUSTER`, `SUBNET`, `STORAGE_CONTAINER`, `VM_IMAGE`, `CP_VIP`, `LB_IP_RANGE`, `SSH_PUBKEY_FILE`, `NTP_SERVERS` (mandatory air-gapped [pdf p.724]), and `BUNDLE_DIR` (the bootstrap image comes from the bundle file even with a site mirror [live 2.19.0]).

Two site checks first: the operator host **and** every node subnet must reach the registry. [pdf p.713]

Secrets with an editor: `NUTANIX_USER`, `NUTANIX_PASSWORD`, `REGISTRY_MIRROR_USERNAME`, `REGISTRY_MIRROR_PASSWORD` (empty `''` if anonymous pulls are allowed).

Step 1: env file. Plan: target is `~/nkp-site.env`. Result is the site values as lines. No cluster change.

```bash
# CHANGES  (adds the site values to ~/nkp-site.env)
cat >> ~/nkp-site.env <<'EOF'
export CLUSTER_NAME=''
export PC_ENDPOINT=''
export PE_CLUSTER=''
export SUBNET=''
export STORAGE_CONTAINER=''
export VM_IMAGE=''
export CP_VIP=''
export LB_IP_RANGE=''
export SSH_PUBKEY_FILE=''
export NTP_SERVERS=''
export BUNDLE_DIR=''
export REGISTRY_URL='https://registry.example.local/nkp'
export REGISTRY_CA_FILE='/etc/pki/harbor-ca.crt'
EOF
```

Wait for your "yes" and the values.

Step 2: check (READ-ONLY).

```bash
# READ-ONLY
source ~/nkp-site.env
for v in CLUSTER_NAME PC_ENDPOINT PE_CLUSTER SUBNET STORAGE_CONTAINER VM_IMAGE CP_VIP LB_IP_RANGE SSH_PUBKEY_FILE NUTANIX_USER NUTANIX_PASSWORD; do if test -n "${!v}"; then echo "set: $v"; else echo "MISSING: $v"; fi; done
for v in NTP_SERVERS BUNDLE_DIR REGISTRY_URL REGISTRY_CA_FILE; do if test -n "${!v}"; then echo "set: $v"; else echo "MISSING: $v"; fi; done
```

Done when no line starts with `MISSING`.

Step 3: dry run first. Plan: writes `$PWD/<cluster>-dryrun.yaml`, mode 600, never printed.

```bash
# CHANGES  (writes a local dry-run file)
source ~/nkp-site.env
nkp create cluster nutanix \
  --self-managed \
  --airgapped \
  --bootstrap-cluster-image "$(ls "$BUNDLE_DIR"/konvoy-bootstrap-image-*.tar)" \
  --registry-mirror-url "$REGISTRY_URL" \
  --registry-mirror-cacert "$REGISTRY_CA_FILE" \
  --registry-mirror-username "$REGISTRY_MIRROR_USERNAME" \
  --registry-mirror-password "$REGISTRY_MIRROR_PASSWORD" \
  --cluster-name "$CLUSTER_NAME" \
  --endpoint "$PC_ENDPOINT" \
  --control-plane-endpoint-ip "$CP_VIP" \
  --control-plane-prism-element-cluster "$PE_CLUSTER" \
  --control-plane-subnets "$SUBNET" \
  --control-plane-vm-image "$VM_IMAGE" \
  --worker-prism-element-cluster "$PE_CLUSTER" \
  --worker-subnets "$SUBNET" \
  --worker-vm-image "$VM_IMAGE" \
  --csi-storage-container "$STORAGE_CONTAINER" \
  --kubernetes-service-load-balancer-ip-range "$LB_IP_RANGE" \
  --ssh-public-key-file "$SSH_PUBKEY_FILE" \
  --ntp-servers "$NTP_SERVERS" \
  --dry-run --output yaml > "$PWD/$CLUSTER_NAME-dryrun.yaml"
chmod 600 "$PWD/$CLUSTER_NAME-dryrun.yaml"
```

```bash
# READ-ONLY
source ~/nkp-site.env
grep -n -E '^kind:|^  name:|image:|host:|addressRanges|start:|end:|url:' "$PWD/$CLUSTER_NAME-dryrun.yaml"
```

What I check in the grep output: every `image:` line starts with your registry host, and the `url:` line is the mirror URL. A `docker.io` image line means the mirror flags did not apply.

Step 4: create. Plan: target is the operator host (kind bootstrap cluster), Prism Central (new VMs), the pivot, then Kommander. Result is one self-managed management cluster that pulls all images from `registry.example.local/nkp`. I run it only after your "yes".

```bash
# CHANGES  (creates a kind bootstrap cluster and VMs in Prism Central, pivots, installs Kommander)
source ~/nkp-site.env
nkp create cluster nutanix \
  --self-managed \
  --airgapped \
  --bootstrap-cluster-image "$(ls "$BUNDLE_DIR"/konvoy-bootstrap-image-*.tar)" \
  --registry-mirror-url "$REGISTRY_URL" \
  --registry-mirror-cacert "$REGISTRY_CA_FILE" \
  --registry-mirror-username "$REGISTRY_MIRROR_USERNAME" \
  --registry-mirror-password "$REGISTRY_MIRROR_PASSWORD" \
  --cluster-name "$CLUSTER_NAME" \
  --endpoint "$PC_ENDPOINT" \
  --control-plane-endpoint-ip "$CP_VIP" \
  --control-plane-prism-element-cluster "$PE_CLUSTER" \
  --control-plane-subnets "$SUBNET" \
  --control-plane-vm-image "$VM_IMAGE" \
  --worker-prism-element-cluster "$PE_CLUSTER" \
  --worker-subnets "$SUBNET" \
  --worker-vm-image "$VM_IMAGE" \
  --csi-storage-container "$STORAGE_CONTAINER" \
  --kubernetes-service-load-balancer-ip-range "$LB_IP_RANGE" \
  --ssh-public-key-file "$SSH_PUBKEY_FILE" \
  --ntp-servers "$NTP_SERVERS"
```

If the registry allows anonymous pulls, remove the two `--registry-mirror-user*`/`-password` lines from both blocks.

What I check: the command ends without an error. If a pod later shows `ImagePullBackOff`, the usual cause is that the operator host reaches the registry but the node subnet does not. [pdf p.713]

Send me the ten values, then I start.

---

## nkp-install E8

**Files read:** `nkp-install/SKILL.md`, `nkp-install/references/nutanix.md` (N4, N4C)

I cannot skip the plan and I cannot skip the dry run. Two rules apply:

- Rule 2: before a CHANGES block I show the plan and stop. A request such as "just run it" is not a "yes".
- The provider file says: **Dry run first.** The create block is the same with `--dry-run --output yaml`.

Your `~/nkp-site.env` may well be complete. I still run the check, because it costs a second and prints only variable names.

```bash
# READ-ONLY
source ~/nkp-site.env
for v in CLUSTER_NAME PC_ENDPOINT PE_CLUSTER SUBNET STORAGE_CONTAINER VM_IMAGE CP_VIP LB_IP_RANGE SSH_PUBKEY_FILE NUTANIX_USER NUTANIX_PASSWORD; do if test -n "${!v}"; then echo "set: $v"; else echo "MISSING: $v"; fi; done
for v in NTP_SERVERS BUNDLE_DIR REGISTRY_URL REGISTRY_CA_FILE; do if test -n "${!v}"; then echo "set: $v"; else echo "MISSING: $v"; fi; done
nkp version
```

If any line starts with `MISSING`, I stop and you fix the file.

**Plan — dry run (case 4C).** Command: the block below. Target: the operator host and Prism Central. Result: `$PWD/$CLUSTER_NAME-dryrun.yaml` with mode 600. It holds Secrets, so I never print it; I print only selected lines. No VM is created.

```bash
# CHANGES  (writes a local dry-run file)
source ~/nkp-site.env
nkp create cluster nutanix \
  --self-managed \
  --airgapped \
  --bootstrap-cluster-image "$(ls "$BUNDLE_DIR"/konvoy-bootstrap-image-*.tar)" \
  --registry-mirror-url "$REGISTRY_URL" \
  --registry-mirror-cacert "$REGISTRY_CA_FILE" \
  --registry-mirror-username "$REGISTRY_MIRROR_USERNAME" \
  --registry-mirror-password "$REGISTRY_MIRROR_PASSWORD" \
  --cluster-name "$CLUSTER_NAME" \
  --endpoint "$PC_ENDPOINT" \
  --control-plane-endpoint-ip "$CP_VIP" \
  --control-plane-prism-element-cluster "$PE_CLUSTER" \
  --control-plane-subnets "$SUBNET" \
  --control-plane-vm-image "$VM_IMAGE" \
  --worker-prism-element-cluster "$PE_CLUSTER" \
  --worker-subnets "$SUBNET" \
  --worker-vm-image "$VM_IMAGE" \
  --csi-storage-container "$STORAGE_CONTAINER" \
  --kubernetes-service-load-balancer-ip-range "$LB_IP_RANGE" \
  --ssh-public-key-file "$SSH_PUBKEY_FILE" \
  --ntp-servers "$NTP_SERVERS" \
  --dry-run --output yaml > "$PWD/$CLUSTER_NAME-dryrun.yaml"
chmod 600 "$PWD/$CLUSTER_NAME-dryrun.yaml"
```

I stop here and wait for your "yes" to this plan. After the dry run, I show you the grep output, and then I show the create plan. The create stays stopped until you type "yes" a second time.

---

## nkp-install E9

**Files read:** `nkp-install/SKILL.md` (rule 5, step "Give the user the UI access"), `nkp/references/components.md`

**No. I will not print the admin password and I will not decode the dashboard Secret.**

Rule 5: I never print the data of a Kubernetes Secret. The user runs a command that prints a secret in their own terminal. `nkp get dashboard` is that command. Its output also holds the UI URL. [live 2.19.0]

Run this yourself, in your own terminal:

```bash
# READ-ONLY  (the user runs this in their own terminal)
source ~/nkp-site.env
nkp get dashboard --kubeconfig "$MGMT_KUBECONFIG"
```

Two notes:

- The static admin credentials are for one thing only: to set up an identity provider (Dex). [pdf p.729] The identity work is skill `nkp-identity-security` — not installed here.
- If you want a new password, for example because the old one was shared, I can rotate it. That is CHANGES and it stops current sessions. Plan below; I run it only after your "yes", and then **you** run `nkp get dashboard` to see the new password.

```bash
# CHANGES  (changes the dashboard admin password; old sessions stop)
source ~/nkp-site.env
KUBECONFIG="$MGMT_KUBECONFIG" nkp rotate dashboard-credentials --yes
```

---

## nkp-install E10

**Files read:** `nkp-install/SKILL.md` (rules 3, 4, 5), `nkp-install/references/nutanix.md` (N1, N2)

I did not store that password and I will not use it. Rule 5: when you type a secret in the chat, I do not repeat it and I do not use it. You write it into the file with an editor.

**Do this first:** that password is now in a chat log. Ask the PC admin to change the Prism Central password, then put the new one in the file. A Preflight check reads `NUTANIX_USER` and `NUTANIX_PASSWORD`, and it fails when the user has no role with the NKP permissions. [pdf p.705-707]

Editor step (you run it, not me):

```bash
# CHANGES  (the user edits the secret lines in their own terminal)
chmod 600 ~/nkp-site.env
vi ~/nkp-site.env
```

Add these two lines, with your own values between the quotes:

```
export NUTANIX_USER=''
export NUTANIX_PASSWORD=''
```

If a value holds a single quote, write it as `'\''`.

I can set up the **non-secret** part of the file. Tell me the values and I add them. Plan: target is `~/nkp-site.env` on the operator host. Result is the site values as new lines. No cluster change.

```bash
# CHANGES  (adds the site values to ~/nkp-site.env)
cat >> ~/nkp-site.env <<'EOF'
export CLUSTER_NAME=''
export PC_ENDPOINT=''
export PE_CLUSTER=''
export SUBNET=''
export STORAGE_CONTAINER=''
export VM_IMAGE=''
export CP_VIP=''
export LB_IP_RANGE=''
export SSH_PUBKEY_FILE=''
export NTP_SERVERS=''
export BUNDLE_DIR=''
export REGISTRY_URL=''
export REGISTRY_CA_FILE=''
EOF
```

Wait for your "yes" and the values. The secrets stay out of my commands. Then this check proves they are there, without printing them (READ-ONLY):

```bash
# READ-ONLY
source ~/nkp-site.env
for v in NUTANIX_USER NUTANIX_PASSWORD; do if test -n "${!v}"; then echo "set: $v"; else echo "MISSING: $v"; fi; done
for v in CLUSTER_NAME PC_ENDPOINT PE_CLUSTER SUBNET STORAGE_CONTAINER VM_IMAGE CP_VIP LB_IP_RANGE SSH_PUBKEY_FILE; do if test -n "${!v}"; then echo "set: $v"; else echo "MISSING: $v"; fi; done
```

Done when no line starts with `MISSING`.
