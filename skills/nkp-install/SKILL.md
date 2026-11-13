---
name: nkp-install
description: >
  Install NKP: create the first (management) cluster or a new workload cluster with nkp create cluster,
  bootstrap and pivot, nkp install kommander, operator host prerequisites, the site and cluster env files.
  Providers: Nutanix AHV, NKP Metal, pre-provisioned hosts, AWS, EKS, Azure, AKS, GCP, vSphere.
metadata:
  nkp_versions: "2.19"
  last_verified: "2026-11-02"
  sources: "live 2.19.0, pdf 2.19"
---

# NKP install

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

Do the steps in order. Start a step only after the "Done when" check of the step before it passes.

## Step: Choose the provider file

Ask the user these questions:
1. Which infrastructure does the cluster run on?
2. Is this the first cluster (a management cluster), or a workload cluster for an existing management cluster?
3. Is the site connected or air-gapped? Does the site have its own registry mirror?
4. Which license tier does the site have? Starter supports only Nutanix AHV. [pdf p.26-28] The tier selects the node size flags (Nutanix: N1 "Node size").
5. Management cluster with Pro or Ultimate: which cluster name is in the license? The key works only on a management cluster with that name. Else the license step fails with `License key is not valid for this cluster`, and you must delete and create the cluster again. Use that name as `CLUSTER_NAME`. [live 2.19.0] Stop after the questions: show no env file block in the same reply (rule 4).

Then load the provider file:

| Infrastructure | Provider file |
|---|---|
| Nutanix AHV with Prism Central (VMs) | [references/nutanix.md](references/nutanix.md) |
| NKP Metal: physical servers imaged by Foundation Central (workload cluster only, Pro or Ultimate) | [references/metal.md](references/metal.md) |
| Pre-provisioned hosts: existing machines that NKP configures over SSH | [references/preprovisioned.md](references/preprovisioned.md) |
| AWS, EKS, Azure, AKS, GCP, vSphere | [references/cloud.md](references/cloud.md) |

The provider file replaces the Nutanix section names in the steps below (N1, N2, N6) with its own sections. Done when: you have the answers and the provider file is loaded.

## Step: Check the operator host

The operator host (bastion) runs `nkp`, a container engine, and the kind bootstrap cluster. The agent runs on the operator host: every block runs there, and the env files and kubeconfig files are there. Requirements:

- x86_64 Linux or macOS. On Linux, cgroups v2 must be on. [pdf p.48]
- Docker 27.4.0, or Podman 4.0 or later (Linux only). [pdf p.48]
- kubectl: the guide asks for 1.36.x [pdf p.50]. The 2.19.0 bundle has kubectl v1.37.2 [live 2.19.0]. A client one minor version newer than the cluster is in the Kubernetes skew policy.
- 4 CPU and 4 GB memory free for the bootstrap cluster. [pdf p.718]
- Network access to the infrastructure API (Prism Central port 9440) and to the registry.
- The operator host is in the same network and proxy domain as the new cluster. [pdf p.666]
- bash and tmux are installed. All blocks run with bash. A long create runs in tmux, so that a lost terminal does not stop it. If tmux is not installed, ask the user to install it.

```bash
# READ-ONLY
nkp version
docker version --format '{{.Server.Version}}'
kubectl version --client
stat -fc %T /sys/fs/cgroup
tmux -V
nproc; free -g; df -h "${TMPDIR:-/tmp}"
```

- `nkp version`: the `nkp` line must show the target NKP version. If it does not, use the `nkp` binary from the bundle (`cli/nkp` in the bundle folder). [live 2.19.0]
- `stat` and `free` work only on Linux. On macOS, ask the user for the free CPU and memory.
- The create and `nkp push bundle` write large temporary files. If a command fails with "no space left on device", ask the user for a folder with more free space. Append it as `TMPDIR` to `~/nkp-site.env` (rule 4). [pdf p.694]
- Air-gapped site: the user extracts the bundle on the operator host first. For the bundle and the registry, use skill `nkp-airgap`.
- Before a create on a site that had an NKP cluster: an old cluster can leave volume groups and floating IPs in Prism Central [live 2.19.0]. Run skill `nutanix-nkp`, RECIPES.md "Site preflight", and "Leftover audit for a cluster" with the old cluster name. If skill `nutanix-nkp` is not installed, the user does it in Prism Central. To remove leftovers, use skill `nkp-cluster-lifecycle` (plan and "yes" first).

Done when: the versions meet the requirements, `stat` prints `cgroup2fs` (Linux), the CPU and memory are free, and no leftover of an old cluster uses the new IPs or the new name.

## Step: Prepare the env files

Rules 3 to 5 describe the two env files.

1. Make the site env file if it does not exist:

```bash
# CHANGES  (makes ~/nkp-site.env with mode 600 if it does not exist)
test -e ~/nkp-site.env || { touch ~/nkp-site.env && chmod 600 ~/nkp-site.env; }
```

2. Ask the user for the cluster name. Make the cluster env file. Replace `<cluster>` with the cluster name before you run the block.

```bash
# CHANGES  (makes the cluster env file with mode 600 if it does not exist)
test -e ~/nkp-<cluster>.env || { (umask 077 && echo 'source ~/nkp-site.env 2>/dev/null' > ~/nkp-<cluster>.env); }
```

3. Ask the user for each value that the provider file lists (Nutanix: section N1). Append each known value to the file that the rules table names (rule 4). For a management cluster, also append `WORKSPACE_NS='kommander'` to the cluster env file. [live 2.19.0]
4. Give the user this block for the secrets. The provider file lists the secret lines for each case. Each line has this form: `export NUTANIX_PASSWORD='the-password'`. If a value has a single quote, the user writes it as `'\''`.

```bash
# USER-TERMINAL  (the user adds the secret lines with an editor)
vi ~/nkp-site.env
```

Done when: the check in the provider file (Nutanix: section N2) prints `set:` for each name in the list.

## Step: Create the cluster

Follow the provider file. It writes one create script for each cluster. The dry run and the real create run the same script.

How the create works: `nkp` makes a kind bootstrap cluster on the operator host. The bootstrap cluster creates the new cluster. Then `nkp` moves the CAPI objects to the new cluster (the pivot) and deletes the bootstrap cluster. [pdf p.22-23]

The flag `--self-managed` does all of this in one command. Use it for a management cluster. A workload cluster does not use `--self-managed`. The management cluster creates it with `--kubeconfig "$MGMT_KUBECONFIG"`.

General rules:
- Cluster names use only `a-z`, `0-9`, `.`, and `-`.
- NKP runs preflight checks before it creates anything. When a check fails, read the `Flag:` line. Fix the value of that flag. Run the create again. [pdf p.725] Use `--skip-preflight-checks=<check name>` only when the user confirms that the check itself is wrong. Never use `all`. [pdf p.726]
- You cannot change the pod CIDR or the service CIDR after the create. [pdf p.724] You cannot change FIPS mode after the create. [pdf p.988]

Done when: the create script ends without an error. The provider file gives the check.

## Step: Set the kubeconfig variables

A kubeconfig file holds credentials. Never print it. **Management cluster.** `--self-managed` writes `$PWD/<cluster>.conf` (mode 600) in the folder of the create and prints the path. The file is final about 17 min before the create ends. [live 2.19.0] Run this block in the folder of the create. On Nutanix, the create plan (N4D) includes this block: run it after `RC=0` with no new approval.

```bash
# CHANGES  (appends MGMT_KUBECONFIG to the site env file and CLUSTER_KUBECONFIG to the cluster env file)
source ~/nkp-<cluster>.env 2>/dev/null
test -f "$PWD/$CLUSTER_NAME.conf" && echo "export MGMT_KUBECONFIG='$PWD/$CLUSTER_NAME.conf'" >> ~/nkp-site.env && echo "export CLUSTER_KUBECONFIG='$PWD/$CLUSTER_NAME.conf'" >> ~/nkp-<cluster>.env || echo "no file: $PWD/$CLUSTER_NAME.conf"
```

If `test -f` fails, read the path in the last lines of the create output. If the output gives no path (vSphere, pre-provisioned hosts), get the file with this block in the folder of the create [pdf p.82, p.842], then run the append block again:

```bash
# CHANGES  (writes the kubeconfig file of the new cluster in this folder)
source ~/nkp-<cluster>.env 2>/dev/null
umask 077 && nkp get kubeconfig --cluster-name "$CLUSTER_NAME" > "$PWD/$CLUSTER_NAME.conf"
```

**Workload cluster.** The create writes no kubeconfig file and prints no success line. It ends at `✓ Waiting for machines to be ready`. This is normal. [live 2.19.0] So this block is mandatory. It writes a local file, and the help says that it can change the local kubeconfig [live 2.19.0], so it is CHANGES. On Nutanix, the create plan (N4D) includes it.

```bash
# CHANGES  (writes a local kubeconfig file and appends its path to the cluster env file)
source ~/nkp-<cluster>.env 2>/dev/null
umask 077 && nkp get kubeconfig --cluster-name "$CLUSTER_NAME" --namespace "$WORKSPACE_NS" --kubeconfig "$MGMT_KUBECONFIG" > "$PWD/$CLUSTER_NAME.conf" && echo "export CLUSTER_KUBECONFIG='$PWD/$CLUSTER_NAME.conf'" >> ~/nkp-<cluster>.env
```

An old `MGMT_KUBECONFIG` line can point to a deleted file. The last line wins (rule 4), so the `test -f` check below proves the new value. Done when this block prints `mgmt kubeconfig ok` and the nodes of the new cluster:

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
test -f "$MGMT_KUBECONFIG" && echo "mgmt kubeconfig ok"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get nodes
```

## Step: Check or install Kommander

Management cluster only. On Nutanix AHV, `nkp create cluster nutanix --self-managed` installs Kommander. [pdf p.47] Always check first:

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" get ns kommander-flux
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n kommander get helmreleases
kubectl --kubeconfig "$MGMT_KUBECONFIG" get storageclass
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n kommander wait --for condition=Ready helmreleases --all --timeout 15m
```

If `kommander-flux` does not exist or there are no HelmReleases, follow [references/kommander.md](references/kommander.md).

Done when: the HelmRelease wait prints "condition met" for each object.

## Step: Verify

`WORKSPACE_NS` is `kommander` for the management cluster and the workspace namespace for a workload cluster.

```bash
# READ-ONLY  (every cluster)
source ~/nkp-<cluster>.env 2>/dev/null
nkp describe cluster --cluster-name "$CLUSTER_NAME" --namespace "$WORKSPACE_NS" --kubeconfig "$MGMT_KUBECONFIG"
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get nkpclusters
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get nodes
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get pods -A --field-selector=status.phase!=Running,status.phase!=Succeeded
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" wait --for=condition=Ready pods -A --field-selector=status.phase=Running --timeout=10m
```

Workload cluster: also run this block. Its platform apps are HelmReleases in `$WORKSPACE_NS` on the workload cluster. A workload cluster has no `kommander` namespace. [live 2.19.0]

```bash
# READ-ONLY  (workload cluster)
source ~/nkp-<cluster>.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get kommanderclusters "$CLUSTER_NAME"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" wait --for=condition=Ready helmreleases -A --all --timeout 45m
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get helmreleases -A --no-headers | wc -l
```

Done when all these are true:
- In `nkp describe cluster`, every `Machine/` row shows READY `True`. The `Cluster/` and `ControlPlane` rows can have an empty READY column. [live 2.19.0]
- The NKPCluster PHASE is `Reconciled`. A workload cluster shows `Reconciling Platform Applications` first. `Reconciled` can come 30–40 min after the create ends. This is normal. [live 2.19.0]
- All nodes are `Ready`. The `--field-selector` pod list prints nothing: expect no output (the "No resources found" line goes to stderr). [live 2.19.0]
- Each wait prints "condition met" for each object. Workload: the KommanderCluster STATUS is `Joined`. [live 2.19.0]
- The HelmRelease count does not change in two reads 15 min apart. Some apps arrive late, so never use the first count as final. Ultimate, measured: management cluster 48 HelmReleases in `kommander` (Starter 24); workload cluster 19 HelmReleases in `$WORKSPACE_NS`, 16 AppDeployments, about 122 pods. [live 2.19.0]

Then do the provider checks (Nutanix: section N6). Pro or Ultimate: Kommander installs as Starter. Apply the license now: skill `nkp-identity-security`, section "License". [live 2.19.0]

## Step: Give the user the UI access

The dashboard command shows the admin password. Give the user this block (rule 1).

```bash
# USER-TERMINAL
source ~/nkp-site.env 2>/dev/null
nkp get dashboard --kubeconfig "$MGMT_KUBECONFIG"
```

- Use the static admin credentials only to set up an identity provider (skill `nkp-identity-security`). [pdf p.729]
- To change the admin password, run this block after approval. `--yes` skips the CLI prompt. [pdf p.729] Then the user runs `nkp get dashboard` again.

```bash
# CHANGES  (changes the dashboard admin password; old sessions stop)
source ~/nkp-site.env 2>/dev/null
KUBECONFIG="$MGMT_KUBECONFIG" nkp rotate dashboard-credentials --yes
```

Done when: the user confirms that the UI login works.

## If the install fails

1. Read the preflight message. It names the check and the flag. Fix the value. Run the create again. [pdf p.725]
2. Read "Common failures" in the provider file.
3. For any other failure, use skill `nkp-troubleshooting`. It owns `nkp diagnose` (also before the pivot) and the debug ladder.
4. To remove a failed bootstrap cluster (also after a cut-off management dry run):

```bash
# CHANGES  (deletes the kind bootstrap cluster on the operator host)
nkp delete bootstrap
```

## Related skills

Bundle, registry, custom and FIPS images: skill `nkp-airgap`. Change or delete a cluster: skill `nkp-cluster-lifecycle`. Cilium, MetalLB, proxy, MTU: skill `nkp-networking`. Flow VPC: skill `nkp-vpc`. Flow CNI: skill `nkp-flow-cni`.
