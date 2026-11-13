# Install an NKP Metal workload cluster (physical servers)

Use this file from skill `nkp-install`. NKP Metal is new in 2.19. The flags match `nkp create cluster metal --help` of NKP 2.19.0. [live 2.19.0] Sections have M-labels so that they do not mix with the steps in `SKILL.md`.

What NKP Metal is: Foundation Central images physical servers with the NKP host OS. Each server then registers with an existing management cluster and appears in the Metal Host Inventory. The management cluster creates workload clusters on these hosts. [pdf p.741, p.747]

- An NKP Metal cluster is always a **workload** cluster. There is no `--self-managed` flag and no bootstrap cluster. [live 2.19.0] Create the management cluster first (for example on AHV: [nutanix.md](nutanix.md)).
- Full Metal cluster: control plane and workers on physical servers. This file covers it. [pdf p.751]
- Mixed cluster: control plane and the standard workers are AHV VMs, and extra worker pools are on physical servers. Create the AHV workload cluster with [nutanix.md](nutanix.md) section N5. Then add the Metal node pool with skill `nkp-cluster-lifecycle`. The Metal pool needs its own StorageClass (`nutanix-volume-metal`): use skill `nkp-storage-backup`. [pdf p.750]

Site variables of this file (rule 4; same use as the rules table):

| File | Site variables |
|---|---|
| `~/nkp-<cluster>.env` | `CP_HOSTS` `WORKER_HOSTS` `CP_HOST_SELECTOR` `WORKER_HOST_SELECTOR` |

## M1. Check the prerequisites

Ask the user to confirm each item. The agent cannot check Foundation Central or the BMCs.

- The management cluster has a **Pro or Ultimate** license. Starter does not support NKP Metal. [pdf p.744]
- Servers: x86_64, on the hardware compatibility list, with a BMC that Foundation Central reaches on the out-of-band network. [pdf p.743-744]
- Foundation Central is deployed. It must stay available for imaging and re-imaging. [pdf p.743, p.747]
- The host OS ISO (Ubuntu 24.04 LTS) and its metadata JSON file are from the Nutanix portal ("NKP Operating System Images"). Keep the two files together. Nutanix does not support FIPS, custom, or other host images. [pdf p.743-745]
- Network: DHCP on the host network, IPv4 only. DNS and NTP reach the servers. Each server reaches the management cluster. [pdf p.743-744]
- An AOS cluster with a storage container for the CSI volumes. Metal hosts have no hypervisor, so volume traffic goes directly to Prism Element. [pdf p.744, p.754]
- Air-gapped site: the registry mirror has the NKP images and the host OS ISO. To seed it, use skill `nkp-airgap`. [pdf p.743]

Done when: the user confirms every item.

## M2. Collect the values

Append each known value to the file in the "File" column (rule 4). Make a new cluster env file for this cluster (`SKILL.md` step "Prepare the env files"). Do not append `WORKSPACE_NS='kommander'`: a Metal cluster is a workload cluster.

| Variable | File | Rule |
|---|---|---|
| `CLUSTER_NAME` | cluster | only `a-z`, `0-9`, `.`, `-` |
| `WORKSPACE_NS` | cluster | the workspace namespace of the hosts. CLI default: `kommander-default-workspace`. [live 2.19.0] |
| `CP_VIP` | cluster | a static IPv4 on the Layer 2 network of the control-plane hosts, outside the DHCP pool. [live 2.19.0][pdf p.743] |
| `LB_IP_RANGE` | cluster | `<first-ip>-<last-ip>`, contiguous, outside the DHCP pool. [pdf p.756] |
| `CP_HOST_SELECTOR` or `CP_HOSTS` | cluster | a label selector (`key=value`), or a comma-separated list of host names. Use one, not both. [live 2.19.0] |
| `WORKER_HOST_SELECTOR` or `WORKER_HOSTS` | cluster | the same for the workers. [live 2.19.0] |
| `PC_ENDPOINT` | site | Prism Central for the CSI driver, for example `https://<host>:9440` [live 2.19.0] |
| `PE_CLUSTER` | site | the Prism Element cluster that has the storage container [pdf p.757] |
| `STORAGE_CONTAINER` | site | the storage container for CSI volumes [pdf p.757] |
| `SSH_PUBKEY_FILE` | site | optional. NKP adds this key for user `konvoy`. [live 2.19.0] |
| `MGMT_KUBECONFIG` | site | the management cluster kubeconfig |
| `REGISTRY_URL`, `REGISTRY_CA_FILE` | site | air-gapped site or site mirror |

Secret lines (the user adds them with an editor):

| Case | Secret variables |
|---|---|
| all | `NUTANIX_USER`, `NUTANIX_PASSWORD` (Prism Central, for the CSI driver) |
| connected, no mirror | `NUTANIX_REGISTRY_USERNAME`, `NUTANIX_REGISTRY_TOKEN` |
| mirror | `REGISTRY_MIRROR_USERNAME`, `REGISTRY_MIRROR_PASSWORD` |

UNKNOWN (P-13): how `nkp create cluster metal` gets the Prism Central credentials for the CSI driver. The help has no credential flag. Find out with: `source ~/nkp-<cluster>.env 2>/dev/null && grep -n -E '^kind: Secret|^  name: ' "$PWD/$CLUSTER_NAME-dryrun.yaml"`. Then ask the user to confirm that the CSI Secret is in the dry run.

Check the files (prints names only):

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
for v in CLUSTER_NAME WORKSPACE_NS CP_VIP LB_IP_RANGE PC_ENDPOINT PE_CLUSTER STORAGE_CONTAINER MGMT_KUBECONFIG NUTANIX_USER NUTANIX_PASSWORD; do if [ -n "$(printenv "$v")" ]; then echo "set: $v"; else echo "MISSING: $v"; fi; done
for v in CP_HOST_SELECTOR CP_HOSTS WORKER_HOST_SELECTOR WORKER_HOSTS; do if [ -n "$(printenv "$v")" ]; then echo "set: $v"; fi; done
```

Done when: the first loop prints only `set:` lines, and the second loop prints one control-plane name and one worker name.

## M3. Make the bootstrap token

The token lets the imaged hosts register with this management cluster. `nkp create bootstrap-token` is in `nkp create --help` [live 2.19.0]; its `--kubeconfig` flag is from [pdf p.746]. Use the token only with the cluster that made it. The file holds credentials: never print it, and do not change it. [pdf p.745-746] The user can also download it in the NKP UI: **Administration > Metal Host Inventory > Download Token**. [pdf p.746]

```bash
# CHANGES  (creates a bootstrap token in the management cluster and writes it to a local file, mode 600)
source ~/nkp-site.env 2>/dev/null
umask 077 && nkp create bootstrap-token --kubeconfig "$MGMT_KUBECONFIG" > "$HOME/nkp-bootstrap-token.conf"
```

Done when: the command ends without an error, and `test -s "$HOME/nkp-bootstrap-token.conf" && echo ok` prints `ok`.

## M4. Image the hosts (the user does this in Foundation Central)

Tell the user to do these steps in Foundation Central. The agent cannot do them. [pdf p.747]
1. Add the NKP host OS image: the ISO and its metadata JSON file.
2. Onboard the servers (Foundation Central connects to the BMCs).
3. Image the servers. Give the bootstrap token file from M3.
4. Ultimate only: in the NKP UI, **Administration > Metal Host Inventory**, select the hosts with Usage `Unassigned`, and **Move to Workspace**. On Pro, NKP assigns the hosts automatically. [pdf p.747-748]
5. Optional: add host labels for the selectors (UI: **Edit Labels**). [pdf p.749]

Then check the hosts:

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get hosts --show-labels
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get assignedhosts
```

Done when: the workspace has enough free hosts: 3 for the control plane (default) and 4 workers (default), and the labels match the selectors. [live 2.19.0][pdf p.756]

## M5. Write the create script

The script adds optional flags only when their variable has a value. It uses a host selector when `CP_HOST_SELECTOR` is set, or a host list when `CP_HOSTS` is set. A host list sets the replica count. [live 2.19.0] Air-gapped site: set `REGISTRY_URL`. Without a mirror, the script uses the Nutanix Docker Hub token. Other flags (`--control-plane-replicas`, `--worker-replicas`, `--csi-file-system xfs`, `--csi-reclaim-policy Retain`, `--kubernetes-image-uri`): add them as lines before `"$@"`. [live 2.19.0] Proxy: skill `nkp-networking`, its file `proxy.md`, X3.

```bash
# CHANGES  (writes the create script of this cluster; creates nothing yet)
source ~/nkp-<cluster>.env 2>/dev/null
(umask 077 && cat > "$HOME/nkp-$CLUSTER_NAME-create.sh" <<'EOF'
nkp create cluster metal \
  --kubeconfig "$MGMT_KUBECONFIG" \
  --namespace "$WORKSPACE_NS" \
  --cluster-name "$CLUSTER_NAME" \
  --control-plane-endpoint-ip "$CP_VIP" \
  --kubernetes-service-load-balancer-ip-range "$LB_IP_RANGE" \
  ${CP_HOST_SELECTOR:+--control-plane-host-selector "$CP_HOST_SELECTOR"} \
  ${CP_HOSTS:+--control-plane-hosts "$CP_HOSTS"} \
  ${WORKER_HOST_SELECTOR:+--worker-host-selector "$WORKER_HOST_SELECTOR"} \
  ${WORKER_HOSTS:+--worker-hosts "$WORKER_HOSTS"} \
  --csi-prism-central-endpoint "$PC_ENDPOINT" \
  --csi-prism-element-cluster "$PE_CLUSTER" \
  --csi-storage-container "$STORAGE_CONTAINER" \
  ${SSH_PUBKEY_FILE:+--ssh-public-key-file "$SSH_PUBKEY_FILE"} \
  ${REGISTRY_URL:+--registry-mirror-url "$REGISTRY_URL"} \
  ${REGISTRY_CA_FILE:+--registry-mirror-cacert "$REGISTRY_CA_FILE"} \
  ${REGISTRY_MIRROR_USERNAME:+--registry-mirror-username "$REGISTRY_MIRROR_USERNAME"} \
  ${REGISTRY_MIRROR_PASSWORD:+--registry-mirror-password "$REGISTRY_MIRROR_PASSWORD"} \
  ${NUTANIX_REGISTRY_TOKEN:+--nutanix-registry-username "$NUTANIX_REGISTRY_USERNAME" --nutanix-registry-password "$NUTANIX_REGISTRY_TOKEN"} \
  "$@"
EOF
)
```

- `--kubernetes-image-uri` (format `oci://<registry>/<path>/<image>:<tag>`) sets the host OS image. When it is not set, NKP finds the image from the Kubernetes version and the registry mirror. [live 2.19.0]
- The CLI takes the mirror password and the Docker Hub token only as flags. Other users on the host can see them in the process list. [live 2.19.0] Tell the user this.

Done when: the script file exists.

## M6. Dry run, then create

The dry run writes the objects to a local file with mode 600. The file holds Secrets. Never print it.

```bash
# CHANGES  (writes the dry-run objects to a local file; creates no cluster)
source ~/nkp-<cluster>.env 2>/dev/null
umask 077 && bash "$HOME/nkp-$CLUSTER_NAME-create.sh" --dry-run --output yaml > "$PWD/$CLUSTER_NAME-dryrun.yaml"
```

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
grep -n -E '^kind:|^  name:|^  namespace:|host:|hostSelector:|matchLabels:|start:|end:|url:' "$PWD/$CLUSTER_NAME-dryrun.yaml"
```

Done when: the dry run ends without an error, and the user agrees with the shown lines. Then create:

```bash
# CHANGES  (creates the Metal cluster: claims the hosts, installs Kubernetes on them)
source ~/nkp-<cluster>.env 2>/dev/null
bash "$HOME/nkp-$CLUSTER_NAME-create.sh"
```

- `--wait` is on by default. The default timeout is 1h. [live 2.19.0] Creation can take longer when hosts are still imaging. [pdf p.757]
- Done when: the command ends without an error. Then go to the `SKILL.md` step "Set the kubeconfig variables" (workload cluster).

## M7. Verify (Metal checks)

Do the `SKILL.md` step "Verify" first. Then:

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get assignedhosts
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get machines -l cluster.x-k8s.io/cluster-name="$CLUSTER_NAME"
nkp get nodepools --cluster-name "$CLUSTER_NAME" --namespace "$WORKSPACE_NS" --kubeconfig "$MGMT_KUBECONFIG"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get storageclass
```

Done when: every Machine is `Running`, the node pool READY count equals DESIRED, and one StorageClass is `(default)`. The `nkp get nodepools` flags are from [pdf p.761].

## M8. Common failures

| Symptom | Cause | Fix |
|---|---|---|
| No hosts in `get hosts` | Imaging is not done, the token is from another management cluster, or the host cannot reach the management cluster. [pdf p.745, p.747] | Ask the user to check Foundation Central. Make a new token (M3) on the correct cluster. |
| Hosts show `Unassigned` (Ultimate) | Ultimate does not assign hosts to a workspace. [pdf p.747] | Move the hosts to the workspace in the UI (M4). |
| Create waits for hosts | Too few free hosts match the selector. [pdf p.756] | Add labels, or use `CP_HOSTS` / `WORKER_HOSTS`. |
| `--control-plane-hosts` and `--control-plane-host-selector` error | The two flags are mutually exclusive. [live 2.19.0] | Keep only one of the two variables. |
| Metal workload PVC stays `Pending` on a mixed cluster | The default StorageClass uses hypervisor-attached volumes. [pdf p.750] | Use skill `nkp-storage-backup`, file `csi.md` C3, for `nutanix-volume-metal`. |

For node pools, scaling, labels, firmware maintenance, and host removal, use skill `nkp-cluster-lifecycle`. For other failures, use skill `nkp-troubleshooting`.
