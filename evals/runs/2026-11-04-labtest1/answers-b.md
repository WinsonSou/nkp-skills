# Group b answers

## nkp-identity-security S4

Skill files read: `nkp/SKILL.md`, `nkp/_shared/RULES.md`, `nkp-identity-security/SKILL.md`.

I cannot apply the key in this turn. Two reasons:

1. Rule 2. A CHANGES block runs only after you type `yes` to the plan. "Just apply it" is not `yes`.
2. A Pro or Ultimate key is bound to the **name of the management cluster**. A key for another name gives `License key is not valid for this cluster` [live 2.19.0]. I must compare the name first.

### Step 1 — read the state (I run this now)

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
[ -n "$(printenv NKP_LICENSE_KEY)" ] && echo "set: NKP_LICENSE_KEY" || echo "MISSING: NKP_LICENSE_KEY"
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n kommander get licenses.kommander.mesosphere.io nutanix-license -o jsonpath='ref={.spec.nutanixLicenseRef.name}{"\n"}'
kubectl --kubeconfig "$MGMT_KUBECONFIG" get nodes -l '!node-role.kubernetes.io/control-plane' -o custom-columns='NAME:.metadata.name,CPU:.status.allocatable.cpu,MEM:.status.allocatable.memory'
kubectl --kubeconfig "$MGMT_KUBECONFIG" describe nodes -l '!node-role.kubernetes.io/control-plane' | grep -E '^Name:|^  (cpu|memory) +[0-9]'
```

I expect: `set: NKP_LICENSE_KEY`, `ref=` empty (no license Secret yet), and the worker list with CPU requests.

`ref=` empty → the cluster has its default license, and way B (kubectl) is correct.
`ref=` has a name → a license Secret is already in use. Then I do not replace that Secret. If the UI gives no way forward, `UNKNOWN (P-56)`: the kubectl way to replace a used key is not in the skills.

The management cluster name comes from the router skill:

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" get nkpclusters -A -o custom-columns='NAMESPACE:.metadata.namespace,NAME:.metadata.name,MGMT:.metadata.labels.kommander\.d2iq\.io/host'
```

### Step 2 — the plan (I stop here for `yes`)

- Cluster: the `NAME` with `MGMT true` (or `NAMESPACE kommander`) from the block above. **The key must be for this exact name.**
- Tier: `<old tier from step 1>` → **Ultimate**. You cannot go back to a lower tier after registration [pdf p.26].
- Workers: the list and the CPU requests from step 1. Above ~60 % before an Ultimate change, add workers or bigger workers first — Ultimate takes worker CPU requests to 67–98 % on 4×8 vCPU [live 2.19.0].
- Effect: NKP installs the 24 extra HelmReleases of the tier (about 11 min), then the UI shows `Valid`.
- The key stays in `~/nkp-site.env`. I never print it, and the Secret is made from the variable.

If the cluster name in that block is not the name the key was bought for, stop: get a key for this name.

### Step 3 — after you type `yes`

```bash
# CHANGES  (makes Secret kommander/nutanix-license-secret with the license key)
source ~/nkp-site.env 2>/dev/null
: "${NKP_LICENSE_KEY:?}"
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n kommander create secret generic nutanix-license-secret --from-file=nutanix-license-key=<(printf %s "$(printenv NKP_LICENSE_KEY)") --dry-run=client -o yaml | kubectl --kubeconfig "$MGMT_KUBECONFIG" apply -f - -o name
```

Then the check that the webhook accepts the key. It changes nothing, and the `sed` mask hides the key if the webhook prints it:

```bash
# READ-ONLY  (server dry run: changes nothing; the sed mask hides the key in a webhook error)
source ~/nkp-site.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n kommander patch licenses.kommander.mesosphere.io nutanix-license --type merge -p '{"spec":{"nutanixLicenseRef":{"name":"nutanix-license-secret"}}}' --dry-run=server -o jsonpath='{.spec}{"\n"}' 2>&1 | sed -E 's/Invalid value: "[^"]*"/Invalid value: "[masked]"/'
```

- It prints `{"nutanixLicenseRef":{"name":"nutanix-license-secret"}}` → I run the real patch (CHANGES, again after your `yes`):

```bash
# CHANGES  (points the license to the new key; NKP changes the tier and installs the apps of that tier)
source ~/nkp-site.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n kommander patch licenses.kommander.mesosphere.io nutanix-license --type merge -p '{"spec":{"nutanixLicenseRef":{"name":"nutanix-license-secret"}}}' 2>&1 | sed -E 's/Invalid value: "[^"]*"/Invalid value: "[masked]"/'
```

- It prints `denied the request` → I do not run the patch. I show you the masked error only.

Then I run step 1 again (tier changes in about 15 s) and the HelmRelease check twice, 15 min apart. Done when: `valid=true`, tier `Ultimate`, and `kommander` has 48 HelmReleases (Starter is 24) [live 2.19.0].

I skip nothing here: the only open item is your `yes`, and the name match.

---

## nkp-identity-security S11

Skill files read: `nkp/SKILL.md`, `nkp/_shared/RULES.md`, `nkp-identity-security/SKILL.md`.

**No. Do not paste that error into the ticket.** The license webhook prints the full key in the rejection (`data.nutanix-license-key: Invalid value: "<key>"`) [live 2.19.0]. The rule in the skill is: never put a raw webhook error in the chat or in a log. Both `patch` blocks send their output through `sed -E 's/Invalid value: "[^"]*"/Invalid value: "[masked]"/'`. If the key showed on your screen, that block ran without the mask.

**Also no: do not run the real patch.** A dry run that prints `denied the request` is a stop. The key is not valid for this cluster.

### What the error means

`License key is not valid for this cluster` = the key is for another management cluster name [live 2.19.0]. Nothing is broken. The key and the cluster name do not match.

Two more things follow:
- The rejected Secret `kommander/nutanix-license-secret` stays and holds the bad key [live 2.19.0].
- The key was on the screen. Ask the Nutanix Support Portal for a new key, and do not reuse this one in a ticket, a chat, or a log.

### What I do now

1. Read the state (READ-ONLY):

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
[ -n "$(printenv NKP_LICENSE_KEY)" ] && echo "set: NKP_LICENSE_KEY" || echo "MISSING: NKP_LICENSE_KEY"
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n kommander get licenses.kommander.mesosphere.io nutanix-license -o jsonpath='ref={.spec.nutanixLicenseRef.name}{"\n"}'
kubectl --kubeconfig "$MGMT_KUBECONFIG" get nkpclusters -A -o custom-columns='NAMESPACE:.metadata.namespace,NAME:.metadata.name,MGMT:.metadata.labels.kommander\.d2iq\.io/host'
```

I expect `ref=` empty and the management cluster name in the list. If `ref=` had a name before you started, the Secret delete below does not apply (the License uses that Secret).

2. I need one answer from you: **which cluster name was the key bought for?** Compare it with the `MGMT true` name from block 1. They must be the same.

3. The plan to remove the rejected Secret (only when `ref=` was empty):

```bash
# CHANGES  (deletes Secret kommander/nutanix-license-secret that holds a rejected key)
source ~/nkp-site.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n kommander delete secret nutanix-license-secret
```

I stop for `yes` before this block. Then, to be safe about the exposed key, I also run the read-back check that the Secret is gone before we make a new one.

4. You get a key for **this** cluster name from the portal, and you put it into `~/nkp-site.env` with your editor (`export NKP_LICENSE_KEY='...'`). I do not write a secret line for you (rule 5).

5. Then I run, in this order: the create Secret block, the masked server dry run, and — only when it prints `{"nutanixLicenseRef":{"name":"nutanix-license-secret"}}` — the real patch. Each one after your `yes`.

### For the ticket

Write: "License apply failed with a webhook rejection: key not valid for this cluster name." Add the masked line only. No key, no full error text, no `kubectl` output that holds `nutanix-license-key`.

---

## nkp-identity-security S12

Skill files read: `nkp/SKILL.md`, `nkp/_shared/RULES.md`, `nkp-identity-security/SKILL.md`, `nkp-identity-security/references/rbac.md`.

Correct: there is no `nkp delete workspace` in 2.19.0 [live 2.19.0]. A workspace delete is a UI action. There is no CLI block for it, and I do not have a CHANGES command to run.

### Step 1 — confirm the state (I run this now)

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" get workspaces
```

I expect one row for `team-a` with the **WORKSPACE NAMESPACE** column filled (the CLI makes `<ws>-<5 random characters>`, for example `team-a-7kr7h` [live 2.19.0]). I use that column, never the workspace name, as `wsns`.

```bash
# READ-ONLY  (before the delete: no cluster in the workspace)
source ~/nkp-site.env 2>/dev/null
ws='team-a'; wsns=''
: "${ws:?}" "${wsns:?}"
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$wsns" get nkpclusters,kommanderclusters
kubectl --kubeconfig "$MGMT_KUBECONFIG" get workspace "$ws" -o jsonpath='{.metadata.deletionTimestamp} {.metadata.finalizers}{"\n"}'
kubectl --kubeconfig "$MGMT_KUBECONFIG" get namespace "$wsns" -o jsonpath='{.status.phase}{"\n"}{range .status.conditions[*]}{.type}={.status} {.message}{"\n"}{end}'
```

I fill `wsns` with the value from block 1 before I run it. I do not guess it.

I expect `No resources found` for the first line. A row there means a cluster is still in the workspace, and a workspace can be deleted only when it has no clusters [pdf p.318].

### Step 2 — the plan (I stop here for `yes`)

- Workspace: `team-a`, namespace `<wsns>` from block 1.
- The delete removes **the namespace and every object in it** — its NKPClusters, AppDeployments, roles, and Projects. It cannot be undone.
- `kommander-workspace` cannot be deleted (the management cluster is in it) [pdf p.496]. Not our case, but I say it in every plan.
- You do the delete in the UI: Global → Workspaces → the three-dot button of `team-a` → Delete → confirm in the Delete Workspace dialog [pdf p.318-319].

I need `yes` before you click Delete.

### Step 3 — check after the delete

```bash
# READ-ONLY  (after the delete: what still blocks the namespace)
source ~/nkp-site.env 2>/dev/null
ws='team-a'; wsns=''
: "${ws:?}" "${wsns:?}"
kubectl --kubeconfig "$MGMT_KUBECONFIG" get workspace "$ws" -o jsonpath='{.metadata.deletionTimestamp} {.metadata.finalizers}{"\n"}'
kubectl --kubeconfig "$MGMT_KUBECONFIG" get namespace "$wsns" -o jsonpath='{.status.phase}{"\n"}{range .status.conditions[*]}{.type}={.status} {.message}{"\n"}{end}'
```

Done when: `get workspace` and `get namespace` give `NotFound`.

If the namespace stays `Terminating`: I show you the `NamespaceContentRemaining` and `NamespaceFinalizersRemaining` conditions. On lab test 1 these named 27 `workspaceroles`, 7 kubefed `federated*` objects, and 2 `helm*proxies` [live 2.19.0]. **I do not remove finalizers** — that skips the cleanup of the controllers. I show the conditions and stop. `UNKNOWN (P-55)`: whether the delete finishes by itself after the clusters are gone, and whether a finalizer removal is safe. Find out with:

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" get namespaces --field-selector status.phase=Terminating
```

---

## nkp-cluster-lifecycle L5

Skill files read: `nkp/SKILL.md`, `nkp/_shared/RULES.md`, `nkp-cluster-lifecycle/SKILL.md`, `nkp-cluster-lifecycle/references/delete.md`.

I cannot go yet. The delete must name the cluster in the approval, and my safety facts are not read. `yes I'm sure, go` has no cluster name in it, so it is not approval (delete.md D2 item 4).

### Step 1 — identify the cluster (I run this now)

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" get nkpclusters -A -o custom-columns='NAMESPACE:.metadata.namespace,NAME:.metadata.name,CAPI:.status.capiClusterRef.name,PHASE:.status.phase,K8S:.status.kubernetesVersion,CLASS:.spec.capiCluster.topology.classRef.name,MGMT:.metadata.labels.kommander\.d2iq\.io/host'
```

I use `kubectl get nkpclusters`, not `nkp get clusters` [pdf p.814]. I expect `test-02` with `MGMT` empty and an empty `CLASS` absent. An empty `CLASS`: no ClusterClass, and this skill has no steps for it — I stop then.

"Default workspace" is your words, not the namespace. I take the NAMESPACE column that this block prints, and I check it.

The cluster env file. I ask two things in one message:
- Is the NAMESPACE value `<from the block>`? (It is usually `kommander-default-workspace` on a fresh install, but I do not take that from memory.)
- Does `~/nkp-test-02.env` exist?

Then:

```bash
# READ-ONLY
source ~/nkp-test-02.env 2>/dev/null
for v in CLUSTER_NAME WORKSPACE_NS CLUSTER_KUBECONFIG MGMT_KUBECONFIG; do if [ -n "$(printenv "$v")" ]; then echo "set: $v"; else echo "MISSING: $v"; fi; done
```

Done when it prints `set:` for all four. A missing file or value: I make it (CHANGES, after `yes`) with skill `nkp-install`, "Prepare the env files", item 2, and append `CLUSTER_NAME` and `WORKSPACE_NS` with rule 4 after you confirm the values. `CLUSTER_KUBECONFIG` comes from skill `nkp-install`, "Set the kubeconfig variables".

### Step 2 — D1 and the safety gate

```bash
# READ-ONLY
source ~/nkp-test-02.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get nkpcluster "$CLUSTER_NAME" -o custom-columns='NAMESPACE:.metadata.namespace,NAME:.metadata.name,MGMT:.metadata.labels.kommander\.d2iq\.io/host,PHASE:.status.phase,CP:.spec.capiCluster.topology.controlPlane.replicas'
kubectl --kubeconfig "$MGMT_KUBECONFIG" get nkpclusters -A
```

`MGMT true` or `NAMESPACE kommander` would make this the management cluster (D4). Otherwise it is a workload cluster (D2).

```bash
# READ-ONLY
source ~/nkp-test-02.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get nodes
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get ns
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get pvc -A
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get pv -o custom-columns='NAME:.metadata.name,NS:.spec.claimRef.namespace,PVC:.spec.claimRef.name,SIZE:.spec.capacity.storage,HANDLE:.spec.csi.volumeHandle'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get svc -A --field-selector spec.type=LoadBalancer
```

```bash
# READ-ONLY
source ~/nkp-test-02.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get nkpclusters -A
```

I expect `error: the server doesn't have a resource type "nkpclusters"` or `No resources found`. That is the pass case: this cluster does not manage other clusters. A list there stops the delete.

I keep the PV list. Each PV of the Nutanix CSI is one volume group in Prism Central; `HANDLE` is `NutanixVolumes-<uuid>` and `<uuid>` is the `extId` of the group [live 2.19.0]. D5 needs it.

### Step 3 — the plan (I stop here)

1. Command: D3 below. Cluster `test-02`, namespace `<WORKSPACE_NS>`, management cluster `<MGMT name>`.
2. What goes: all nodes and VMs, all pods, the `LoadBalancer` services from the list, and the access to all PVC data [pdf p.814].
3. What stays: one volume group per PV in Prism Central with its data (D5.2), the mirror Secrets `<test-02>-oci-cert` and `<test-02>-oci-creds` in the workspace namespace (D5.1), a VPC with its floating IPs if the cluster had one (D5.3), and the operator host files (D5.4).
4. **Approval: type `yes test-02` in one message** — `yes` plus the exact cluster name. A message without the name is not approval.
5. If a PVC holds data you need: say so now. The backup is skill `nkp-storage-backup`, file `velero.md`, B3.

### Step 4 — after `yes test-02`

```bash
# CHANGES  (deletes the workload cluster: its VMs, nodes, and data; cannot be undone)
source ~/nkp-test-02.env 2>/dev/null
nkp delete cluster --cluster-name "$CLUSTER_NAME" --namespace "$WORKSPACE_NS" --kubeconfig "$MGMT_KUBECONFIG" --timeout 30m
```

Expected output: 3 steps, then `INF Deleted <namespace>/<cluster> cluster`, RC 0. Time: 28 s for 5 nodes without PVCs, 57 s for 7 nodes with PVCs [live 2.19.0]. `--timeout 30m` is only a safety limit.

Check (READ-ONLY), then the IP check and D5. Done when the two kubectl blocks show no object, `ping` gets no reply and `curl` prints `000` (if ICMP is blocked, `curl` is the proof).

---

## nkp-cluster-lifecycle L6

Skill files read: `nkp/SKILL.md`, `nkp/_shared/RULES.md`, `nkp-cluster-lifecycle/SKILL.md`, `nkp-cluster-lifecycle/references/delete.md`.

This is three deletes in a fixed order: the two workload clusters first, the management cluster last. After the management cluster is gone, NKP cannot delete the workload clusters [pdf p.496].

I do not have the cluster names, and I do not take them from an example. First read (I run this now):

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" get nkpclusters -A -o custom-columns='NAMESPACE:.metadata.namespace,NAME:.metadata.name,PHASE:.status.phase,CLASS:.spec.capiCluster.topology.classRef.name,MGMT:.metadata.labels.kommander\.d2iq\.io/host'
ls "$BUNDLE_DIR"/konvoy-bootstrap-image-*.tar
```

I expect exactly three rows: one with `MGMT true` (or NAMESPACE `kommander`), and two in a workspace namespace. `ls` expects one `konvoy-bootstrap-image-*.tar` — the air-gapped D4 block needs it.

Then I confirm with you, in one message: the three names, and that each of the two workload clusters is the one you mean. A fourth row, or a name I did not expect, stops the whole job.

### The order and the plan

**Cluster 1 (workload), then cluster 2 (workload), then the management cluster.** For each workload cluster I do D1, the D2 safety gate, the plan, and wait for `yes <name>`; then D3, the checks, and D5. The next cluster starts only when the one before it is clean.

Per workload cluster, the plan has: the command, the name, the namespace, the `LoadBalancer` service list, and the PV list (one Prism Central volume group per PV stays). Approval is `yes <that cluster name>`.

Then the management cluster (D4):

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" get nkpclusters -A
```

This must list **only** the management cluster. A row there stops D4 — a workload cluster is still alive.

D4 plan, in addition to the D2 items: Kommander, the NKP UI, and all platform apps go. A management cluster has many PVCs (3 with Starter, 20 with Ultimate, 340 Gi) [live 2.19.0]. The delete moves the CAPI resources to a kind bootstrap cluster on this host first, so the operator host needs the bootstrap requirements of skill `nkp-install` (container engine, 4 CPU and 4 GB free). Approval: `yes <mgmt cluster name>`.

```bash
# CHANGES  (deletes the management cluster; makes a kind bootstrap cluster on this host; cannot be undone)
source ~/nkp-<cluster>.env 2>/dev/null
nkp delete cluster --self-managed --cluster-name "$CLUSTER_NAME" --namespace "$WORKSPACE_NS" --kubeconfig "$MGMT_KUBECONFIG" --timeout 60m ${BUNDLE_DIR:+--bootstrap-cluster-image "$(ls "$BUNDLE_DIR"/konvoy-bootstrap-image-*.tar)"}
```

`<cluster>` stays in line 2 until block 1 prints your management cluster name. Then I replace it with the real name in every block that uses a cluster-file variable. Each step prints `•` then `✓`. Time: 5–10 min for 3 control-plane and 4 worker nodes (Starter 5 min, Ultimate 7 min) [live 2.19.0]. The `<cluster>-bootstrap.conf` file that the output names goes away with the bootstrap cluster; do not use it.

### After each delete

- D3 checks: no NKPCluster, Cluster, or Machine for the name. The NKPCluster was `NotFound` 82 s after RC 0 [live 2.19.0].
- IP check: `ping` no reply, `curl` prints `000`.
- D4 extra checks: `docker ps -a --format '{{.Names}}'` (no name with `bootstrap`; use `podman ps -a` on Podman) and `ls -l "$PWD/$CLUSTER_NAME-bootstrap.conf` (expect "No such file or directory").
- D5 for every cluster, in order: D5.1 mirror Secrets (workload only), D5.2 volume groups in Prism Central, D5.3 VPC objects, D5.4 operator host files, and after the management cluster D5.5.

D5.2 is the big one here: the two workload clusters and the Ultimate management cluster leave about 20 groups each on the management side, with the PVC data. I report the count, the names, the PVCs, and the sizes, and I get `yes` on those exact objects before any volume-group delete. The recipe is skill `nutanix-storage`, "What an NKP cluster leaves behind", and the full check is skill `nutanix-nkp`, "Leftover audit for a cluster".

D5.5: `~/nkp-site.env` is never removed. After the management cluster delete, `MGMT_KUBECONFIG` in it points to a dead cluster or a removed file. **No block that uses `MGMT_KUBECONFIG` works until a new management cluster exists**, and I do not write a placeholder value.

I stop now, at block 1, for the names.

---

## nkp-cluster-lifecycle L9

Skill files read: `nkp/SKILL.md`, `nkp/_shared/RULES.md`, `nkp-cluster-lifecycle/SKILL.md`, `nkp-cluster-lifecycle/references/delete.md`, `ntnx-skills/nutanix-api/SKILL.md`, `ntnx-skills/nutanix-storage/SKILL.md`, `ntnx-skills/nutanix-storage/RECIPES.md`, `ntnx-skills/nutanix-nkp/RECIPES.md`.

RC 0 is not proof that the objects are gone. First the delete checks, then D5. Do this cleanup now: after the management cluster goes, `MGMT_KUBECONFIG` is dead and D5.1 and D5.4 cannot read their values.

### Step 1 — the delete finished (READ-ONLY, I run this now)

```bash
# READ-ONLY
source ~/nkp-dev-03.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get nkpclusters,clusters.cluster.x-k8s.io,machines -l "cluster.x-k8s.io/cluster-name=$CLUSTER_NAME"
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get nkpcluster "$CLUSTER_NAME"
```

```bash
# READ-ONLY
source ~/nkp-dev-03.env 2>/dev/null
ping -c 2 -W 2 "$CP_VIP"
curl -sk -o /dev/null -w '%{http_code}\n' --max-time 5 "https://${LB_IP_RANGE%%-*}/"
```

I expect `No resources found` and `NotFound`, no ping reply, and `000`. An object that stays: `sleep 30` and run it again. If a Machine still exists, I do not clean anything else yet.

If `~/nkp-dev-03.env` is not there, I ask you for the workspace namespace of `dev-03` first; the mirror Secrets live in that namespace and a wrong value makes them look `NotFound` while they stay.

### Step 2 — what is left, and the order

**D5.1 Mirror Secrets** (management cluster):

```bash
# READ-ONLY
source ~/nkp-dev-03.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get secret "$CLUSTER_NAME-oci-cert" "$CLUSTER_NAME-oci-creds"
```

`NotFound` for both → the cluster had no mirror flags, skip. A row → this block, after `yes`:

```bash
# CHANGES  (deletes the 2 mirror Secrets of the deleted workload cluster on the management cluster)
source ~/nkp-dev-03.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" delete secret "$CLUSTER_NAME-oci-cert" "$CLUSTER_NAME-oci-creds" --ignore-not-found
```

**D5.2 Prism Central leftovers** (VMs, volume groups, floating IPs, IP reservations, categories):

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
python3 - <<'PY'
import sys; sys.path.insert(0, '/tmp/nkp-eval-lt1/ntnx-skills/nutanix-api/scripts'); from ntnx import *
G = '/volumes/v4.3/config/volume-groups'; N = '/networking/v4.4/config'
V = '/vmm/v4.1/ahv/config/vms'; CAT = '/prism/v4.0/config/categories'
ipv_s = lambda o: o if isinstance(o, str) else ((o or {}).get('ipv4') or {}).get('value') or (o or {}).get('value')
def entries(g):
    d = g.get('description') or ''
    if 'K8sClusterID' not in d or ' for ' not in d: return None
    f = lambda k: next((p.split(':',1)[1] for p in d.split(', ') if p.startswith(k+':')), None)
    return d.split(' for ',1)[1].split(',',1)[0], f('PVC'), f('NS')
c = 'dev-03'; out = {'VMs': [], 'volume_groups': [], 'floating_ips': [], 'ip_reservations': [], 'categories': []}
for v in list_all(V, filter=f"startswith(name,'{c}')"):
    out['VMs'].append({'name': v['name'], 'extId': v['extId'], 'power': v.get('powerState')})
for g in list_all(G):
    e = entries(g)
    if g.get('isHidden') or g.get('usageType') == 'INTERNAL' or not e or e[0] != c: continue
    if (req(f"{G}/{g['extId']}/vm-attachments")[2].get('data') or []): continue
    out['volume_groups'].append({'name': g['name'], 'extId': g['extId'], 'pvc': e[1], 'ns': e[2]})
for f in list_all(f'{N}/floating-ips'):
    if c in (f.get('name') or ''):
        out['floating_ips'].append({'name': f['name'], 'extId': f['extId'], 'status': f.get('associationStatus')})
for sn in list_all(f'{N}/subnets'):
    for r in (req(f'{N}/subnets/{sn["extId"]}/reserved-ips')[2].get('data') or []):
        if c in (r.get('clientContext') or ''):
            out['ip_reservations'].append({'ip': ipv_s(r.get('ipv4Address')), 'context': r.get('clientContext')})
used = {x.get('extId') for v in list_all(V) for x in v.get('categories') or []}
for k in list_all(CAT):
    if c in (k.get('key') or '') or c in (k.get('value') or ''):
        out['categories'].append({'key': k['key'], 'value': k['value'], 'extId': k['extId'], 'inUse': k['extId'] in used})
out['counts'] = {k: len(v) for k, v in out.items()}
print(out)
PY
```

This is the "Leftover audit for a cluster" recipe of `nutanix-nkp/RECIPES.md` with the cluster name set. A bulk-named floating IP (`fip-dummy-name`) cannot be attributed to a cluster; the recipe puts it in a separate candidate list, and I treat it as a candidate only.

I expect `counts` of 0 for every kind, and:
- `volume_groups` — **normal after a delete**: the CSI groups stay, unattached, with the PVC data. Each PV in my D2 list is one of them. A workload cluster with PVCs leaves 4, without PVCs 0 [live 2.19.0].
- `VMs` a row → the delete did not finish. Stop, skill `nkp-troubleshooting`.
- `floating_ips` → normal for a VPC cluster; the delete recipe is skill `nutanix-networking`, "Delete a floating IP" (disassociate, then delete).
- `ip_reservations` → a VIP reserved and never released; skill `nutanix-networking`, "Subnet IP reservations".
- `categories` with `inUse` false → skill `nutanix-prism`, "Categories".

For the volume groups I run the tighter filter too (description `for dev-03,` **and** `K8sClusterID`, and `vm-attachments` empty, never `isHidden` / `INTERNAL`):

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
python3 - <<'PY'
import sys; sys.path.insert(0, '/tmp/nkp-eval-lt1/ntnx-skills/nutanix-api/scripts'); from ntnx import *
G = '/volumes/v4.3/config/volume-groups'
def entries(g):
    d = g.get('description') or ''
    if 'K8sClusterID' not in d or ' for ' not in d: return None
    f = lambda k: next((p.split(':',1)[1] for p in d.split(', ') if p.startswith(k+':')), None)
    return d.split(' for ',1)[1].split(',',1)[0], f('PVC'), f('NS')
out = []
for g in list_all(G):
    if g.get('isHidden') or g.get('usageType') == 'INTERNAL': continue
    e = entries(g)
    if not e or e[0] != 'dev-03': continue
    if (req(f"{G}/{g['extId']}/vm-attachments")[2].get('data') or []): continue
    out.append((g['name'], g['extId'], e))
print(len(out)); [print(x) for x in out]
PY
```

**D5.3 VPC objects**: only if `dev-03` was in a VPC (the `floating_ips` rows show it). Skill `nkp-vpc`, step 7, now — before D5.4 removes the env file through which the names are read. Not in a VPC: skip.

**D5.4 Operator host files** (bastion):

```bash
# READ-ONLY
source ~/nkp-dev-03.env 2>/dev/null
for f in "$HOME/nkp-$CLUSTER_NAME-create.sh" "$HOME/nkp-$CLUSTER_NAME-patch.json" "$HOME/nkp-$CLUSTER_NAME-nodepool.sh" "$HOME/nkp-$CLUSTER_NAME-nodepool-dryrun.yaml" "$HOME/nkp-$CLUSTER_NAME-inventory.yaml" "$PWD/$CLUSTER_NAME-dryrun.yaml" "$PWD/$CLUSTER_NAME-dryrun.err" "$PWD/$CLUSTER_NAME-metallb-conf.yaml" "$PWD/$CLUSTER_NAME-bootstrap.conf" "$HOME/nkp-$CLUSTER_NAME-create.log" "$CLUSTER_KUBECONFIG" "$HOME/nkp-$CLUSTER_NAME.env"; do [ -e "$f" ] && ls -l "$f"; done; true
ls -a "$HOME" "$PWD" | grep -F -- "$CLUSTER_NAME"
```

I run it from the folder where the create ran. Then, after `yes`, one CHANGES block removes exactly those names (the `.env` last, with `;` not `&&`). No `*` after the cluster name. The second command can match a longer name (`dev-03` matches `dev-030`); I do not remove those, and I ask you about any file it finds that the first list does not name.

### The plan (I stop here for `yes`)

One plan, in this order: the mirror Secret delete (if a row), the volume-group deletes on the exact objects from the filter (name, `extId`, PVC, namespace — this destroys the PVC data), the VPC cleanup, the host-file delete. `yes` covers the steps you approve; I name each block as I start it. D5.5 does not apply here (the management cluster still exists). It does apply after your next step.

One warning about that next step: the management cluster is Ultimate, so its own delete leaves about 20 volume groups and 340 Gi of PVC data in Prism Central [live 2.19.0]. That cleanup uses the same D5.2 recipes with the management cluster name, and it runs after the management cluster is gone — through Prism Central, not through `kubectl`.

---

## nkp-cluster-lifecycle L10

Skill files read: `nkp/SKILL.md`, `nkp/_shared/RULES.md`, `nkp-cluster-lifecycle/SKILL.md`, `nkp-cluster-lifecycle/references/delete.md`, `ntnx-skills/nutanix-api/SKILL.md`, `ntnx-skills/nutanix-api/REFERENCE.md`, `ntnx-skills/nutanix-storage/SKILL.md`, `ntnx-skills/nutanix-storage/RECIPES.md`, `ntnx-skills/nutanix-nkp/RECIPES.md`.

`nkp delete cluster` does **not** delete the PVCs. It keeps one Nutanix CSI volume group for each PV, with the data [live 2.19.0]. An Ultimate management cluster leaves 20 groups, 340 Gi [live 2.19.0]. That is the first thing to look at. The blocks below read Prism Central, not the cluster — correct, because `MGMT_KUBECONFIG` is dead now (D5.5). Do not try kubectl here.

### Step 1 — capacity and the full leftover list (READ-ONLY, I run this now)

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
python3 - <<'PY'
import sys; sys.path.insert(0, '/tmp/nkp-eval-lt1/ntnx-skills/nutanix-api/scripts'); from ntnx import *
GIB = 2 ** 30
for e in req('/nutanix/v2.0/storage_containers')[2]['entities']:
    u = e.get('usage_stats') or {}
    t = int(u.get('storage.user_capacity_bytes') or 0); f = int(u.get('storage.user_unreserved_free_bytes') or 0)
    print(e['name'], round(t/GIB,1), round(f/GIB,1), round(100*(t-f)/t,1) if t else None)
PY
```

A `-1` in a v2 stat means "not reported", not zero. This gives the free/total GiB and the used percent per container, so we see the size of the problem and can compare before and after.

The full audit (VMs, volume groups, floating IPs, IP reservations, categories):

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
python3 - <<'PY'
import sys; sys.path.insert(0, '/tmp/nkp-eval-lt1/ntnx-skills/nutanix-api/scripts'); from ntnx import *
# the path constants and the audit() helper from nutanix-nkp/RECIPES.md, "Leftover audit for a cluster", pasted whole
print(audit('nkp-lab-01'))
PY
```

The recipe text goes in as the file has it, not retyped. I expect: `volume_groups` about 20 rows with the platform PVC names (`helm-charts-pvc`, `git-operator-*`, `kube-prometheus-stack-grafana`, `opencost-pvc`, `prometheus-...-db-...-0`) [live 2.19.0]. `VMs` should be empty; a row means the delete left node VMs, and their disks are a real part of "storage full". `counts` comes first, then the rows.

Then the volume groups with their size and PVC, from the tighter filter:

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
python3 - <<'PY'
import sys; sys.path.insert(0, '/tmp/nkp-eval-lt1/ntnx-skills/nutanix-api/scripts'); from ntnx import *
G = '/volumes/v4.3/config/volume-groups'
def entries(g):
    d = g.get('description') or ''
    if 'K8sClusterID' not in d or ' for ' not in d: return None
    f = lambda k: next((p.split(':',1)[1] for p in d.split(', ') if p.startswith(k+':')), None)
    return d.split(' for ',1)[1].split(',',1)[0], f('PVC'), f('NS')
for g in list_all(G):
    if g.get('isHidden') or g.get('usageType') == 'INTERNAL': continue
    e = entries(g); 
    if not e or e[0] != 'nkp-lab-01': continue
    if (req(f"{G}/{g['extId']}/vm-attachments")[2].get('data') or []): continue
    print(g['name'], g['extId'], round((g.get('sizeBytes') or 0)/2**30,1), e[1], e[2])
PY
```

`nkp-lab-01` also matches `nkp-lab-010`. I say so when a row looks foreign and I do not delete it without your word.

### Step 2 — what I will not delete

- The Prism Central internal groups. On the lab PC 11 groups belong to Prism Central itself (`isHidden`, `usageType: INTERNAL`) and they do not carry `K8sClusterID` [live 2.19.0]. The filter above skips them. A group with no `K8sClusterID` stays.
- The storage container. It holds every VM and volume group of the cluster. I report its capacity and never delete it [nutanix-storage rule 2].
- The Prism Central images of the node OS. They stay, and other clusters can use them (D5). I report their size, nothing more.

### Step 3 — the plan (I stop here for `yes`)

The plan: the capacity lines from step 1, the count of groups, and for each group the name, `extId`, size, PVC, and namespace. The delete **destroys the PVC data of that group** and takes its disks with it. The delete is per group, irreversible, and takes about 3 s.

Also in the plan: any `VMs` row (skill `nutanix-vm`, delete recipe), `ip_reservations` (skill `nutanix-networking`, "Subnet IP reservations"), and `categories` with `inUse` false (skill `nutanix-prism`, "Categories"). Floating IPs take no storage; I report them and do not touch them here.

Approval: `yes` for the volume-group deletes on **those exact objects**. I do not delete a group to free space you have not seen reported.

### Step 4 — after `yes`, one group at a time (CHANGES)

```bash
# CHANGES  (deletes one volume group and its disks; destroys that PVC's data)
source ~/nkp-site.env 2>/dev/null
python3 - <<'PY'
import sys; sys.path.insert(0, '/tmp/nkp-eval-lt1/ntnx-skills/nutanix-api/scripts'); from ntnx import *
G = '/volumes/v4.3/config/volume-groups'; vg_id = ''   # extId from the plan
g = next(x for x in list_all(G) if x['extId'] == vg_id)          # list projection: attachments
print(g['name'], g['description'], g['attachmentType'])          # assert the target first
for vm_id in [a['attachment']['extId'] for a in g.get('attachments') or []]:
    post(f'{G}/{vg_id}/$actions/detach-vm', {"$objectType": "volumes.v4.config.VmAttachment", "extId": vm_id})
assert not (req(f'{G}/{vg_id}/vm-attachments')[2].get('data') or [])   # stop if still attached
delete(f'{G}/{vg_id}', get(f'{G}/{vg_id}')[1])                            # fresh ETag; task VolumeGroupDelete
print(get(f'{G}/{vg_id}'))                                               # expect 404
PY
```

`vg_id` stays empty with its guard until I put the `extId` from the plan into it. The `If-Match` ETag is required; without it the call is a 428, and a non-numeric ETag (`:NA==`) is still valid.

I repeat that block for each group of the plan.

### Step 5 — done when

I run the audit and the capacity block again. Done when the audit `counts` are 0 for every kind and the groups are gone (a fresh `list_all` no longer holds them, and `GET` gives 404). I report the new free GiB next to the old figure.

How fast the freed space shows in `capacity()` is **not in the skills**. So I re-run the capacity block and report the real figure instead of claiming an amount.

One note, because it changes the size of this job: the delete keeps the groups of the platform apps too. With Ultimate that is most of the 20. None of them is needed by a deleted cluster.

---

Skipped: no live cluster or Prism Central was reachable in this run (eval task), so every block above is shown, not executed, and all output statements are expected values from the skill tags. Risk: the management cluster name, workspace namespaces, and the two workload cluster names are unknown — the answers ask for them instead of guessing, so nothing can run with a wrong target.
