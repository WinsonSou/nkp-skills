# Install NKP on Nutanix AHV (Prism Central)

Use this file from skill `nkp-install`. It covers a management cluster and a workload cluster, connected and air-gapped. The flags match `nkp create cluster nutanix --help` of NKP 2.19.0. [live 2.19.0] Sections have N-labels so that they do not mix with the steps in `SKILL.md`.

## N1. Collect the values

Ask the user for each value. Append each known value to the file in the "File" column (rule 4). "Req" says which case needs it: 4A connected, 4B air-gapped with the internal mirror, 4C site registry mirror, 5 workload cluster. "all" means every case.

| Variable | File | Req | Rule |
|---|---|---|---|
| `CLUSTER_NAME` | cluster | all | only `a-z`, `0-9`, `.`, `-` [pdf p.718] |
| `CP_VIP` | cluster | all | a static IP in the node subnet CIDR, **outside** the IPAM or DHCP pool. No other host uses it. [pdf p.720] |
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

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
nkp version
curl -sk -o /dev/null -w 'pc: %{http_code}\n' "$PC_ENDPOINT"
pc=${PC_ENDPOINT#https://}; pc=${pc%%[:/]*}
curl -sk --netrc-file <(printf 'machine %s login %s password %s\n' "$pc" "$(printenv NUTANIX_USER)" "$(printenv NUTANIX_PASSWORD)") -o /dev/null -w 'pc login: %{http_code}\n' "$PC_ENDPOINT/api/clustermgmt/v4.0/config/clusters"
openssl s_client -connect "$pc:9440" -servername "$pc" </dev/null 2>/dev/null | openssl x509 -noout -subject -ext subjectAltName
ping -c 2 "$CP_VIP"
first=${LB_IP_RANGE%-*}; last=${LB_IP_RANGE#*-}
for i in $(seq "${first##*.}" "${last##*.}"); do ping -c 1 -W 1 "${first%.*}.$i" >/dev/null && echo "IN USE: ${first%.*}.$i" || echo "no reply: ${first%.*}.$i"; done
test -f "$SSH_PUBKEY_FILE" && echo "ssh key file found"
```

`--netrc-file <(...)` keeps the password out of the process list. A password with a space or a `"` fails in a netrc line: then the user checks the login in the UI. The LB loop expects the first and the last IP in the same /24. Site mirror (4C, 5 mirror): a `401` without credentials also proves that the registry answers. [live 2.19.0]

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
reg=${REGISTRY_URL#https://}; reg=${reg%%/*}
curl -s --cacert "$REGISTRY_CA_FILE" -o /dev/null -w 'mirror: %{http_code}\n' "https://$reg/v2/"
curl -s --cacert "$REGISTRY_CA_FILE" --netrc-file <(printf 'machine %s login %s password %s\n' "${reg%%:*}" "$(printenv REGISTRY_MIRROR_USERNAME)" "$(printenv REGISTRY_MIRROR_PASSWORD)") -o /dev/null -w 'mirror login: %{http_code}\n' "https://$reg/v2/"
```

Done when:
- `pc:` is not `000` (`302` is normal). `pc login:` is `200` (`401` = wrong user or password). [live 2.19.0] More credential checks: skill `nutanix-iam`, RECIPES.md "Read-only credential check". If skill `nutanix-iam` is not installed, the user does it in Prism Central.
- `openssl` shows the PC certificate: see N4 "PC certificate". `ping` of `CP_VIP` gets no reply, and the loop prints `no reply` for each LB IP. If the network blocks ICMP, "no reply" proves nothing. Use the free-IP check of N1 "IP plan", or ask the user to confirm that no host uses these IPs.
- The output has "ssh key file found". On a mirror site, `mirror:` is `200` or `401`, and `mirror login:` is `200`.

## N4. Create the management cluster

Choose one case:

| Case | Section |
|---|---|
| Connected, no registry mirror | N4A |
| Air-gapped, no site registry: NKP puts the bundle images in an internal registry in the new cluster | N4B |
| Site registry mirror (Harbor, Nexus, Artifactory) that is already seeded | N4C |

Use only one registry method: `--bundle` (internal mirror) or `--registry-mirror-*` (site mirror). [pdf p.725] The flags `--registry-url`, `--registry-username`, `--registry-password`, and `--registry-cacert` do not make a mirror. They give credentials for one upstream registry, for example Docker Hub. [pdf p.723]

Each case writes a create script: `~/nkp-<name>-create.sh` (mode 700). The dry run and the real create run the same script (section N4D). The script ends with `"$@"`, so the dry run adds its flags at the end.

The script adds optional flags only when their variable has a value: `PC_PROJECT` adds `--pc-project`. `PC_CA_FILE` adds `--additional-trust-bundle` with the certificate as Base64 text. [pdf p.719]
- UNKNOWN (P-07): the format that `--additional-trust-bundle` accepts. The key is in the dry run also when it is empty, so count the value, not the key. Run it only with `PC_CA_FILE` set. Find out with: `source ~/nkp-<cluster>.env 2>/dev/null && grep -E '^ *additionalTrustBundle:' "$PWD/$CLUSTER_NAME-dryrun.yaml" | awk '{print length($2)}'` (`2` = `""` = empty).
- Use only the Prism Central certificate, not a full CA bundle. A large file exceeds the 16 KB cloud-init limit. [pdf p.719]
- **PC certificate** (the `openssl` line of N3). No `subjectAltName`, or a SAN without the host or IP of `PC_ENDPOINT`: a CA file cannot work, because the hostname check fails. Use `--insecure` (it skips the check [pdf p.719]) after the user agrees. A SAN with that host or IP: append `PC_CA_FILE`. The Nutanix default PC certificate has no SAN. `--insecure` does not change the mirror CA check. [live 2.19.0] More: skill `nutanix-api`, REFERENCE.md "PC certificate check".
- Management cluster: add `--timeout 60m`. The create takes 22–24 min, and the CLI default is `30m0s`. A workload create takes 3–13 min: the default is enough. [live 2.19.0]
- Other flags (`--fips`, `--onboard-to-prism-central=false`, `--insecure`, `--timeout 60m`, the size flags in N1): add them as lines before `"$@"` in the script block before you write it. [live 2.19.0] For a proxy, add the lines from skill `nkp-networking`, its file `proxy.md`, X3.
- Cluster in a Flow VPC: add the lines from skill `nkp-vpc`, step 4.
- Custom domain and ingress certificate at create time (`--cluster-hostname`, `--ingress-certificate`, `--ingress-private-key`, `--ingress-ca`): skill `nkp-networking`, its file `ingress-certs.md`, I1.
- The CLI takes the mirror password and the Docker Hub token only as flags. Other users on the host can see them in the process list. [live 2.19.0] Tell the user this.

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

- Management cluster (`--self-managed`): the dry run is also the preflight test. It makes a kind bootstrap cluster (4 CPU and 4 GB free), installs CAPI, runs the preflight checks against Prism Central, prints the objects, and deletes the bootstrap cluster. About 3 min, 7 Secrets. It creates no VMs. If it stops before the end, run `nkp delete bootstrap` (`SKILL.md` "If the install fails"). [live 2.19.0]
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

The worker autoscaler annotations are min = max = `--worker-replicas`. [live 2.19.0] Done when: the dry run ends without an error, and the user agrees with the shown lines. Then the create. It runs in tmux on the operator host, so that a lost terminal does not stop it. The plan for "yes" includes the kubeconfig block of the `SKILL.md` step "Set the kubeconfig variables" (management or workload). Run that block after `RC=0` with no new approval. Durations: management 22–24 min, workload 3–13 min. [live 2.19.0]

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
