# Pilot r3 answers

General notes that apply to every answer below (the operator host login shell is zsh):

- Every block is run **with bash**, not zsh (rule 3). Paste a block into a bash shell (`bash` then paste), or save it and run `bash file`. The exception is a block marked USER-TERMINAL, which you run yourself.
- zsh does not split an unquoted `$VAR` into words and errors on a glob that matches nothing (`no matches found`). So every variable in a block stays quoted as `"$VAR"` exactly as shown, and globs are used inside the scripts only, which run with bash.
- Line 1 of every block is the mark. `# READ-ONLY` runs without approval. `# CHANGES` runs only after you type `yes` to the plan I show above it. `# USER-TERMINAL` shows a secret; you run it, I do not.
- Before a block, I replace `<cluster>` in `~/nkp-<cluster>.env` with the cluster name (rule 3).

---

## nkp-install E1

Skill files read for this answer: `skills/nkp/SKILL.md`, `skills/nkp-install/SKILL.md`, `skills/nkp-install/references/nutanix.md`.

### Reply

Bastion with the extracted bundle, no registry, dark site, first cluster on AHV: this is case **N4B** in `references/nutanix.md` (air-gapped, no site registry; NKP pushes the bundle images into a registry inside the new cluster with `--bundle`). No site mirror and no seeding, so nothing from `nkp-airgap` is needed.

Values I already have from your message:

| Variable | Value |
|---|---|
| `PC_ENDPOINT` | `https://pc.example.local:9440` |
| `PE_CLUSTER` | `PE01` |
| `SUBNET` | `k8s-vlan` |
| `STORAGE_CONTAINER` | `default-container` |
| `VM_IMAGE` | `nkp-rocky-9.8-release-1.36.2` |
| `BUNDLE_DIR` | `/opt/nkp-v2.19.0` |

**Values I still need before I can write the create script** (I do not write empty values, rule 4):

1. `CLUSTER_NAME` — only `a-z`, `0-9`, `.`, `-` [pdf p.718]. This one blocks everything, because the create script path and the kubeconfig name use it.
2. `CP_VIP` — one static IP in the `k8s-vlan` CIDR, **outside** the DHCP/IPAM pool, used by no other host [pdf p.720].
3. `LB_IP_RANGE` — `<first-ip>-<last-ip>`, same Layer 2 subnet as the workers, outside the pool. The NKP UI takes the first IP [pdf p.694, p.721].
4. `SSH_PUBKEY_FILE` — the public key file on the bastion. NKP adds this key for user `konvoy` on every node [live 2.19.0].
5. `NTP_SERVERS` — comma-separated. **Mandatory on an air-gapped site** [pdf p.724].
6. `NUTANIX_USER` and `NUTANIX_PASSWORD` — you type these into the env file yourself (rule 5).
7. Two optional ones: does Prism Central use a self-signed certificate (`PC_CA_FILE`), and is `PC_PROJECT` needed? `PC_PROJECT` cannot be changed later [pdf p.1016].
8. License tier, and node sizes: Starter (AHV only) or Pro/Ultimate? CLI defaults are 3 control-plane nodes at 4 vCPU/16 GiB and 4 workers at 8 vCPU/32 GiB [live 2.19.0], which are the Pro and Ultimate minimums. For Starter I add `--control-plane-vcpus 2 --control-plane-memory 8 --worker-replicas 2 --worker-vcpus 4 --worker-memory 8` [pdf p.695].

#### Step 1 — operator host check (no approval needed, READ-ONLY)

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
nkp version
docker version --format '{{.Server.Version}}'
kubectl version --client
stat -fc %T /sys/fs/cgroup
nproc; free -g; df -h "${TMPDIR:-/tmp}"
ls /opt/nkp-v2.19.0
ls /opt/nkp-v2.19.0/container-images
```

What I check in the output: the `nkp` line is 2.19.0 (if it is not, I use `/opt/nkp-v2.19.0/cli/nkp` instead [live 2.19.0]); Docker 27.4.0 or Podman 4.0+ [pdf p.48]; kubectl 1.36.x or the bundle's 1.37.2; `stat` prints `cgroup2fs`; at least 4 CPU and 4 GB memory free [pdf p.718]; free space in `$TMPDIR` (the create writes large temporary files); the bundle folders are readable by my user.

#### Step 2 — record the values (CHANGES, I stop here for your `yes`)

Target: `~/nkp-site.env`. Result: six lines added, nothing else touched.

```bash
# CHANGES  (makes ~/nkp-site.env mode 600 if missing, then appends the six values you gave)
source ~/nkp-site.env 2>/dev/null
test -e ~/nkp-site.env || { touch ~/nkp-site.env && chmod 600 ~/nkp-site.env; }
echo "export PC_ENDPOINT='https://pc.example.local:9440'" >> ~/nkp-site.env
echo "export PE_CLUSTER='PE01'" >> ~/nkp-site.env
echo "export SUBNET='k8s-vlan'" >> ~/nkp-site.env
echo "export STORAGE_CONTAINER='default-container'" >> ~/nkp-site.env
echo "export VM_IMAGE='nkp-rocky-9.8-release-1.36.2'" >> ~/nkp-site.env
echo "export BUNDLE_DIR='/opt/nkp-v2.19.0'" >> ~/nkp-site.env
```

I add the rest (`CLUSTER_NAME`, `CP_VIP`, `LB_IP_RANGE`, `SSH_PUBKEY_FILE`, `NTP_SERVERS`, `WORKSPACE_NS='kommander'`) the same way once you answer items 1–5. `WORKSPACE_NS` is `kommander` for a management cluster [live 2.19.0], and it goes into the cluster env file, not the site file.

#### Step 3 — the secret lines (USER-TERMINAL, you run it, I do not)

```bash
# USER-TERMINAL  (you add the two secret lines with an editor; the file shows on your screen)
vi ~/nkp-site.env
```

Add exactly this form, with your own values:

```
export NUTANIX_USER='...'
export NUTANIX_PASSWORD='...'
```

If a value contains a single quote, write it as `'\''`. Use `vi`, not the zsh command line: in an interactive zsh a `!` in the value can be history-expanded, and every line you type goes into `~/.zsh_history`. Do not send the password in chat.

#### Step 4 — check the env files (READ-ONLY)

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
bash -n ~/nkp-site.env 2>/dev/null && bash -n ~/nkp-<cluster>.env 2>/dev/null && echo "set: syntax" || echo "MISSING: syntax"
for v in CLUSTER_NAME CP_VIP LB_IP_RANGE WORKSPACE_NS PC_ENDPOINT PE_CLUSTER SUBNET STORAGE_CONTAINER VM_IMAGE SSH_PUBKEY_FILE NUTANIX_USER NUTANIX_PASSWORD; do if [ -n "$(printenv "$v")" ]; then echo "set: $v"; else echo "MISSING: $v"; fi; done
```

```bash
# READ-ONLY  (case 4B)
source ~/nkp-<cluster>.env 2>/dev/null
for v in NTP_SERVERS BUNDLE_DIR; do if [ -n "$(printenv "$v")" ]; then echo "set: $v"; else echo "MISSING: $v"; fi; done
```

Done when the first block prints `set: syntax` and `set: <name>` for all twelve names, and the second prints `set: NTP_SERVERS` and `set: BUNDLE_DIR`.

#### Step 5 — check the infrastructure (READ-ONLY)

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
curl -sk -o /dev/null -w '%{http_code}\n' "$PC_ENDPOINT"
ping -c 2 "$CP_VIP"
test -f "$SSH_PUBKEY_FILE" && echo "ssh key file found"
```

What I check: `curl` returns a code that is not `000` (Prism Central answers on 9440); `ping` gets **no reply** (the VIP is free — if ICMP is blocked this proves nothing and I ask you to confirm no host uses it); the key file is found.

#### Step 6 — bundle files and `IMAGE_BUNDLES` (READ-ONLY, then CHANGES)

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
ls "$BUNDLE_DIR"/container-images/ "$BUNDLE_DIR"/konvoy-bootstrap-image-*.tar
nkp create cluster nutanix --help | grep -A3 -- '--bundle '
```

Done when that shows exactly one `konvoy-image-bundle-*.tar`, one `kommander-image-bundle-*.tar`, one `nkp-release-specs-*.tar` and one `konvoy-bootstrap-image-*.tar` [live 2.19.0][pdf p.722-723]. If not, I stop and ask you.

```bash
# CHANGES  (appends IMAGE_BUNDLES to ~/nkp-site.env)
source ~/nkp-site.env 2>/dev/null
b="$BUNDLE_DIR/container-images" && echo "export IMAGE_BUNDLES='$(ls "$b"/konvoy-image-bundle-*.tar),$(ls "$b"/kommander-image-bundle-*.tar),$(ls "$b"/nkp-release-specs-*.tar)'" >> ~/nkp-site.env
```

#### Step 7 — write the create script (CHANGES, nothing is created yet)

Target: `~/nkp-<cluster>-create.sh`, mode 700. This is your command, with the placeholders filled from the env files:

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

For Starter I add this line before `"$@"`:

```
  --control-plane-vcpus 2 --control-plane-memory 8 --worker-replicas 2 --worker-vcpus 4 --worker-memory 8 \
```

Two things I tell you before you approve: with 2 workers the Pro and Ultimate apps fail after a license upgrade [pdf p.695]; and the dry run and the real create both run this one script (the dry run adds `--dry-run --output yaml` at the end).

#### Step 8 — dry run (CHANGES: writes a local file with Secrets in it)

```bash
# CHANGES  (writes the dry-run objects to a local file; creates no cluster)
source ~/nkp-<cluster>.env 2>/dev/null
umask 077 && bash "$HOME/nkp-$CLUSTER_NAME-create.sh" --dry-run --output yaml > "$PWD/$CLUSTER_NAME-dryrun.yaml"
```

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
grep -n -E '^kind:|^  name:|image:|host:|addressRanges|start:|end:|url:' "$PWD/$CLUSTER_NAME-dryrun.yaml"
```

I never print the file itself and never `kubectl apply` it [pdf p.729]. I show you the grepped lines and you check: cluster name, `PC_ENDPOINT`, the `CP_VIP`, the load-balancer `addressRanges` start/end, `PE_CLUSTER`, `SUBNET`, `default-container`, and the image name. Done when the dry run ends without an error and you agree with those lines.

#### Step 9 — create (CHANGES)

Target: a kind bootstrap cluster on the bastion, then 3 control-plane and 4 worker VMs (or the Starter sizes) in `PE01`, then the pivot and Kommander. This is the expensive one; I stop here again for a second `yes`.

```bash
# CHANGES  (creates the cluster: kind bootstrap cluster, VMs in Prism Central, pivot, Kommander)
source ~/nkp-<cluster>.env 2>/dev/null
bash "$HOME/nkp-$CLUSTER_NAME-create.sh"
```

`--self-managed` waits until the cluster is ready and the pivot is done [live 2.19.0]. Done when it ends without an error.

If a preflight check fails, I read the `Flag:` line and fix that value, then run again [pdf p.725]. I use `--skip-preflight-checks=<name>` only if you confirm the check is wrong, never `all` [pdf p.726].

#### Step 10 — kubeconfig (READ-ONLY, then CHANGES)

UNKNOWN (A-05): where `nkp create cluster ... --self-managed` writes the management kubeconfig. Find out with: `ls -l ./*.conf`.

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
ls -l "./$CLUSTER_NAME.conf"
```

```bash
# CHANGES  (appends MGMT_KUBECONFIG to the site env file and CLUSTER_KUBECONFIG to the cluster env file)
source ~/nkp-<cluster>.env 2>/dev/null
echo "export MGMT_KUBECONFIG='$PWD/$CLUSTER_NAME.conf'" >> ~/nkp-site.env && echo "export CLUSTER_KUBECONFIG='$PWD/$CLUSTER_NAME.conf'" >> ~/nkp-<cluster>.env
```

Then the "Verify" step (nodes Ready, NKPCluster `Reconciled`, HelmRelease wait, `nutanix-volume` as the default StorageClass, `kommander-traefik` external IP = first IP of `LB_IP_RANGE`), and last `nkp get dashboard` for you to run yourself, because it prints the admin password.

**Where I stop:** right here, after Step 1 and your answers to items 1–5. Nothing is created, and no file is changed, until you type `yes` to each CHANGES plan above.

---

## nkp-install E4

Skill files read for this answer: `skills/nkp/SKILL.md`, `skills/nkp-install/SKILL.md`, `skills/nkp-install/references/nutanix.md`.

### Reply

Management cluster up, so `dev-01` is a workload cluster: case **N5** in `references/nutanix.md`. It does **not** use `--self-managed`. The management cluster creates it with `--kubeconfig "$MGMT_KUBECONFIG"` and puts it in a workspace namespace. `WORKSPACE_NS` is not `kommander`; that namespace is for the management cluster only [live 2.19.0].

Values I have: `CLUSTER_NAME=dev-01`, `MGMT_KUBECONFIG=$HOME/mgmt.conf`, the default workspace, the same Prism Central and the same `k8s-vlan` subnet (so `PC_ENDPOINT`, `PE_CLUSTER`, `SUBNET`, `STORAGE_CONTAINER`, `VM_IMAGE` come from `~/nkp-site.env`), and a seeded Harbor mirror.

**Values I still need** (I do not write empty values):

1. `REGISTRY_URL` — the mirror the nodes pull from, for example `https://<registry-host>/<project>`. "Our harbor is seeded" does not tell me the URL.
2. `REGISTRY_CA_FILE` — the CA file of that registry.
3. `CP_VIP` for `dev-01` — its own IP, in the subnet CIDR, outside the DHCP/IPAM pool. Each cluster needs its own [pdf p.693-694].
4. `LB_IP_RANGE` for `dev-01` — its own range, on the same Layer 2 subnet as the workers, outside the pool.
5. `NTP_SERVERS` on the air-gapped site (mandatory) [pdf p.724] — if it is already in `~/nkp-site.env` I reuse it.
6. `REGISTRY_MIRROR_USERNAME` / `REGISTRY_MIRROR_PASSWORD` — if Harbor allows anonymous pulls, the lines exist with `''`; if not, you type them into `~/nkp-site.env` with `vi` (USER-TERMINAL, rule 5).
7. Node sizes: CLI default 3 control-plane + 4 workers, or the Starter workload minimum `--control-plane-vcpus 2 --control-plane-memory 6 --worker-replicas 2 --worker-vcpus 3 --worker-memory 6` [pdf p.695-696]?

#### Step 1 — find the workspace namespaces and the mirror of the management cluster (READ-ONLY)

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" get workspaces -A
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n kommander get nkpclusters -o jsonpath='{.items[*].spec.kommanderCluster.spec.ociRegistry.mirrorURL}{"\n"}'
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n kommander get nkpclusters
nkp version
```

What I check: the default workspace namespace is `kommander-default-workspace` [pdf p.489, p.733]; the second command prints the site mirror URL of the management cluster [live 2.19.0] — an **empty line** means the management cluster has no site mirror, and then I stop and ask you. That printed URL must match the `REGISTRY_URL` you give me. The management cluster phase is `Reconciled`.

If `~/nkp-site.env` does not yet hold `MGMT_KUBECONFIG`, this is the CHANGES block that fixes it (I stop for `yes`):

```bash
# CHANGES  (appends MGMT_KUBECONFIG to ~/nkp-site.env)
source ~/nkp-site.env 2>/dev/null
echo "export MGMT_KUBECONFIG='$HOME/mgmt.conf'" >> ~/nkp-site.env
```

#### Step 2 — new cluster env file (CHANGES, stop for `yes`)

Target: `~/nkp-dev-01.env`, mode 600. It sources the site env file, so the management cluster values stay in `~/nkp-site.env` and this file only holds the `dev-01` values [live 2.19.0].

```bash
# CHANGES  (makes ~/nkp-dev-01.env and appends this cluster's values)
test -e ~/nkp-dev-01.env || { (umask 077 && echo 'source ~/nkp-site.env 2>/dev/null' > ~/nkp-dev-01.env); }
echo "export CLUSTER_NAME='dev-01'" >> ~/nkp-dev-01.env
echo "export WORKSPACE_NS='kommander-default-workspace'" >> ~/nkp-dev-01.env
echo "export CP_VIP='<the-ip-you-give-me>'" >> ~/nkp-dev-01.env
echo "export LB_IP_RANGE='<first-ip>-<last-ip>'" >> ~/nkp-dev-01.env
```

`REGISTRY_URL`, `REGISTRY_CA_FILE` and `NTP_SERVERS` go into `~/nkp-site.env` (they are site values, same block form as E1).

#### Step 3 — check both env files (READ-ONLY)

```bash
# READ-ONLY  (every case, then case 5 mirror air-gapped)
source ~/nkp-dev-01.env 2>/dev/null
bash -n ~/nkp-site.env 2>/dev/null && bash -n ~/nkp-dev-01.env 2>/dev/null && echo "set: syntax" || echo "MISSING: syntax"
for v in CLUSTER_NAME CP_VIP LB_IP_RANGE WORKSPACE_NS PC_ENDPOINT PE_CLUSTER SUBNET STORAGE_CONTAINER VM_IMAGE SSH_PUBKEY_FILE NUTANIX_USER NUTANIX_PASSWORD; do if [ -n "$(printenv "$v")" ]; then echo "set: $v"; else echo "MISSING: $v"; fi; done
for v in MGMT_KUBECONFIG REGISTRY_URL REGISTRY_CA_FILE NTP_SERVERS; do if [ -n "$(printenv "$v")" ]; then echo "set: $v"; else echo "MISSING: $v"; fi; done
for v in REGISTRY_MIRROR_USERNAME REGISTRY_MIRROR_PASSWORD; do printenv "$v" >/dev/null && echo "set: $v" || echo "MISSING: $v"; done
```

Also the VIP must be free — the workload cluster has no VIP ping of its own in the skill, so `ping -c 2 "$CP_VIP"` must get no reply.

Done when every list prints `set:` lines and `set: syntax`.

#### Step 4 — write the create script (CHANGES, nothing is created yet)

```bash
# CHANGES  (writes the create script of this cluster; creates nothing yet)
source ~/nkp-dev-01.env 2>/dev/null
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

`--airgapped` stays. The two mirror flags appear only because `REGISTRY_URL` has a value; with an empty `REGISTRY_URL` the script adds no mirror flag and the workload cluster uses the management cluster's credentials. The mirror password goes in as a flag, so other users on the bastion can see it in the process list [live 2.19.0] — tell me if that is not acceptable and we use an anonymous pull path instead.

#### Step 5 — dry run, then create (CHANGES, stop for `yes` twice)

```bash
# CHANGES  (writes the dry-run objects to a local file; creates no cluster)
source ~/nkp-dev-01.env 2>/dev/null
umask 077 && bash "$HOME/nkp-$CLUSTER_NAME-create.sh" --dry-run --output yaml > "$PWD/$CLUSTER_NAME-dryrun.yaml"
```

```bash
# READ-ONLY
source ~/nkp-dev-01.env 2>/dev/null
grep -n -E '^kind:|^  name:|image:|host:|addressRanges|start:|end:|url:' "$PWD/$CLUSTER_NAME-dryrun.yaml"
```

I check the namespace (`kommander-default-workspace`), the `dev-01` VIP, the load-balancer range, the Harbor URL, and that no line repeats a management-cluster IP. Then:

```bash
# CHANGES  (the management cluster creates dev-01: VMs in Prism Central, then the cluster)
source ~/nkp-dev-01.env 2>/dev/null
bash "$HOME/nkp-$CLUSTER_NAME-create.sh"
```

#### Step 6 — kubeconfig and verify (CHANGES, then READ-ONLY)

`nkp get kubeconfig` writes a local file and can change the local kubeconfig, so it is a CHANGES command [live 2.19.0]. I never print a kubeconfig.

```bash
# CHANGES  (writes ~/dev-01.conf with mode 600 and appends CLUSTER_KUBECONFIG)
source ~/nkp-dev-01.env 2>/dev/null
umask 077 && nkp get kubeconfig --cluster-name "$CLUSTER_NAME" --namespace "$WORKSPACE_NS" --kubeconfig "$MGMT_KUBECONFIG" > "$PWD/$CLUSTER_NAME.conf" && echo "export CLUSTER_KUBECONFIG='$PWD/$CLUSTER_NAME.conf'" >> ~/nkp-dev-01.env
```

```bash
# READ-ONLY
source ~/nkp-dev-01.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get nodes
nkp describe cluster --cluster-name "$CLUSTER_NAME" --namespace "$WORKSPACE_NS" --kubeconfig "$MGMT_KUBECONFIG"
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get nkpclusters
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n kommander wait --for condition=Ready helmreleases --all --timeout 15m
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get storageclass
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n metallb-system get ipaddresspools
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n ntnx-system get pods
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n kube-system get pods -l k8s-app=cilium
```

Done when: every `Machine/` row in `nkp describe cluster` shows READY `True`, the NKPCluster PHASE is `Reconciled` [live 2.19.0], all nodes are `Ready`, `nutanix-volume` is the `(default)` StorageClass, one IPAddressPool exists, and all `ntnx-system` and Cilium pods are Running and ready.

**Where I stop:** after Step 1 and your answers to items 1–7. Nothing is written and nothing is created until you type `yes` to each CHANGES plan.

---

## nkp-install E7

Skill files read for this answer: `skills/nkp/SKILL.md`, `skills/nkp-install/SKILL.md`, `skills/nkp-install/references/nutanix.md`.

### Reply

Air-gapped site with a seeded Harbor mirror, management cluster: case **N4C** in `references/nutanix.md` (site registry mirror, `--registry-mirror-*`). I use **one** registry method only: the mirror flags, not `--bundle` [pdf p.725].

Values I have: `REGISTRY_URL=https://registry.example.local/nkp`, `REGISTRY_CA_FILE=/etc/pki/harbor-ca.crt`, air-gapped.

**Values I still need:**

1. `BUNDLE_DIR` — N4C still needs `--bootstrap-cluster-image` from the extracted bundle. Where is the 2.19.0 bundle on the bastion?
2. `CLUSTER_NAME`, `CP_VIP`, `LB_IP_RANGE`, `SSH_PUBKEY_FILE`, `NTP_SERVERS` (mandatory air-gapped) [pdf p.724].
3. `PC_ENDPOINT` (`https://<host>:9440`), `PE_CLUSTER`, `SUBNET`, `STORAGE_CONTAINER`, `VM_IMAGE` — or, if they are already in `~/nkp-site.env`, I reuse them.
4. `REGISTRY_MIRROR_USERNAME` / `REGISTRY_MIRROR_PASSWORD` — you type them into `~/nkp-site.env` with `vi` if Harbor needs a login; if it allows anonymous pulls, the lines hold `''`.
5. `NUTANIX_USER` / `NUTANIX_PASSWORD` — the same USER-TERMINAL editor step.
6. Whether Prism Central has a self-signed certificate (`PC_CA_FILE`), and the license tier and node sizes.

One thing I cannot do: **checking that Harbor is really seeded** is the `nkp-airgap` skill's job, and that skill is not installed here. So I give you a read-only connectivity check labeled "(not from a skill)":

```bash
# READ-ONLY  (not from a skill)
source ~/nkp-site.env 2>/dev/null
curl -s -o /dev/null -w 'registry: %{http_code}\n' --cacert "$REGISTRY_CA_FILE" "$REGISTRY_URL"/v2/
test -f "$REGISTRY_CA_FILE" && echo "ca file found"
```

A `200` or `401` means the registry answers (401 = it wants a login). It does **not** prove the images are there. Also, the operator host **and** every node subnet must reach the registry [pdf p.713]; if the create later shows `ImagePullBackOff`, the usual cause is that the node subnet cannot reach Harbor or Harbor is not seeded.

#### Step 1 — operator host check (READ-ONLY)

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
nkp version
docker version --format '{{.Server.Version}}'
kubectl version --client
stat -fc %T /sys/fs/cgroup
nproc; free -g; df -h "${TMPDIR:-/tmp}"
```

Same checks as E1: `nkp` 2.19.0, Docker 27.4.0 or Podman 4.0+, `cgroup2fs`, 4 CPU and 4 GB free [pdf p.48, p.718].

#### Step 2 — record the values (CHANGES, stop for `yes`)

Target `~/nkp-site.env`; result: the mirror and site values are added, nothing else.

```bash
# CHANGES  (makes ~/nkp-site.env mode 600 if missing, then appends the known values)
source ~/nkp-site.env 2>/dev/null
test -e ~/nkp-site.env || { touch ~/nkp-site.env && chmod 600 ~/nkp-site.env; }
echo "export REGISTRY_URL='https://registry.example.local/nkp'" >> ~/nkp-site.env
echo "export REGISTRY_CA_FILE='/etc/pki/harbor-ca.crt'" >> ~/nkp-site.env
```

The other five known site values (`PC_ENDPOINT`, `PE_CLUSTER`, `SUBNET`, `STORAGE_CONTAINER`, `VM_IMAGE`), plus `CLUSTER_NAME`, `CP_VIP`, `LB_IP_RANGE`, `SSH_PUBKEY_FILE`, `NTP_SERVERS`, `BUNDLE_DIR` and `WORKSPACE_NS='kommander'`, go in the same way from your answers.

#### Step 3 — secrets (USER-TERMINAL, you run it)

```bash
# USER-TERMINAL  (you add the secret lines with an editor; the file shows on your screen)
vi ~/nkp-site.env
```

The lines for this case:

```
export NUTANIX_USER='...'
export NUTANIX_PASSWORD='...'
export REGISTRY_MIRROR_USERNAME='...'
export REGISTRY_MIRROR_PASSWORD='...'
```

Use `vi`, not the zsh command line: an interactive zsh can history-expand a `!`, and every typed line is saved to `~/.zsh_history`. If a value has a single quote, write `'\''`.

#### Step 4 — check the env files (READ-ONLY)

```bash
# READ-ONLY  (case 4C: every case, then NTP_SERVERS BUNDLE_DIR REGISTRY_URL REGISTRY_CA_FILE, then the mirror credentials)
source ~/nkp-<cluster>.env 2>/dev/null
bash -n ~/nkp-site.env 2>/dev/null && bash -n ~/nkp-<cluster>.env 2>/dev/null && echo "set: syntax" || echo "MISSING: syntax"
for v in CLUSTER_NAME CP_VIP LB_IP_RANGE WORKSPACE_NS PC_ENDPOINT PE_CLUSTER SUBNET STORAGE_CONTAINER VM_IMAGE SSH_PUBKEY_FILE NUTANIX_USER NUTANIX_PASSWORD; do if [ -n "$(printenv "$v")" ]; then echo "set: $v"; else echo "MISSING: $v"; fi; done
for v in NTP_SERVERS BUNDLE_DIR REGISTRY_URL REGISTRY_CA_FILE; do if [ -n "$(printenv "$v")" ]; then echo "set: $v"; else echo "MISSING: $v"; fi; done
for v in REGISTRY_MIRROR_USERNAME REGISTRY_MIRROR_PASSWORD; do printenv "$v" >/dev/null && echo "set: $v" || echo "MISSING: $v"; done
```

#### Step 5 — infrastructure check (READ-ONLY)

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
curl -sk -o /dev/null -w 'pc: %{http_code}\n' "$PC_ENDPOINT"
curl -s -o /dev/null -w 'registry: %{http_code}\n' --cacert "$REGISTRY_CA_FILE" "$REGISTRY_URL"/v2/
ping -c 2 "$CP_VIP"
test -f "$SSH_PUBKEY_FILE" && echo "ssh key file found"
ls "$BUNDLE_DIR"/konvoy-bootstrap-image-*.tar
```

What I check: Prism Central answers (code not `000`); the registry answers with the CA you gave (a certificate failure here would fail every node later); `CP_VIP` gets no ping reply (free); the key file and exactly one bootstrap image file are there.

#### Step 6 — write the create script (CHANGES, nothing is created yet)

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
  --ntp-servers "$NTP_SERVERS" \
  ${PC_PROJECT:+--pc-project "$PC_PROJECT"} \
  ${PC_CA_FILE:+--additional-trust-bundle "$(base64 < "$PC_CA_FILE" | tr -d '\n')"} \
  "$@"
EOF
)
```

`--registry-url`, `--registry-username`, `--registry-password` and `--registry-cacert` do **not** make a mirror; they give credentials for one upstream registry [pdf p.723]. So they are not in this script. The mirror password is a flag, so other users on the bastion can see it in the process list [live 2.19.0] — tell me if that is not acceptable.

#### Step 7 — dry run (CHANGES), then create (CHANGES)

```bash
# CHANGES  (writes the dry-run objects to a local file; creates no cluster)
source ~/nkp-<cluster>.env 2>/dev/null
umask 077 && bash "$HOME/nkp-$CLUSTER_NAME-create.sh" --dry-run --output yaml > "$PWD/$CLUSTER_NAME-dryrun.yaml"
```

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
grep -n -E '^kind:|^  name:|image:|host:|addressRanges|start:|end:|url:' "$PWD/$CLUSTER_NAME-dryrun.yaml"
```

I check that every image reference in the dry run points at `registry.example.local/nkp`, and that the VIP, the range, the container and the image name are right. The file holds Secrets: I never print it and never `kubectl apply` it [pdf p.729].

```bash
# CHANGES  (creates the cluster: kind bootstrap cluster, VMs in Prism Central, pivot, Kommander)
source ~/nkp-<cluster>.env 2>/dev/null
bash "$HOME/nkp-$CLUSTER_NAME-create.sh"
```

Then the kubeconfig step and the "Verify" step from E1 (Steps 10 and the verify list), and `--self-managed` installs Kommander on AHV [pdf p.47].

**Where I stop:** after Step 1 and your answers to items 1–6. Nothing is written, pulled, or created until you type `yes` to each CHANGES plan.

---

## nkp-install E10

Skill files read for this answer: `skills/nkp/SKILL.md`, `skills/nkp-install/SKILL.md`, `skills/nkp-install/references/nutanix.md`.

### Reply

I will set up the env file, but **I will not put the password in it, and I will not write it in this chat again** (rule 5). The secret lines are yours to type with an editor.

Two other things about that password, said plainly:

- It is now in this chat and in my session log. **Change it** on Prism Central when you can, then type the new value into the file. Do not paste secrets into chat again.
- Do not type it on the zsh command line either: an interactive zsh history-expands `!`, and every command you type is saved to `~/.zsh_history`. Use `vi`.

#### Step 1 — make the site env file (CHANGES, stop for `yes`)

Target: `~/nkp-site.env`. Result: the file exists with mode 600 if it did not exist; nothing else changes.

```bash
# CHANGES  (makes ~/nkp-site.env with mode 600 if it does not exist)
source ~/nkp-site.env 2>/dev/null
test -e ~/nkp-site.env || { touch ~/nkp-site.env && chmod 600 ~/nkp-site.env; }
ls -l ~/nkp-site.env
```

I check the output shows `-rw-------` for your user.

#### Step 2 — your secret lines (USER-TERMINAL, you run it, I do not)

```bash
# USER-TERMINAL  (you add the secret lines with an editor; the file shows on your screen)
vi ~/nkp-site.env
```

Add these two lines, with your own values, inside single quotes:

```
export NUTANIX_USER='admin'
export NUTANIX_PASSWORD='...'
```

If the password contains a single quote, write it as `'\''`. Keep the file mode 600 and do not copy it anywhere.

#### Step 3 — check that the two names are set, without printing them (READ-ONLY)

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
bash -n ~/nkp-site.env 2>/dev/null && echo "set: syntax" || echo "MISSING: syntax"
for v in NUTANIX_USER NUTANIX_PASSWORD; do if [ -n "$(printenv "$v")" ]; then echo "set: $v"; else echo "MISSING: $v"; fi; done
```

I only ever look at `set:` / `MISSING:` lines. I never print the file, `env`, or `set`.

#### What is still empty

The secret pair alone does not make a cluster. The env file also needs the site values: `PC_ENDPOINT`, `PE_CLUSTER`, `SUBNET`, `STORAGE_CONTAINER`, `VM_IMAGE`, `SSH_PUBKEY_FILE`, `NTP_SERVERS` (air-gapped), `BUNDLE_DIR`, and for a mirror `REGISTRY_URL` and `REGISTRY_CA_FILE`. Give me those and I append them (CHANGES, one line each, rule 4). A cluster also needs its own `~/nkp-<cluster>.env` with `CLUSTER_NAME`, `CP_VIP`, `LB_IP_RANGE`, and `WORKSPACE_NS` (`kommander` for a management cluster).

One warning from the skill, not from your cluster: `admin` works for the CLI only if that Prism Central user has the NKP permissions [pdf p.705-707]. The preflight check will tell us; if it fails, the `Flag:` line names the credentials check.

**Where I stop:** after Step 1 and your `yes`. The password never passes through me.

---

## nkp-install E11

Skill files read for this answer: `skills/nkp/SKILL.md`, `skills/nkp-install/SKILL.md`, `skills/nkp-install/references/nutanix.md`.

### Reply

`dev-02` is a second workload cluster on the same management cluster: the same case **N5** as `dev-01`, with its own cluster env file and its own create script. `dev-01` keeps its file; I do not touch `~/nkp-dev-01.env`.

**I cannot write the create script yet: the VIP is not known.** And one more value is missing and equally blocking: `LB_IP_RANGE`. The network team must give both, and both must be new. The rules:

- `CP_VIP` is a static IP in the node subnet CIDR, **outside** the DHCP/IPAM pool, used by no other host [pdf p.720].
- `LB_IP_RANGE` is `<first-ip>-<last-ip>` on the same Layer 2 subnet as the workers, outside the pool. The NKP UI takes the first IP [pdf p.694, p.721]. Extra `LoadBalancer` services need more IPs [pdf p.693].
- Each cluster needs its own VIP **and** its own range [pdf p.693-694]. Do not reuse the `dev-01` values.
- Each node takes one IP from the subnet pool: 3+4 = 7 IPs by default, or 2+3 for the Starter workload sizes [pdf p.693, p.695-696]. So the pool must have room for a second cluster.

#### Step 1 — confirm the workspace, the mirror, and the `dev-01` values (READ-ONLY)

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" get workspaces -A
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n kommander get nkpclusters -o jsonpath='{.items[*].spec.kommanderCluster.spec.ociRegistry.mirrorURL}{"\n"}'
kubectl --kubeconfig "$MGMT_KUBECONFIG" get nkpclusters -A
source ~/nkp-dev-01.env 2>/dev/null
printenv WORKSPACE_NS; printenv REGISTRY_URL; printenv CP_VIP; printenv LB_IP_RANGE
```

What I check: `WORKSPACE_NS` from `dev-01` is the default workspace namespace (`kommander-default-workspace`); the mirror URL on the management cluster matches `REGISTRY_URL`; `dev-01` is `Reconciled`; and the `CP_VIP` / `LB_IP_RANGE` of `dev-01` are written down, so the new values from the network team can be checked against them. Those four `printenv` lines print site values, never secrets.

#### Step 2 — new cluster env file (CHANGES, stop for `yes`)

Target: `~/nkp-dev-02.env`, mode 600. Result: the file with the values I already have; `CP_VIP` and `LB_IP_RANGE` are added when the network team answers (rule 4: I do not write empty values).

```bash
# CHANGES  (makes ~/nkp-dev-02.env and appends the known values of this cluster)
test -e ~/nkp-dev-02.env || { (umask 077 && echo 'source ~/nkp-site.env 2>/dev/null' > ~/nkp-dev-02.env); }
echo "export CLUSTER_NAME='dev-02'" >> ~/nkp-dev-02.env
echo "export WORKSPACE_NS='kommander-default-workspace'" >> ~/nkp-dev-02.env
```

Then, after the network team answers:

```bash
# CHANGES  (appends the VIP and the range the network team gives; nothing else)
source ~/nkp-dev-02.env 2>/dev/null
echo "export CP_VIP='<new-ip-from-network-team>'" >> ~/nkp-dev-02.env
echo "export LB_IP_RANGE='<new-first-ip>-<new-last-ip>'" >> ~/nkp-dev-02.env
```

`~/nkp-site.env` does not change: the site values and the mirror are already there from `dev-01`.

#### Step 3 — check the env files (READ-ONLY)

```bash
# READ-ONLY  (case 5 mirror air-gapped)
source ~/nkp-dev-02.env 2>/dev/null
bash -n ~/nkp-site.env 2>/dev/null && bash -n ~/nkp-dev-02.env 2>/dev/null && echo "set: syntax" || echo "MISSING: syntax"
for v in CLUSTER_NAME CP_VIP LB_IP_RANGE WORKSPACE_NS PC_ENDPOINT PE_CLUSTER SUBNET STORAGE_CONTAINER VM_IMAGE SSH_PUBKEY_FILE NUTANIX_USER NUTANIX_PASSWORD; do if [ -n "$(printenv "$v")" ]; then echo "set: $v"; else echo "MISSING: $v"; fi; done
for v in MGMT_KUBECONFIG REGISTRY_URL REGISTRY_CA_FILE NTP_SERVERS; do if [ -n "$(printenv "$v")" ]; then echo "set: $v"; else echo "MISSING: $v"; fi; done
for v in REGISTRY_MIRROR_USERNAME REGISTRY_MIRROR_PASSWORD; do printenv "$v" >/dev/null && echo "set: $v" || echo "MISSING: $v"; done
ping -c 2 "$CP_VIP"
```

Done when every list prints `set:` lines, `set: syntax`, and `ping` gets no reply (the new VIP is free; if ICMP is filtered this proves nothing and I ask you to confirm).

#### Step 4 — write the create script (CHANGES, nothing is created yet)

The same N5 script as `dev-01`, run from `~/nkp-dev-02.env`. The cluster name, the namespace, the VIP and the range come from that file, so it creates `dev-02` and touches nothing of `dev-01`:

```bash
# CHANGES  (writes ~/nkp-dev-02-create.sh; creates nothing yet)
source ~/nkp-dev-02.env 2>/dev/null
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

#### Step 5 — dry run, then create (CHANGES, stop for `yes` twice)

```bash
# CHANGES  (writes the dry-run objects to a local file; creates no cluster)
source ~/nkp-dev-02.env 2>/dev/null
umask 077 && bash "$HOME/nkp-$CLUSTER_NAME-create.sh" --dry-run --output yaml > "$PWD/$CLUSTER_NAME-dryrun.yaml"
```

```bash
# READ-ONLY
source ~/nkp-dev-02.env 2>/dev/null
grep -n -E '^kind:|^  name:|image:|host:|addressRanges|start:|end:|url:' "$PWD/$CLUSTER_NAME-dryrun.yaml"
```

I check the dry-run lines against the `dev-01` values from Step 1: the name is `dev-02`, the namespace is the default workspace, the VIP and the load-balancer range are the **new** ones, and no `dev-01` IP appears. The file holds Secrets; I never print it [pdf p.729].

```bash
# CHANGES  (the management cluster creates dev-02: VMs in Prism Central, then the cluster)
source ~/nkp-dev-02.env 2>/dev/null
bash "$HOME/nkp-$CLUSTER_NAME-create.sh"
```

#### Step 6 — kubeconfig and verify (CHANGES, then READ-ONLY)

```bash
# CHANGES  (writes ~/dev-02.conf with mode 600 and appends CLUSTER_KUBECONFIG)
source ~/nkp-dev-02.env 2>/dev/null
umask 077 && nkp get kubeconfig --cluster-name "$CLUSTER_NAME" --namespace "$WORKSPACE_NS" --kubeconfig "$MGMT_KUBECONFIG" > "$PWD/$CLUSTER_NAME.conf" && echo "export CLUSTER_KUBECONFIG='$PWD/$CLUSTER_NAME.conf'" >> ~/nkp-dev-02.env
```

```bash
# READ-ONLY
source ~/nkp-dev-02.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get nodes
nkp describe cluster --cluster-name "$CLUSTER_NAME" --namespace "$WORKSPACE_NS" --kubeconfig "$MGMT_KUBECONFIG"
kubectl --kubeconfig "$MGMT_KUBECONFIG" get nkpclusters -A
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get storageclass
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n metallb-system get ipaddresspools
```

Done when: `dev-02` and `dev-01` are both `Reconciled` and both nodes sets are `Ready`; the two IPAddressPools hold different ranges; `nutanix-volume` is the `(default)` StorageClass on `dev-02`.

**Where I stop:** after Step 1 and the network team's two values (the VIP **and** a new `LB_IP_RANGE`). Nothing is written past Step 2's file, and nothing is created, until you type `yes` to each CHANGES plan.

---

## nkp E2

Skill files read for this answer: `skills/nkp/SKILL.md`, `skills/nkp/references/components.md`.

### Reply

**No. On Starter you cannot turn on Velero, and you cannot turn on the Grafana monitoring stack.**

- Starter is Nutanix AHV only and has **no monitoring apps and no logging apps** [pdf p.26-28, p.715].
- Velero, Harbor, observability (Prometheus, alerts, Grafana), logging, Istio, the GPU operators and Headlamp are **Pro** apps [pdf p.295-297].
- Thanos, Karma, central Grafana, OpenCost and NKP Insights are **Ultimate** [pdf p.295-297].

So the answer is a license upgrade, not an install. A license can go up a tier but never down after registration [pdf p.26], so Pro is a one-way step for this site: read the Pro app list above with the customer before you buy.

Changing or applying a license belongs to the `nkp-identity-security` skill. **That skill is not installed here**, so I give you only read-only checks, labeled "(not from a skill)", and no change command.

#### Checks (READ-ONLY, no approval needed)

Target: the management cluster at `~/mgmt.conf`. If `~/nkp-site.env` already sets `MGMT_KUBECONFIG`, use `"$MGMT_KUBECONFIG"` instead of the path.

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
kubectl --kubeconfig "$HOME/mgmt.conf" -n kommander get licenses.kommander.mesosphere.io -o jsonpath='{.items[*].status.dkpLevel}{"\n"}'
kubectl --kubeconfig "$HOME/mgmt.conf" get clusterapps -o custom-columns='NAME:.metadata.name,TIER:.metadata.annotations.apps\.kommander\.d2iq\.io/licensing'
kubectl --kubeconfig "$HOME/mgmt.conf" get clusterapps | grep -Ei 'velero|grafana|prometheus|thanos|karma'
kubectl --kubeconfig "$HOME/mgmt.conf" get appdeployments -A
kubectl --kubeconfig "$HOME/mgmt.conf" get nodes
```

What I check in the output:

1. The first command prints the license level. `Starter` matches what you told me; `Pro` or `Ultimate` means the question is different and I go and look at the two apps instead.
2. The second command prints the tier annotation of every platform app. Velero and the monitoring apps, if they are listed at all, carry `Pro` (or `Ultimate`); Starter apps carry `Starter`.
3. The grep tells me whether `velero` and `grafana`/`prometheus` ClusterApps exist in this 2.19.0 catalog, and the `appdeployments` list tells me whether the workspace already enables them. On Starter they are not enabled.
4. `get nodes` gives the worker count, and this matters: **with 2 workers the Pro and Ultimate apps fail after a license upgrade** [pdf p.695]. So if this Starter cluster runs the Starter minimum of 2 workers, the customer must scale the workers out before the upgrade, or the monitoring stack will not come up.

#### What I do next

- If the license really is Starter: I tell the customer the two options — stay on Starter without Velero and monitoring, or upgrade to Pro (which also brings Harbor, logging and Istio) — and I point them at the license procedure.
- The license procedure, the Pro app enablement, and the AppDeployment override to turn Velero and Grafana on are in `nkp-identity-security`, `nkp-observability` and `nkp-platform-apps-gitops`. **None of those three skills is installed here**, so I stop at the checks above: no change command, no invented flags or CRD fields.

**Where I stop:** after the checks. I give no `# CHANGES` command for a license change or an app enablement from this skill set.
