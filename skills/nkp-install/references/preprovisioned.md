# Install NKP on pre-provisioned hosts (SSH)

Use this file from skill `nkp-install`. It covers a management cluster and a workload cluster on hosts that already exist: bare metal, or VMs that you made yourself. NKP does not create machines. It connects with SSH and configures the hosts. [pdf p.765, p.792] The flags match `nkp create cluster preprovisioned --help` and `nkp upload image-artifacts --help` of NKP 2.19.0. [live 2.19.0] Sections have P-labels so that they do not mix with the steps in `SKILL.md`.

- License: Pro or Ultimate. Starter supports only Nutanix AHV. [pdf p.27-28]
- Default storage is `localvolumeprovisioner`. It is not for production. Plan a CSI driver with skill `nkp-storage-backup`, file `csi.md` C9. [pdf p.766]
- The CNI on pre-provisioned clusters is Calico in the guide. [pdf p.765, p.788] For CNI changes, use skill `nkp-networking`.

Site variables of this file (rule 4; same use as the rules table):

| File | Site variables |
|---|---|
| `~/nkp-site.env` | `SSH_USER` `SSH_PRIVATE_KEY_FILE` |
| `~/nkp-<cluster>.env` | `CP_HOSTS` `WORKER_HOSTS` `VIP_INTERFACE` |

## P1. Check the hosts

Ask the user to confirm each item. [pdf p.766-767]

- x86_64 Linux hosts with a supported OS. SSH access works with an **unencrypted** private key. The SSH user is `root` or has passwordless `sudo`. [pdf p.766, p.768]
- Control plane: at least 3 hosts (3, 5, or 7), each 4 cores, 16 GB memory, about 80 GB free for `/var/lib/kubelet` and `/var/lib/containerd`, 15% free on the root file system. [pdf p.767, p.779]
- Workers: at least 4 hosts, each 8 cores, 32 GiB memory, the same disk rules. [pdf p.767]
- Swap is off. `firewalld` is stopped and disabled. The NKP ports are open. [pdf p.767]
- Local volumes: at least four volumes mounted under `/mnt/disks/` on each worker. [pdf p.767]
- The control-plane endpoint: an external load balancer on port 6443 (recommended), or the built-in virtual IP (kube-vip). The VIP is a static IPv4 on the Layer 2 network of the control-plane hosts, and the interface name is the same on each control-plane host. [pdf p.80, p.787][live 2.19.0]
- Time sync: `nkp create cluster preprovisioned` has no `--ntp-servers` flag. [live 2.19.0] The hosts get their time setup from the OS. Do not collect `NTP_SERVERS` for this provider.
- The pod CIDR (`192.168.0.0/16`) and the service CIDR (`10.96.0.0/12`) do not overlap the host subnet. [live 2.19.0][pdf p.788]

Done when: the user confirms every item.

## P2. Collect the values

Append each known value to the file in the "File" column (rule 4). "Req": M management cluster, W workload cluster, AG air-gapped.

| Variable | File | Req | Rule |
|---|---|---|---|
| `CLUSTER_NAME` | cluster | all | only `a-z`, `0-9`, `.`, `-`. Use the same name in the inventory. [pdf p.777] |
| `CP_HOSTS` | cluster | all | comma-separated IPs or host names of the control-plane hosts |
| `WORKER_HOSTS` | cluster | all | comma-separated IPs or host names of the workers |
| `CP_VIP` | cluster | all | the built-in VIP, or the address of the external load balancer [live 2.19.0] |
| `VIP_INTERFACE` | cluster | VIP only | the NIC name for the VIP, for example `eth1`. Do not set it for an external load balancer. [live 2.19.0] |
| `LB_IP_RANGE` | cluster | all | `<first-ip>-<last-ip>` for MetalLB, in the host subnet [pdf p.83] |
| `WORKSPACE_NS` | cluster | all | M: `default` (see below). W: the workspace namespace. |
| `SSH_USER` | site | all | the SSH user on the hosts [pdf p.768] |
| `SSH_PRIVATE_KEY_FILE` | site | all | the path of the unencrypted private key [live 2.19.0] |
| `MGMT_KUBECONFIG` | site | W | the management cluster kubeconfig |
| `BUNDLE_DIR` | site | AG | the extracted bundle folder |
| `REGISTRY_URL`, `REGISTRY_CA_FILE` | site | AG or mirror | the site registry mirror |

- Management cluster: append `WORKSPACE_NS='default'`, **not** `kommander`. The CLI default namespace for this provider is `default`, and the guide puts the inventory in `default`. [live 2.19.0][pdf p.768]
- UNKNOWN (P-14): the namespace of the pre-provisioned management cluster objects after the pivot. Find out with: `source ~/nkp-site.env 2>/dev/null && kubectl --kubeconfig "$MGMT_KUBECONFIG" get clusters -A`. If the cluster is in another namespace, append the new `WORKSPACE_NS` to the cluster env file.

Secret lines (the user adds them with an editor):

| Case | Secret variables |
|---|---|
| connected, no mirror | `NUTANIX_REGISTRY_USERNAME`, `NUTANIX_REGISTRY_TOKEN` |
| mirror | `REGISTRY_MIRROR_USERNAME`, `REGISTRY_MIRROR_PASSWORD` |

Check the files (prints names only). Add `MGMT_KUBECONFIG` for W, and `BUNDLE_DIR REGISTRY_URL` for AG:

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
for v in CLUSTER_NAME CP_HOSTS WORKER_HOSTS CP_VIP LB_IP_RANGE WORKSPACE_NS SSH_USER SSH_PRIVATE_KEY_FILE; do if [ -n "$(printenv "$v")" ]; then echo "set: $v"; else echo "MISSING: $v"; fi; done
```

Done when: each name prints `set:`.

Then check SSH to each host from the operator host:

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
for h in ${CP_HOSTS//,/ } ${WORKER_HOSTS//,/ }; do ssh -i "$SSH_PRIVATE_KEY_FILE" -o BatchMode=yes "$SSH_USER@$h" 'hostname; sudo -n true && echo sudo-ok; swapon --show | wc -l'; done
```

Done when: each host prints its name, `sudo-ok`, and `0` (no swap).

If it prints `Host key verification failed`, the host is not in `~/.ssh/known_hosts`. Ask the user to check the host keys and add them, for example with `ssh-keyscan` (CHANGES). Then run the block again.

## P3. Air-gapped: upload the artifacts to the hosts

Skip this step on a connected site. The hosts cannot download OS packages, containerd, and the Kubernetes images, so the operator host copies them over SSH. [pdf p.71-73, p.801-802]

1. The site registry mirror must have the NKP images. `nkp create cluster preprovisioned` has no `--bundle` flag and no `--airgapped` flag. [live 2.19.0] To seed the mirror, use skill `nkp-airgap`.
2. The OS packages are not in the bundle. Make the OS package bundle on a connected host with `nkp create package-bundle` (skill `nkp-airgap`), and put it in `$BUNDLE_DIR/image-artifacts`. [pdf p.73]
3. List the artifacts:

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
ls "$BUNDLE_DIR"/image-artifacts/ "$BUNDLE_DIR"/image-artifacts/images/
```

The 2.19.0 bundle has containerd files for each OS and the Kubernetes image files in `image-artifacts/images/`. [live 2.19.0] Done when: the user confirms that the OS package bundle for the host OS is also there.

4. Upload. Here `--ssh-username` is the SSH login user. [live 2.19.0][pdf p.802] Add `--fips` only for FIPS hosts, and `--nvidia-runfile <file>` only for GPU hosts (add them as lines before you run the block). [live 2.19.0][pdf p.801-802]

```bash
# CHANGES  (copies packages, containerd, and images to every host over SSH and installs them)
source ~/nkp-<cluster>.env 2>/dev/null
nkp upload image-artifacts \
  --ssh-host "$CP_HOSTS,$WORKER_HOSTS" \
  --ssh-username "$SSH_USER" \
  --ssh-private-key-file "$SSH_PRIVATE_KEY_FILE" \
  --artifacts-directory "$BUNDLE_DIR/image-artifacts"
```

Done when: the command ends without an error.

## P4. Write the inventory file

The inventory tells NKP which hosts are control-plane hosts and which are workers. [pdf p.768-769] The SSH key Secret name is `<cluster>-ssh-key`. The guide's `--self-managed` command gives only `--ssh-private-key-file` and the inventory file. Thus the CLI makes the Secret. [pdf p.82][live 2.19.0]

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

- The pool names `<cluster>-control-plane` and `<cluster>-md-0` follow the guide. [pdf p.768-769]
- The inventory namespace is the namespace of the cluster: `WORKSPACE_NS`. [pdf p.768-769]
- `--control-plane-replicas` sets how many control-plane hosts NKP uses. [pdf p.768]

Done when: `grep -c 'address:'` on the file prints the total number of hosts.

## P5. Write the create script

The block is for the management cluster (`--self-managed`). For a workload cluster, replace the `--self-managed` line with `--kubeconfig "$MGMT_KUBECONFIG" \` before you write the script. `--kubeconfig` is ignored with `--self-managed`. [live 2.19.0] Optional flags come from their variables. Other flags (`--control-plane-endpoint-port`, `--control-plane-replicas`, `--worker-replicas`, `--override-file`): add them as lines before `"$@"`. [live 2.19.0][pdf p.787] Proxy: skill `nkp-networking`, its file `proxy.md`, X3.

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

- NKP connects with the user in the inventory (`SSH_USER`). On `nkp create cluster`, `--ssh-username` is a different thing: the user that NKP creates on the nodes (default `konvoy`). [live 2.19.0] Do not add it.
- `--bootstrap-cluster-image` is only for the management cluster (air-gapped). Remove that line for a workload cluster. [live 2.19.0]
- The CLI takes the mirror password and the Docker Hub token only as flags. Other users on the host can see them in the process list. [live 2.19.0] Tell the user this.

Done when: the script file exists.

## P6. Dry run, then create

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

The file holds Secrets. Never print it. Done when: the dry run ends without an error, and the user agrees with the shown lines. Then create:

```bash
# CHANGES  (installs Kubernetes on the hosts over SSH; with --self-managed also the bootstrap cluster and the pivot)
source ~/nkp-<cluster>.env 2>/dev/null
bash "$HOME/nkp-$CLUSTER_NAME-create.sh"
```

- The default timeout is 45m. [live 2.19.0] Add `--timeout 90m` before `"$@"` for many hosts.
- If the create reports that the Secret `<cluster>-ssh-key` is missing (workload cluster), make it in the management cluster, then run the create again. Field scripts do this step. [pdf p.777][field]

```bash
# CHANGES  (makes the SSH key Secret of this cluster in the management cluster; prints nothing secret)
source ~/nkp-<cluster>.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" create secret generic "$CLUSTER_NAME-ssh-key" --from-file=ssh-privatekey="$SSH_PRIVATE_KEY_FILE" && kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" label secret "$CLUSTER_NAME-ssh-key" clusterctl.cluster.x-k8s.io/move=
```

- Done when: the command ends without an error. Then go to the `SKILL.md` step "Set the kubeconfig variables".

## P7. MetalLB

The pre-provisioned provider has no load-balancer range flag. [live 2.19.0] Give MetalLB an address pool after the create (Layer 2 mode). [pdf p.83-84] For BGP mode, use skill `nkp-networking`.

```bash
# CHANGES  (writes metallb-conf.yaml and applies the MetalLB pool to the new cluster)
source ~/nkp-<cluster>.env 2>/dev/null
printf -- 'apiVersion: metallb.io/v1beta1\nkind: IPAddressPool\nmetadata:\n  name: default\n  namespace: metallb-system\nspec:\n  addresses:\n  - %s\n---\napiVersion: metallb.io/v1beta1\nkind: L2Advertisement\nmetadata:\n  name: default\n  namespace: metallb-system\nspec:\n  ipAddressPools:\n  - default\n' "$LB_IP_RANGE" > "$PWD/$CLUSTER_NAME-metallb-conf.yaml"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" apply -f "$PWD/$CLUSTER_NAME-metallb-conf.yaml"
```

Done when: `kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n metallb-system get ipaddresspools` shows `default`.

## P8. Kommander (management cluster)

Do the `SKILL.md` step "Check or install Kommander". The guide installs Kommander as a separate step on this provider. [pdf p.84-86] Before the install, add one Rook Ceph override to `kommander.yaml`, because the local static provisioner cannot give `volumeMode: Block` PVCs. [pdf p.85-86] Use all raw devices:

```yaml
rook-ceph-cluster:
    enabled: true
    values: |
      cephClusterSpec:
        storage:
          storageClassDeviceSets: []
          useAllDevices: true
          useAllNodes: true
```

To use only some devices, set `useAllDevices: false` and `deviceFilter: "^sdb."` (a regex). [pdf p.86] Ask the user which disks Ceph can use. Ceph deletes the data on them.

Done when: the HelmRelease wait in the `SKILL.md` step "Verify" passes.

## P9. Common failures

| Symptom | Cause | Fix |
|---|---|---|
| SSH or `sudo` fails in the create | Encrypted key, wrong user, or `sudo` asks for a password. [pdf p.766, p.768] | Fix the key or the `sudoers` file. Run P1 again. |
| The API endpoint does not answer | The VIP is in use, or `VIP_INTERFACE` is not on every control-plane host. [live 2.19.0] | Use a free VIP and the correct NIC name. |
| Host preparation fails on an air-gapped site | The artifacts or the OS package bundle are missing. [pdf p.73] | Run P3 again with the correct bundle. |
| `ImagePullBackOff` | The registry mirror is not seeded, or the hosts cannot reach it. [pdf p.770] | Seed with skill `nkp-airgap`. Check the routes. |
| Services stay `<pending>` | No MetalLB pool. [pdf p.83] | Run P7. |
| Kommander apps fail on Ceph | No raw disks, or the override is missing. [pdf p.85-86] | Fix the override in P8, then run the install again. |

For node pools and deleting a cluster, use skill `nkp-cluster-lifecycle`. For other failures, use skill `nkp-troubleshooting`.
