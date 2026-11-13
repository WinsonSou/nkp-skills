# nkp diagnose: support bundle

Use this file from skill `nkp-troubleshooting`. `nkp diagnose` collects a support bundle for Nutanix support. It is the NKP fork of troubleshoot.sh. [pdf p.1049]

| File | Site variables |
|---|---|
| `~/nkp-site.env` | `BOOTSTRAP_KUBECONFIG` `DIAG_DIR` `DIAG_INVENTORY` |

`DIAG_DIR` is a folder on the operator host with free space for the bundle. `DIAG_INVENTORY` is the SSH inventory file for section D4. `BOOTSTRAP_KUBECONFIG`: [controllers.md](controllers.md), B2.

## What the bundle has [live 2.19.0][pdf p.1049-1050]

`nkp diagnose default-config` prints the collectors. The 2.19.0 default:
- `clusterInfo`, `clusterResources` (all CRDs and custom resources), `allLogs` (all pods, all namespaces).
- `configMap` with `includeAllData: true`: **all ConfigMap data**, all namespaces.
- `secret`: the names and metadata of Secrets, not the values. [pdf p.1050]
- `execCopyFromHost` `node-diagnostics`: a privileged pod on each node, also the control plane, with host network, PID, and IPC. It copies node files (for example the kube-apiserver audit log [pdf p.1003]). Image `docker.io/mesosphere/dkp-diagnostics-node-collector:v0.14.0`, pause image `docker.io/mesosphere/pause-busybox:3.6`, timeout `600s`.

So `nkp diagnose` is **not** READ-ONLY: it starts pods on every node and writes a file. It is a CHANGES command. The bundle holds ConfigMap data, logs, host names, and IPs. The user decides where it goes. Do not open or print its files in the chat, except the error files in D3.

The guide shows older defaults (`pause-alpine:3.2`, `nkp-diagnostics-node-collector`, timeout 30 s). [pdf p.1053-1054] Trust `default-config` from your `nkp` binary.

## D1. Bundle of a running cluster

**Air-gapped site, first.** The node collector image of `nkp diagnose` is not in the 2.19.0 bundle. Before the first run, do skill `nkp-airgap`, its file `prestage.md`, item P5 (the facts, the two choices, and A-08 are there). Use what P5 gives. If the user does not want either choice, run without node data: make a D5 file without the `execCopyFromHost` collector, and run it with block B. Then D3 accepts "no `node-diagnostics`".

Check the space and the version:

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
nkp version
df -h "${DIAG_DIR:-$PWD}"
nkp diagnose default-config | grep -n -E 'image:|pauseImage:|timeout:'
```

The plan says: the cluster, that a privileged pod runs on each node for up to 600 s, that the bundle holds ConfigMap data and all pod logs, and the folder. After "yes":

**Block A. Default collectors** (connected site, or after P5 choice A):

```bash
# CHANGES  (runs collector pods on every node; writes support-bundle-*.tar.gz in DIAG_DIR)
source ~/nkp-<cluster>.env 2>/dev/null
cd "${DIAG_DIR:?}" && nkp diagnose --kubeconfig "$CLUSTER_KUBECONFIG" --bundle-name-prefix "$CLUSTER_NAME"
```

**Block B. With a config file** (P5 choice B `diagnose-airgap.yaml`, or a file from D5). Set `cfg` to the absolute path of the file:

```bash
# CHANGES  (runs the collectors of the file; writes support-bundle-*.tar.gz in DIAG_DIR)
source ~/nkp-<cluster>.env 2>/dev/null
cfg=''
: "${cfg:?}"
cd "${DIAG_DIR:?}" && nkp diagnose "$cfg" --kubeconfig "$CLUSTER_KUBECONFIG" --bundle-name-prefix "$CLUSTER_NAME"
```

- The guide gives the file as an argument: `nkp diagnose bundle.yaml`. [pdf p.1051] The 2.19.0 help shows only `nkp diagnose [flags]`. [live 2.19.0]
- UNKNOWN (A-22): whether `nkp diagnose` 2.19.0 reads a config file given as an argument. Find out with: `nkp diagnose --help`; after a block B run, the `tar -tzf` list in D3 shows the collector names of the file.
- Run it once for each cluster that has the problem. For a workload cluster problem, also run it on the management cluster with `--kubeconfig "$MGMT_KUBECONFIG"` (the CAPI objects and controller logs are there).
- `--since 6h` limits the pod logs to the last 6 hours. [live 2.19.0] Use it when the bundle is too large. Without it, the guide says the bundle has 48 h. [pdf p.1049]

Done when: the output names a `.tar.gz` file and D3 finds no error files.

## D2. Bootstrap cluster (before the pivot)

Add the bootstrap kubeconfig. NKP makes a second file `bootstrap-support-bundle-<date>.tar.gz` with cluster info, resources, all logs, ConfigMaps, and Secret metadata. [pdf p.1050-1051] If the new cluster does not answer yet, use the bootstrap file as `--kubeconfig` too.

```bash
# CHANGES  (writes support-bundle-*.tar.gz and bootstrap-support-bundle-*.tar.gz in DIAG_DIR)
source ~/nkp-site.env 2>/dev/null
cd "${DIAG_DIR:?}" && nkp diagnose --kubeconfig "$BOOTSTRAP_KUBECONFIG" --bootstrap-kubeconfig "$BOOTSTRAP_KUBECONFIG"
```

When the new cluster answers, replace the first `--kubeconfig` with the kubeconfig of the new cluster (skill `nkp-install`, step "Set the kubeconfig variables"). Run this before `nkp delete bootstrap`.

## D3. Check the bundle

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
cd "${DIAG_DIR:?}" && ls -lt ./*support-bundle-*.tar.gz | head -3
f="$(ls -t "$DIAG_DIR"/*support-bundle-*.tar.gz | head -1)"; tar -tzf "$f" | awk -F/ '{print $2}' | sort | uniq -c
tar -tzf "$f" | grep -E 'error\.txt$|pod-collector\.(json|log)$'
```

- Expected folders: `cluster-info`, `cluster-resources`, `configmaps`, `node-diagnostics`, `pod-logs`, `secrets`, and `version.yaml`. [pdf p.1050]
- No `node-diagnostics`, or `node-diagnostics/<node>/pod-collector.log` and `*-error.txt` files: the node collection failed. [pdf p.1054] (A run without the node collector, D1, has no `node-diagnostics`. That is correct.) Read only those files with `tar -xzOf "$f" <path>`. `ImagePullBackOff` or a pull error: D1 "Air-gapped site". `timeout`: raise `timeout` in a config file (D5).

Done when: the folders are there. Give the user the file path. The user sends the file to Nutanix support.

## D4. API server down: SSH fallback

`nkp diagnose ssh` collects node data over SSH when the Kubernetes API does not answer. [pdf p.1051] Only these inventory keys work: `ansible_host`, `ansible_port`, `ansible_user`, `ansible_ssh_private_key_file`, in the `all` group `vars` and `hosts`. [pdf p.1052] The default per-node timeout is 5m (`--timeout`). [live 2.19.0]

Read the node IPs with skill `nutanix-vm`, RECIPES.md "NKP VM audit: the VMs of one cluster" (If that skill is not installed, the user does it in Prism Central), the SSH user (`konvoy` on AHV [live 2.19.0]), and the private key file of `SSH_PUBKEY_FILE`. Write the inventory (one `hostN` line pair per node; fill the values before you run):

```bash
# CHANGES  (writes the SSH inventory file on the operator host)
source ~/nkp-site.env 2>/dev/null
user='konvoy'; key=''; h1=''; h2=''; h3=''
: "${key:?}" "${h1:?}" "${DIAG_INVENTORY:?}"
(umask 077 && { printf 'all:\n  vars:\n    ansible_user: %s\n    ansible_ssh_private_key_file: %s\n  hosts:\n' "$user" "$key"; n=0; for h in "$h1" "$h2" "$h3"; do [ -n "$h" ] && n=$((n+1)) && printf '    host-%s:\n      ansible_host: %s\n' "$n" "$h"; done; } > "$DIAG_INVENTORY")
cat "$DIAG_INVENTORY"
```

Add more `hN` values for more nodes. Then, after "yes":

```bash
# CHANGES  (connects to each node over SSH, runs the collector script, writes a bundle in DIAG_DIR)
source ~/nkp-site.env 2>/dev/null
cd "${DIAG_DIR:?}" && nkp diagnose ssh "$DIAG_INVENTORY"
```

The bundle has `node-diagnostics/<host>_<port>/data/`. [pdf p.1052] If SSH is not set up on the nodes, this does not work. Then the user collects logs from the Prism Central VM console.

## D5. Change the collectors

Write the default config to a file, change it, and run it with D1 block B. [pdf p.1051]

```bash
# CHANGES  (writes diagnose-config.yaml in DIAG_DIR)
source ~/nkp-site.env 2>/dev/null
cd "${DIAG_DIR:?}" && nkp diagnose default-config > diagnose-config.yaml && grep -n -E 'image:|pauseImage:|timeout:|namespaces:' diagnose-config.yaml
```

Useful changes (one at a time, with `sed`, and show the diff in the plan):
- `timeout: 600s` → a higher value, or `0` for no limit. [pdf p.1054]
- `allLogs` `namespaces: ['*']` → a list of namespaces, to make the bundle smaller. [pdf p.1055]
- Remove the `configMap` collector when the user does not want ConfigMap data in the bundle. Nutanix support can then ask for more data.
