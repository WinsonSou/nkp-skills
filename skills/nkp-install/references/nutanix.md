# Install NKP on Nutanix AHV (Prism Central)

Use this file from skill `nkp-install`. It covers a management cluster and a workload cluster, connected and air-gapped. The flags match `nkp create cluster nutanix --help` of NKP 2.19.0 and 2.19.1. [live 2.19.0] Sections have N-labels so that they do not mix with the steps in `SKILL.md`.

## N1. Collect the values

Ask the user for each value. Append each known value to the file in the "File" column (rule 4). "Req" says which case needs it: 4A connected, 4B air-gapped with the internal mirror, 4C site registry mirror, 5 workload cluster. "all" means every case.

| Variable | File | Req | Rule |
|---|---|---|---|
| `CLUSTER_NAME` | cluster | all | only `a-z`, `0-9`, `.`, `-` [pdf p.718] |
| `CP_VIP` | cluster | all | a static IP in the node subnet CIDR, **outside** the IPAM or DHCP pool. No other host uses it. [pdf p.720] Reserve it, and every address of `LB_IP_RANGE`, in Prism IPAM on an IPAM subnet: the create makes no reservation, so a later cluster can take `CP_VIP` from the pool and the API endpoint of this cluster then stops. [live 2.19.1] |
| `LB_IP_RANGE` | cluster | all | `<first-ip>-<last-ip>` on the same Layer 2 subnet as the workers, outside the pool. MetalLB gives the first **free** IP to the first `LoadBalancer` Service. The NKP UI gets the first IP only when no other Service took it first. [pdf p.694, p.721][live 2.19.0] So create other `LoadBalancer` Services only after the platform apps are ready (skill `nkp-storage-backup`, `csi.md` C12 "When"). An annotation on `kommander-traefik` is not in the skills. |
| `WORKSPACE_NS` | cluster | all | `kommander` for a management cluster. For case 5, the WORKSPACE NAMESPACE of the workspace (N5 step 1). [live 2.19.0] |
| `PC_ENDPOINT` | site | all | for example `https://<host>:9440` [live 2.19.0] |
| `PE_CLUSTER` | site | all | the Prism Element cluster for the VMs |
| `SUBNET` | site | all | IPAM or DHCP is on. The subnet is in `PE_CLUSTER`. [pdf p.693, p.721] |
| `STORAGE_CONTAINER` | site | all | the container is in `PE_CLUSTER`. [pdf p.720] |
| `VM_IMAGE` | site | all | the image is in Prism Central. Its name contains the Kubernetes version, for example `1.36.2`. [pdf p.726] |
| `SSH_PUBKEY_FILE` | site | all | NKP adds this key for user `konvoy` on every node. [live 2.19.0] |
| `NTP_SERVERS` | site | 4B, 4C, 5 air-gapped | comma-separated. **Mandatory on an air-gapped site.** [pdf p.724] PE, PC, and the operator host can use different servers. Use the NTP list of `PE_CLUSTER`: skill `nutanix-cluster`, RECIPES.md "Full inventory" (field `network.ntpServerIpList`). If skill `nutanix-cluster` is not installed, the user reads it in Prism Central. [live 2.19.0] |
| `BUNDLE_DIR` | site | 4B, 4C | the extracted bundle folder |
| `REGISTRY_URL` | site | 4C, 5 mirror | for example `https://<registry-host>/<project>` [live 2.19.0] |
| `REGISTRY_CA_FILE` | site | 4C, 5 mirror | the CA file of the registry |
| `MGMT_KUBECONFIG` | site | 5 | set by the `SKILL.md` step "Set the kubeconfig variables" |
| `PC_CA_FILE` | site | optional | only when the PC certificate has a SAN with the host or IP of `PC_ENDPOINT` (N4 "PC certificate") |
| `PC_PROJECT` | site | optional | one project for the control plane and all node pools. You cannot change it later. [pdf p.1016] |

Secret lines that the user adds with an editor (`SKILL.md` step "Prepare the env files"):

| Case | Secret variables |
|---|---|
| all | `NUTANIX_USER`, `NUTANIX_PASSWORD` (the CLI reads them from the environment [pdf p.719]) |
| 4A | `NUTANIX_REGISTRY_USERNAME`, `NUTANIX_REGISTRY_TOKEN` (from the Nutanix portal) [pdf p.675-677] |
| 4C, 5 mirror | `REGISTRY_MIRROR_USERNAME`, `REGISTRY_MIRROR_PASSWORD` (write `''` when the registry allows anonymous pulls) |

### IP plan

- Each node takes one IP from the subnet pool. The default is 3 control-plane nodes and 4 workers, so 7 IPs. [pdf p.693] The node IPs are not in sequence. [live 2.19.0]
- `CP_VIP` and `LB_IP_RANGE` are outside the pool, in the same CIDR. [pdf p.693-694] Each cluster needs its own VIP and its own range.
- Find free IPs: skill `nutanix-networking`, RECIPES.md "Free IP check for a VIP or an LB range". It reads the pool, the VM NICs, and the PE/PC/CVM/host IPs, and sends an ARP probe. Run it on the operator host: the ARP probe must come from the same Layer 2 subnet. A basic VLAN subnet does not show the IPs of a VIP or a MetalLB range in Prism Central. [live 2.19.0] If skill `nutanix-networking` is not installed, the user confirms the IPs with the network team.
- The pod CIDR (default `192.168.0.0/16`) and the service CIDR (default `10.96.0.0/12`) must not overlap each other, the node subnet, or `CP_VIP`. You cannot change them later. [live 2.19.0][pdf p.724]
- Extra `LoadBalancer` services (for example NDK) need more IPs in `LB_IP_RANGE`. [pdf p.693]

### Node size

- CLI defaults: 3 control-plane nodes with 4 vCPU, 16 GiB, and an 80 GiB disk; 4 workers with 8 vCPU, 32 GiB, and an 80 GiB disk. [live 2.19.0] These are the Pro and Ultimate minimums. [pdf p.696]
- The default 7 nodes need **44 vCPU, 176 GiB RAM, and 7 × 80 GiB of disk** in `PE_CLUSTER`. Read the capacity of the PE first (N3 of [preflight.md](preflight.md)): the create does not check it. [live 2.19.1]
- Starter minimum for a management cluster: add `--control-plane-vcpus 2 --control-plane-memory 8 --worker-replicas 2 --worker-vcpus 4 --worker-memory 8`. [pdf p.695]
- Starter minimum for a workload cluster: add `--control-plane-vcpus 2 --control-plane-memory 6 --worker-replicas 2 --worker-vcpus 3 --worker-memory 6`. [pdf p.695-696]
- With 2 workers, the Pro and Ultimate apps fail after a license upgrade. Tell the user this. [pdf p.695]
- One control-plane node (`--control-plane-replicas 1`) works, but the cluster is lost when that node fails. Use it only for a test. [pdf p.696]

### Node OS image

- The guide says that Starter supports only the Rocky Linux image [pdf p.715]. A Starter create with the Ubuntu 24.04 image works [live 2.19.0]. This is a support statement, not a block: tell the user, and continue with the image that the user selects.
- Nutanix pre-built images: Rocky Linux 9.8 and Ubuntu 24.04, CIS Level 1, no FIPS. [pdf p.55-56] Keep the image name from the Nutanix portal. [pdf p.715]
- The image placement policy must allow the image on `PE_CLUSTER`. [pdf p.713]
- `--fips` needs a FIPS-built image, and you set it only at create time. For custom and FIPS images, use skill `nkp-airgap`.

## N2. Check the env files

The checks print only variable names, never values. Replace `<cluster>` with the cluster name.

```bash
# READ-ONLY  (every case)
source ~/nkp-<cluster>.env 2>/dev/null
bash -n ~/nkp-site.env 2>/dev/null && bash -n ~/nkp-<cluster>.env 2>/dev/null && echo "set: syntax" || echo "MISSING: syntax"
for v in CLUSTER_NAME CP_VIP LB_IP_RANGE WORKSPACE_NS PC_ENDPOINT PE_CLUSTER SUBNET STORAGE_CONTAINER VM_IMAGE SSH_PUBKEY_FILE NUTANIX_USER NUTANIX_PASSWORD; do if [ -n "$(printenv "$v")" ]; then echo "set: $v"; else echo "MISSING: $v"; fi; done
```

Then run the block for the case. Replace the names after `for v in` with the names in the table below.

```bash
# READ-ONLY  (one case)
source ~/nkp-<cluster>.env 2>/dev/null
for v in NTP_SERVERS BUNDLE_DIR; do if [ -n "$(printenv "$v")" ]; then echo "set: $v"; else echo "MISSING: $v"; fi; done
```

| Case | Names for the block above | Also run this block |
|---|---|---|
| 4A | `NUTANIX_REGISTRY_USERNAME NUTANIX_REGISTRY_TOKEN` | — |
| 4B | `NTP_SERVERS BUNDLE_DIR` | — |
| 4C | `NTP_SERVERS BUNDLE_DIR REGISTRY_URL REGISTRY_CA_FILE` | mirror credentials |
| 5 mirror, air-gapped | `MGMT_KUBECONFIG REGISTRY_URL REGISTRY_CA_FILE NTP_SERVERS` | mirror credentials |
| 5 mirror, connected | `MGMT_KUBECONFIG REGISTRY_URL REGISTRY_CA_FILE` | mirror credentials |
| 5 connected, no mirror | `MGMT_KUBECONFIG` | — |

The mirror credentials can be empty (anonymous pulls), so this block checks only that the lines exist:

```bash
# READ-ONLY  (mirror credentials)
source ~/nkp-site.env 2>/dev/null
for v in REGISTRY_MIRROR_USERNAME REGISTRY_MIRROR_PASSWORD; do printenv "$v" >/dev/null && echo "set: $v" || echo "MISSING: $v"; done
```

Done when: each block prints `set: syntax` (first block) and `set: <name>` for each name in its list. For a `MISSING` secret, give the user the editor block from `SKILL.md`. For `MISSING: syntax`, ask the user to check the quotes in the env files.

## N3. Check the infrastructure

Use [preflight.md](preflight.md), section N3. It tests Prism Central, the PC certificate, `CP_VIP`, the LB range, the SSH key, the capacity of the PE cluster, and the site mirror (host and project).

## N4. Create the management cluster

Choose one case:

| Case | Section |
|---|---|
| Connected, no registry mirror | N4A |
| Air-gapped, no site registry: NKP puts the bundle images in an internal registry in the new cluster | N4B |
| Site registry mirror (Harbor, Nexus, Artifactory) that is already seeded | N4C |

Use only one registry method: `--bundle` (internal mirror) or `--registry-mirror-*` (site mirror). [pdf p.725]

`--registry-url`, `--registry-username`, `--registry-password`, and `--registry-cacert` are a **third, separate** setting, not a mirror: they render CAREN `imageRegistries[]` (that registry's CA and credentials, applied on every node through the kubelet dynamic credential provider, so a Pod pulling `<registry>/<project>/<image>` needs no namespace `imagePullSecret`). They are allowed together with `--registry-mirror-*` (mirror becomes `globalImageRegistryMirror`, registry becomes `imageRegistries[]`) and never replace it: alone on a connected management create the CLI stops with `--nutanix-registry-username and --nutanix-registry-password are required … unless it is air-gapped or --registry-mirror-url is set`. They are needed only for **private** registry projects: without them such a pull gets `401`, while public projects still work, because the mirror CA also lands in `certs.d/<registry-host>/ca.crt` and an explicit `<registry>/<project>/<image>` reference is not rewritten to the mirror path. The credentials reach a Secret (`<cluster>-image-registry-credentials`), the `KubeadmConfig` of every machine, and a file on every node (`/etc/kubernetes/static-image-credentials.json`): use a read-only robot account, not an administrator. A create writes the same CA bytes into that Secret and into `<cluster>-image-registry-mirror-credentials`, so the flags are safe together. When you add `imageRegistries` to a **running** cluster by hand, put only `username` and `password` in the Secret: if the CA in the two Secrets differs at all, the CAPI reconcile stops with `conflicting CA certificate specified for registry host: "<host>" (from secrets A and B)`, and the mirror entry already supplies the CA for that host. [live 2.19.1]

| File | Site variables |
|---|---|
| `~/nkp-site.env` | `REGISTRY_HOST` `REGISTRY_USERNAME` `REGISTRY_PASSWORD` |

### N4A. Connected, no registry mirror

The cluster pulls NKP images from `docker.io/nutanix` with the Nutanix Docker Hub token. [pdf p.675-677]

```bash
# CHANGES  (writes the create script of this cluster; creates nothing yet)
source ~/nkp-<cluster>.env 2>/dev/null
(umask 077 && cat > "$HOME/nkp-$CLUSTER_NAME-create.sh" <<'EOF'
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
  ${NTP_SERVERS:+--ntp-servers "$NTP_SERVERS"} \
  ${PC_PROJECT:+--pc-project "$PC_PROJECT"} \
  ${PC_CA_FILE:+--additional-trust-bundle "$(base64 < "$PC_CA_FILE" | tr -d '\n')"} \
  "$@"
EOF
)
```

### N4B. Air-gapped, internal registry mirror

NKP pushes the bundle images into a registry inside the new cluster. [pdf p.722-723]

1. List the bundle files:

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
ls "$BUNDLE_DIR"/container-images/ "$BUNDLE_DIR"/konvoy-bootstrap-image-*.tar
nkp create cluster nutanix --help | grep -A3 -- '--bundle '
```

The `--help` text names the mandatory bundles: the `konvoy-image-bundle` and the `kommander-image-bundle`. [live 2.19.0] The guide also adds the `nkp-release-specs` bundle. [pdf p.722-723] Add the Nutanix product catalog bundle only for NDK (skill `nkp-ndk`). [pdf p.723]

Done when: `ls` shows exactly one file for each of the three bundles and one bootstrap image file. If not, stop and ask the user.
2. Set `IMAGE_BUNDLES` with skill `nkp-airgap`, step 4 (the first block). Do not push the bundles: the create pushes them. Done when this prints three paths:

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
echo "$IMAGE_BUNDLES" | tr ',' '\n'
```

3. Write the create script. The bootstrap image comes from the bundle file. [live 2.19.0]

```bash
# CHANGES  (writes the create script of this cluster; creates nothing yet)
source ~/nkp-<cluster>.env 2>/dev/null
(umask 077 && cat > "$HOME/nkp-$CLUSTER_NAME-create.sh" <<'EOF'
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
  ${PC_PROJECT:+--pc-project "$PC_PROJECT"} \
  ${PC_CA_FILE:+--additional-trust-bundle "$(base64 < "$PC_CA_FILE" | tr -d '\n')"} \
  "$@"
EOF
)
```

### N4C. Site registry mirror

The registry must have all NKP images before the create. To seed it, use skill `nkp-airgap`. The operator host **and** every node subnet must reach the registry. [pdf p.713] On a connected site with a mirror, remove the `--airgapped` line and the `--bootstrap-cluster-image` line before you write the script. Empty mirror credentials (anonymous pulls) add no flag.

```bash
# CHANGES  (writes the create script of this cluster; creates nothing yet)
source ~/nkp-<cluster>.env 2>/dev/null
(umask 077 && cat > "$HOME/nkp-$CLUSTER_NAME-create.sh" <<'EOF'
nkp create cluster nutanix \
  --self-managed \
  --airgapped \
  --bootstrap-cluster-image "$(ls "$BUNDLE_DIR"/konvoy-bootstrap-image-*.tar)" \
  --registry-mirror-url "$REGISTRY_URL" \
  --registry-mirror-cacert "$REGISTRY_CA_FILE" \
  ${REGISTRY_MIRROR_USERNAME:+--registry-mirror-username "$REGISTRY_MIRROR_USERNAME"} \
  ${REGISTRY_MIRROR_PASSWORD:+--registry-mirror-password "$REGISTRY_MIRROR_PASSWORD"} \
  ${REGISTRY_HOST:+--registry-url "$REGISTRY_HOST"} \
  ${REGISTRY_USERNAME:+--registry-username "$REGISTRY_USERNAME"} \
  ${REGISTRY_PASSWORD:+--registry-password "$REGISTRY_PASSWORD"} \
  ${REGISTRY_HOST:+--registry-cacert "$REGISTRY_CA_FILE"} \
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
  ${NTP_SERVERS:+--ntp-servers "$NTP_SERVERS"} \
  ${PC_PROJECT:+--pc-project "$PC_PROJECT"} \
  ${PC_CA_FILE:+--additional-trust-bundle "$(base64 < "$PC_CA_FILE" | tr -d '\n')"} \
  "$@"
EOF
)
```

### N4D. Dry run, then create

The dry run writes the objects into a local file with mode 600. The file holds Secrets. Never print it. Never apply it with `kubectl`: an applied `--self-managed` file needs manual pivot steps. [pdf p.729]

- Management cluster (`--self-managed`): the dry run is also the preflight test. It loads the bootstrap image (about 1 min for a 3.4 GB file), makes a real kind bootstrap cluster (4 CPU and 4 GB free), installs CAPI, runs the preflight checks against Prism Central, prints the objects, and deletes the bootstrap cluster. 4 to 6 min, 7 Secrets. It creates no VMs. **Run it in tmux. Never put a short `timeout` around it:** a kill in the middle leaves the kind cluster on the operator host, and the next create then fails on the name. After a kill, remove it with `nkp delete bootstrap --kind-cluster-name konvoy-capi-bootstrapper` (`SKILL.md` "If the install fails"). [live 2.19.0, 2.19.1]
- Workload cluster: no kind cluster. It runs the preflight checks and prints the objects in less than 20 s, 5 Secrets. [live 2.19.0]

Show the plan (the file path, and that the file holds Secrets) and stop for "yes".
```bash
# CHANGES  (writes the dry-run objects to a local file; creates no VMs)
source ~/nkp-<cluster>.env 2>/dev/null
umask 077 && bash "$HOME/nkp-$CLUSTER_NAME-create.sh" --dry-run --output yaml > "$PWD/$CLUSTER_NAME-dryrun.yaml"
```

Show the user only these lines:

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
grep -n -E '^kind:|^  name:|image:|host:|addressRanges:|start:|end:|url:|replicas:|vcpuSockets:|memorySize:|systemDiskSize:|servers:|insecure:' "$PWD/$CLUSTER_NAME-dryrun.yaml"
```

The worker autoscaler annotations are min = max = `--worker-replicas`. [live 2.19.0] Done when: the dry run ends without an error, and the user agrees with the shown lines. Then the create. It runs in tmux on the operator host, so that a lost terminal does not stop it. The plan for "yes" includes the kubeconfig block of the `SKILL.md` step "Set the kubeconfig variables" (management or workload). Run that block after `RC=0` with no new approval. Durations: management 22–35 min, workload 3–13 min. A site mirror with a 3.4 GB bootstrap image and the 7 default nodes took 34 min 38 s: bootstrap image 1 min, kind 1 min, CAPI 2 min, VMs 2 min, control planes 4 min, pivot 4 min, Kommander 19 min. [live 2.19.1] `--timeout 60m` is the safe value; the 30m default is not enough for a slow mirror. Do not act on a HelmRelease before the log says `Cluster was created successfully!`: the last core app can retry for about 5 min (skill `nkp-troubleshooting`, file `flux.md` F3).

```bash
# CHANGES  (creates the cluster in a tmux session named after the cluster: VMs in Prism Central; management: kind, pivot, Kommander)
source ~/nkp-<cluster>.env 2>/dev/null
tmux new-session -d -s "nkp-$CLUSTER_NAME" -c "$PWD" "bash -c 'umask 077; source ~/nkp-$CLUSTER_NAME.env 2>/dev/null; bash ~/nkp-$CLUSTER_NAME-create.sh > ~/nkp-$CLUSTER_NAME-create.log 2>&1; echo RC=\$? >> ~/nkp-$CLUSTER_NAME-create.log'"
```

Read the log every few minutes (READ-ONLY): `source ~/nkp-<cluster>.env 2>/dev/null && tail -n 5 "$HOME/nkp-$CLUSTER_NAME-create.log"`. Management: `--self-managed` waits until the cluster is ready and the pivot is done; the last line before `RC=0` is `Cluster was created successfully!`. Workload: the last line before `RC=0` is `✓ Waiting for machines to be ready`, and this is a success. [live 2.19.0]

Done when: the log ends with `RC=0`. Then run the kubeconfig block of the `SKILL.md` step "Set the kubeconfig variables".

## N5. Create a workload cluster

The management cluster creates the workload cluster. Do not use `--self-managed`. Put the cluster in a workspace namespace. The CLI default namespace `kommander` is for the management cluster only. [live 2.19.0]

1. Find the workspace namespaces and the registry mirror of the management cluster:

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" get workspaces -A
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n kommander get nkpclusters -o jsonpath='{.items[*].spec.kommanderCluster.spec.ociRegistry.mirrorURL}{"\n"}'
```

The second command prints the site registry mirror URL of the management cluster. [live 2.19.0] An empty line means that the management cluster has no site mirror.

For a new workspace, use skill `nkp-identity-security`, file `rbac.md`, R5. Then run `get workspaces -A` again. `WORKSPACE_NS` is the WORKSPACE NAMESPACE column, never the workspace name: `nkp create workspace <ws>` makes the namespace `<ws>-<5 random characters>`. [live 2.19.0]

UNKNOWN (A-06): the registry flags for a workload cluster when the management cluster uses only the internal mirror (N4B). Find out with: `source ~/nkp-site.env 2>/dev/null && kubectl --kubeconfig "$MGMT_KUBECONFIG" -n kommander get nkpclusters -o jsonpath='{..ociRegistry}'`. Then ask the user if the site now has a seeded registry mirror. If not, stop.

2. Make a new cluster env file for the workload cluster (`SKILL.md` step "Prepare the env files"). Append its `CLUSTER_NAME`, a new `CP_VIP`, a new `LB_IP_RANGE`, and `WORKSPACE_NS`. When the workload cluster uses another subnet, append its `SUBNET` to this file too, and `PE_CLUSTER` and `STORAGE_CONTAINER` when they differ. Do not change `~/nkp-site.env`: the management cluster values stay there. The cluster env file sources the site file first, so its lines win only for this cluster.
3. Run section N2 (every case, and case 5). Write the create script. Without a site mirror (`REGISTRY_URL` empty), the script adds no mirror flags, and the workload cluster uses the Docker Hub credentials of the management cluster. [pdf p.675] On a connected site, remove the `--airgapped` line before you write the script.

```bash
# CHANGES  (writes the create script of this cluster; creates nothing yet)
source ~/nkp-<cluster>.env 2>/dev/null
(umask 077 && cat > "$HOME/nkp-$CLUSTER_NAME-create.sh" <<'EOF'
nkp create cluster nutanix \
  --kubeconfig "$MGMT_KUBECONFIG" \
  --namespace "$WORKSPACE_NS" \
  --airgapped \
  ${REGISTRY_URL:+--registry-mirror-url "$REGISTRY_URL" --registry-mirror-cacert "$REGISTRY_CA_FILE"} \
  ${REGISTRY_MIRROR_USERNAME:+--registry-mirror-username "$REGISTRY_MIRROR_USERNAME"} \
  ${REGISTRY_MIRROR_PASSWORD:+--registry-mirror-password "$REGISTRY_MIRROR_PASSWORD"} \
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
  ${NTP_SERVERS:+--ntp-servers "$NTP_SERVERS"} \
  ${PC_PROJECT:+--pc-project "$PC_PROJECT"} \
  ${PC_CA_FILE:+--additional-trust-bundle "$(base64 < "$PC_CA_FILE" | tr -d '\n')"} \
  "$@"
EOF
)
```

4. Do section N4D (dry run, then create). Done when: the log ends with `RC=0`. The workload create writes no kubeconfig: then run the workload block of the `SKILL.md` step "Set the kubeconfig variables". [live 2.19.0]

## N6. Verify (Nutanix checks)

Do the `SKILL.md` step "Verify" first. Then:
```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get storageclass
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n metallb-system get ipaddresspools
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n ntnx-system get pods
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n kube-system get pods -l k8s-app=cilium
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$WORKSPACE_NS" get svc kommander-traefik
```

Done when:
- `nutanix-volume` is the `(default)` StorageClass. [live 2.19.0]
- One IPAddressPool exists. All `ntnx-system` and Cilium pods are `Running` and ready.
- `kommander-traefik` has an EXTERNAL-IP from `LB_IP_RANGE`. It is the first IP when it was the first `LoadBalancer` Service (N1). On a workload cluster, this Service is in `$WORKSPACE_NS` on the workload cluster. [live 2.19.0]

## N7. Common failures

| Symptom | Cause | Fix |
|---|---|---|
| `Check: NutanixVMImage` … `found 0` | The image name is wrong, or the image is not in Prism Central. [pdf p.725] | Correct `VM_IMAGE`. The name must contain the Kubernetes version. [pdf p.726] Check the image placement policy. [pdf p.713] |
| `Check: NutanixStorageContainer` | The storage container is not in `PE_CLUSTER`. [pdf p.726] | Correct `STORAGE_CONTAINER`. |
| Preflight: CIDR overlap | The pod or service CIDR overlaps the node subnet, the other CIDR, or the VIP. [pdf p.726] | Add `--kubernetes-pod-network-cidr` and `--kubernetes-service-cidr` with free ranges to the script. |
| Preflight: Prism Central credentials | `NUTANIX_USER` or `NUTANIX_PASSWORD` is wrong, or the user has no role with the NKP permissions. [pdf p.705-707] | Ask the user to correct the file, or ask the PC admin to check the role. |
| TLS error to Prism Central | Prism Central has a self-signed certificate. [pdf p.719] | N4 "PC certificate". |
| VM creation fails after you add a trust bundle | A full CA bundle exceeds the 16 KB cloud-init limit. [pdf p.719] | Use only the Prism Central certificate. |
| `ImagePullBackOff` on an air-gapped site | The operator host reaches the registry, but the node subnet does not. Or the registry is not seeded. [pdf p.713] | Ask the user to check the routes and the firewall. Seed with skill `nkp-airgap`. |
| Image pulls fail on a connected site | Docker Hub rate limit, or no Nutanix Docker Hub token. [pdf p.675] | Use N4A with the token, or use a mirror (N4C). |
| konnector-agent pod stays in `Init` | The `karbon-core` service is off in Prism Central. [pdf p.724] | Ask the PC admin to enable `karbon-core`. On PC 7.3, the admin also upgrades karbon-core to 2.10.2. [pdf p.724] |
| Bootstrap cluster does not start | Less than 4 CPU or 4 GB memory is free, or cgroups v2 is off. [pdf p.718, p.48] | Free resources on the operator host. |
| API VIP does not answer | `CP_VIP` is in the DHCP or IPAM pool, or another host uses it. [pdf p.720] | Delete the cluster with skill `nkp-cluster-lifecycle`. Create it again with a free IP. |

For other failures, use skill `nkp-troubleshooting`. Before the pivot, `nkp diagnose` needs the bootstrap kubeconfig. That skill gives the command.
