# Delete a cluster

Use this file from skill `nkp-cluster-lifecycle`. A delete removes the VMs, the disks of the nodes, and all data in the cluster. You cannot undo it. Do every step in order.

## D1. Identify the cluster

Do `SKILL.md` step 1. Use `kubectl get nkpclusters`, not `nkp get clusters`, to find the name and the namespace. [pdf p.814] `nkp delete cluster` uses namespace `kommander` when you do not give `--namespace`. [live 2.19.0] All blocks give `--namespace "$WORKSPACE_NS"`.

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get nkpcluster "$CLUSTER_NAME" -o custom-columns='NAMESPACE:.metadata.namespace,NAME:.metadata.name,MGMT:.metadata.labels.kommander\.d2iq\.io/host,PHASE:.status.phase,CP:.spec.capiCluster.topology.controlPlane.replicas'
kubectl --kubeconfig "$MGMT_KUBECONFIG" get nkpclusters -A
```

- `MGMT` `true`, or `NAMESPACE` `kommander`: this is the management cluster. [live 2.19.0] Go to D4.
- Otherwise it is a workload cluster. Go to D2.
- An attached cluster (NKP did not create it) is not deleted with this file. `nkp detach cluster` only removes it from NKP. Its workloads stay. [pdf p.496]

## D2. Safety gate (workload cluster)

Collect the facts for the plan. Run this block from the folder where you ran the create (D5 needs the same folder).

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get nodes
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get ns
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get pvc -A
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get pv -o custom-columns='NAME:.metadata.name,NS:.spec.claimRef.namespace,PVC:.spec.claimRef.name,SIZE:.spec.capacity.storage,HANDLE:.spec.csi.volumeHandle'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get svc -A --field-selector spec.type=LoadBalancer
```

- Keep the PV list in the plan. D5 uses it. Each PV of the Nutanix CSI is one volume group in Prism Central. `HANDLE` is `NutanixVolumes-<uuid>`; the `<uuid>` is the `extId` of the volume group. [live 2.19.0]
- Put `NS` and `PVC` in two columns. A `custom-columns` path with a `/` between two fields prints `<none>`. [live 2.19.0]

Does this cluster manage other clusters?

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get nkpclusters -A
```

- `error: the server doesn't have a resource type "nkpclusters"`: the pass case. The NKPCluster type exists only on a management cluster. The cluster is not broken. Continue. [live 2.19.0]
- `No resources found`: the pass case. Continue.
- A list of NKPClusters: stop.

Stop and tell the user when one of these is true:
- The second block lists an NKPCluster. Then this cluster manages other clusters. Delete those first. [pdf p.718]
- PVCs hold data that the user needs. A backup is in skill `nkp-storage-backup` (file `velero.md` B3). Ask the user to confirm the backup, or to confirm that the data can go.
- The user did not name this exact cluster.

The plan has:
1. The command (D3), the cluster name, the namespace, and the management cluster.
2. What goes: all nodes and VMs, all pods, all `LoadBalancer` services (the list above), and the access to all PVC data in the cluster. [pdf p.814][live 2.19.0]
3. What stays: see D5. With PVCs: one volume group for each PV stays in Prism Central, with its data, until the D5 cleanup.
4. The user types `yes` **and the exact cluster name** in one message. A message without the name is not approval.

## D3. Delete a workload cluster

```bash
# CHANGES  (deletes the workload cluster: its VMs, nodes, and data; cannot be undone)
source ~/nkp-<cluster>.env 2>/dev/null
nkp delete cluster --cluster-name "$CLUSTER_NAME" --namespace "$WORKSPACE_NS" --kubeconfig "$MGMT_KUBECONFIG" --timeout 30m
```

Output of a 2.19.0 workload delete (3 steps, then RC 0): [live 2.19.0]

```text
 • Deleting cluster resources for Cluster <namespace>/<cluster>...
 ✓ Deleting cluster resources for Cluster <namespace>/<cluster>
 • Waiting for cluster to be fully deleted...
 ✓ Waiting for cluster to be fully deleted
INF Deleted <namespace>/<cluster> cluster
```

- The guide also shows "Deleting Services with type LoadBalancer" and "Deleting ClusterResourceSets". [pdf p.814] 2.19.0 did not print these lines, but the `LoadBalancer` services went. [live 2.19.0] Do not wait for them.
- Time: 28 s for 5 nodes without PVCs, 57 s for 7 nodes with PVCs. [live 2.19.0] The 30m timeout is a safety limit.
- `--delete-kubernetes-resources=false` skips the `LoadBalancer` delete (default `true`). [live 2.19.0] Use it only when the API server of the cluster does not answer, and only after the user agrees.
- The default `--timeout` is 15m. [live 2.19.0] The block uses 30m.
- The guide prefers the NKP UI for a managed cluster delete. [pdf p.496] The CLI is for the agent.

Check. Run it after RC 0. If an object stays, wait 30 s (`sleep 30`) and run it again:

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get nkpclusters,clusters.cluster.x-k8s.io,machines -l "cluster.x-k8s.io/cluster-name=$CLUSTER_NAME"
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get nkpcluster "$CLUSTER_NAME"
```

The NKPCluster was `NotFound` 82 s after RC 0. [live 2.19.0]

The IPs of the cluster must stop answering:

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
ping -c 2 -W 2 "$CP_VIP"
curl -sk -o /dev/null -w '%{http_code}\n' --max-time 5 "https://${LB_IP_RANGE%%-*}/"
```

Done when:
- Both kubectl commands show no object for the cluster ("No resources found" or "NotFound").
- `ping` gets no reply and `curl` prints `000`. [live 2.19.0] If the network blocks ICMP, `ping` proves nothing; `curl` is the proof. A cluster in a VPC: the operator host outside the VPC cannot reach these private IPs. Use the floating IPs (D5).

Then do D5.

**The NKPCluster stays, or the UI shows it in an `Error` state** [pdf p.496]: not seen on 2.19.0 [live 2.19.0]. Do this only when the NKPCluster still exists 10 minutes after RC 0. First check that the machines are gone (first check block). Only then:

```bash
# CHANGES  (deletes the NKPCluster object on the management cluster)
source ~/nkp-<cluster>.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" delete nkpcluster "$CLUSTER_NAME" --wait=false
```

The NKPCluster has the finalizers `capicluster-cleanup` and `kommandercluster-cleanup`. [live 2.19.0] The guide removes them when the object stays. [pdf p.497] A finalizer removal skips the cleanup, so VMs can stay in Prism Central. Do not remove finalizers while machines exist. For that case, use skill `nkp-troubleshooting`.

## D4. Delete the management cluster

- Delete all workload clusters first (D2, D3, D5 for each). After the management cluster is gone, NKP cannot delete them. [pdf p.496]
- A self-managed cluster cannot delete itself. `nkp delete cluster --self-managed` moves the CAPI resources to a bootstrap cluster on the operator host, then deletes the cluster. [live 2.19.0][pdf p.832] The operator host needs the bootstrap requirements of skill `nkp-install` (container engine, 4 CPU and 4 GB free).
- Air-gapped site: add `--bootstrap-cluster-image` with the `konvoy-bootstrap-image-*.tar` file of the bundle. [live 2.19.0]

Run the first D2 block (the facts, with the PV list). Then:

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" get nkpclusters -A
ls "$BUNDLE_DIR"/konvoy-bootstrap-image-*.tar
```

The first command must list only the management cluster. If it lists more, stop. The plan has the D2 items, and says that Kommander, the NKP UI, and all platform apps go too. A management cluster has many PVCs (3 with Starter, 20 with Ultimate, 340 Gi). [live 2.19.0] Approval: `yes` and the exact cluster name.

```bash
# CHANGES  (deletes the management cluster in a tmux session; makes a kind bootstrap cluster on this host; cannot be undone)
source ~/nkp-<cluster>.env 2>/dev/null
: "${CLUSTER_NAME:?}"
tmux new-session -d -s "nkp-$CLUSTER_NAME-delete" -c "$PWD" "bash -c 'umask 077; source ~/nkp-$CLUSTER_NAME.env 2>/dev/null; nkp delete cluster --self-managed --cluster-name \"\$CLUSTER_NAME\" --namespace \"\$WORKSPACE_NS\" --kubeconfig \"\$MGMT_KUBECONFIG\" --timeout 60m \${BUNDLE_DIR:+--bootstrap-cluster-image \"\$(ls \"\$BUNDLE_DIR\"/konvoy-bootstrap-image-*.tar)\"} > ~/nkp-$CLUSTER_NAME-delete.log 2>&1; echo RC=\$? >> ~/nkp-$CLUSTER_NAME-delete.log'"
```

The delete runs in tmux, so a lost terminal does not stop the move. On a connected site without `BUNDLE_DIR`, the block uses the default bootstrap image. Read the log every few minutes (READ-ONLY): `source ~/nkp-<cluster>.env 2>/dev/null && tail -n 5 "$HOME/nkp-$CLUSTER_NAME-delete.log"`. Done when the log ends with `RC=0`.

Output (each step prints `•` at the start and `✓` at the end), in this order: [live 2.19.0]

```text
Loading bootstrap image from archive
Creating a bootstrap cluster
Installing CAPI Stack operators
Creating CAPI components
Creating ClusterClass resources
Creating NKPCluster resources
Creating ClusterClass resources
Moving cluster resources
You can now view resources in the moved cluster by using the --kubeconfig flag with kubectl.
For example: kubectl --kubeconfig="<cluster>-bootstrap.conf" get nodes
Waiting for cluster in kommander/<cluster>
Waiting for cluster infrastructure to be ready
Waiting for cluster control-planes to be ready
Waiting for machines to be ready
Deleting cluster resources for Cluster kommander/<cluster>
Waiting for cluster to be fully deleted
Deleted kommander/<cluster> cluster
Deleting bootstrap cluster
```

- Time: 5–10 min for 3 control-plane and 4 worker nodes (Starter 5 min 6 s, Ultimate 7 min 4 s). [live 2.19.0] The longest steps are at the end: the move (about 90 s) and "Waiting for cluster to be fully deleted" (1–3 min; longer with more PVCs).
- The `<cluster>-bootstrap.conf` file that the output names goes away with the bootstrap cluster. [live 2.19.0] Do not use it.
- No NKPCluster object stays: the management cluster that holds it is gone. The `Error` step of D3 does not apply to D4. [live 2.19.0]

After the delete, check for a bootstrap cluster or a file that stays:

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
docker ps -a --format '{{.Names}}'
ls -l "$PWD/$CLUSTER_NAME-bootstrap.conf"
```

- Use `docker ps -a`: a stopped container does not show in `docker ps`. On Podman, use `podman ps -a`.
- Done when: no name has `bootstrap` in it, and `ls` prints "No such file or directory". [live 2.19.0]
- If a name has `bootstrap` in it, remove it with `nkp delete bootstrap` (CHANGES, skill `nkp-install`). If the file stays, D5 removes it.
- Run the IP check block of D3. Then do D5.

## D5. What stays after a delete, and the cleanup

What stays: [live 2.19.0]
- **Volume groups of the PVCs.** `nkp delete cluster` deletes the node VMs and their disks. It does **not** delete the PVCs. It keeps one Nutanix CSI volume group for each PV, of the user and of the platform apps, with the data. Prism Central removes their VM attachments when it deletes the VMs. Seen: Starter management cluster 3, Ultimate management cluster 20 (340 Gi), Ultimate workload cluster with one user PVC 4, workload cluster without PVCs 0. A cluster with no PV in the D2 list leaves no volume group. (On AWS, the guide says that PVs stay too. [pdf p.833])
- **Mirror Secrets of a workload cluster.** On the management cluster, in the workspace namespace of the workload cluster: `<cluster>-oci-cert` and `<cluster>-oci-creds`. They hold the registry mirror credentials. The other Secrets in that namespace belong to the workspace. Leave them.
- **Cluster in a VPC**: the VPC, subnets, and floating IPs stay. A floating IP stays `ASSOCIATED_TO_PRIVATE_IP` on a private IP that no VM holds. It answers `000` until skill `nkp-vpc`, step 7, removes it. This is normal, not a fault.
- **Flow CNI cluster**: the user HelmChartProxy of Flow CNI stays on the management cluster. Remove it with skill `nkp-flow-cni` (N-36).
- **Metal hosts**: [metal.md](metal.md), section MT5.
- **Operator host files**: the cluster env file, the kubeconfig file, the create script and its logs, the patch and node pool files, and the dry-run files (`.yaml` holds Secrets, `.err`). The IPs `CP_VIP` and `LB_IP_RANGE` are free again.
- **Prism Central images** stay. Other clusters can use them.

Do the cleanup in this order. The cluster env file goes last, because the other steps read their names from it. Show one plan with the items that apply; run each CHANGES block only after "yes".

### D5.1 Mirror Secrets (workload cluster only)

After a management cluster delete, skip this step: the namespaces went with the cluster.

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get secret "$CLUSTER_NAME-oci-cert" "$CLUSTER_NAME-oci-creds"
```

`WORKSPACE_NS` comes from the env file of the **workload** cluster. Never use the value of the management cluster (`kommander`): there the Secrets are `NotFound`, and they still stay. "NotFound" for both: the cluster had no mirror flags. Go to D5.2.

```bash
# CHANGES  (deletes the 2 mirror Secrets of the deleted workload cluster on the management cluster)
source ~/nkp-<cluster>.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" delete secret "$CLUSTER_NAME-oci-cert" "$CLUSTER_NAME-oci-creds" --ignore-not-found
```

Done when: the READ-ONLY block prints `NotFound` for both.

### D5.2 Volume groups in Prism Central (only when the D2 PV list was not empty)

Order: **delete the cluster first, then the volume groups.** Before the delete, the groups are attached to the node VMs and hold live data.

**Never match a group by name.** Every Nutanix CSI volume group is named `pvc-<pvc-uid>`, and one Prism Central holds the groups of every cluster that uses it. Measured on a lab Prism Central with 4 clusters: 75 groups, all named `pvc-…`, 21 of them this cluster's. A search for the cluster name finds nothing, because the group `name` does not contain it. [live 2.19.1]

The group `description` is the key. It has this form: [live 2.19.1]

```text
FS:ext4, K8sClusterID:<uid>, CSIVersion:v3.9.0, DeploymentType:non-bare-metal,
CSI StorageClass nutanix-volume for <cluster>, PVC:<pvc>, NS:<ns>, POD:<pod>, SA:<default>
```

`<uid>` is the `kube-system` namespace UID of the cluster. It and the `for <cluster>,` marker survive the delete, so the full set can be found **after** the cluster is gone. Check all four gates:

| Gate | Check | Why |
|---|---|---|
| A. Cluster identity | `K8sClusterID:<uid>` in the description equals the `kube-system` UID recorded before the delete | The complete set. It also catches PVCs made after any list was captured |
| B. Name marker | `for <cluster>,` in the description (with the comma) | A second, independent identity key |
| C. Not internal | `isHidden` and `usageType` `INTERNAL` are false | A Prism Central group is never a PVC group |
| D. Detached | the `attachments` field is an empty list | A group with a VM attachment belongs to a live VM |

**Do not use the PV list as the primary source.** A PVC made after the capture leaves a group that the PV list does not have. Seen: 12 PVs at the capture, 21 groups after a license upgrade deployed more platform apps. The PV list is a **cross-check**: each PV id must be in the identity set, and a group in the identity set that is not in the PV list is normal, not a fault.

1. Record the UID and the PV list **immediately before** the delete of D4. The cluster is the only place that holds the UID.

```bash
# CHANGES  (writes the volume-group whitelist file; run before the delete; changes nothing in the cluster)
source ~/nkp-<cluster>.env 2>/dev/null
wl="$HOME/nkp-$CLUSTER_NAME-vg-whitelist.txt"
{
  echo "# $CLUSTER_NAME kube-system-uid: $(kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get ns kube-system -o jsonpath='{.metadata.uid}')"
  kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get pv -o jsonpath='{range .items[*]}{.spec.csi.volumeHandle}{" "}{.spec.claimRef.namespace}{"/"}{.spec.claimRef.name}{"\n"}{end}' \
    | sed -n 's/^NutanixVolumes-\([0-9a-f-]*\) /\1 /p' | sort
} > "$wl"
cat "$wl"
```

2. After the delete, list the groups that pass gates A, B, C, and D. Show the plan: the count, and for each group the `extId`, the PVC, and the namespace. Stop for "yes".

```bash
# READ-ONLY  (lists this cluster's volume groups; deletes nothing)
source ~/nkp-<cluster>.env 2>/dev/null
curl -sk --netrc-file <(printf 'machine %s login %s password %s\n' "${PC_ENDPOINT#https://}" "$(printenv NUTANIX_USER)" "$(printenv NUTANIX_PASSWORD)") "${PC_ENDPOINT%/}/api/volumes/v4.0/config/volume-groups?\$limit=100" -o /tmp/vg.json
python3 - "$HOME/nkp-$CLUSTER_NAME-vg-whitelist.txt" "$CLUSTER_NAME" <<'PY'
import json,re,sys
wl,cl=sys.argv[1],sys.argv[2]
uid=re.search(r'kube-system-uid: (\S+)',open(wl).read()).group(1)
pv={l.split()[0] for l in open(wl) if not l.startswith('#') and l.strip()}
for g in json.load(open('/tmp/vg.json'))["data"]:
    desc=g.get("description") or ""
    if uid not in desc or f"for {cl}," not in desc: continue
    if g.get("isHidden") or (g.get("attachments") or []): continue
    pvc=re.search(r'PVC:(\S+?),',desc); ns=re.search(r'NS:(\S+?),',desc)
    print(g["extId"], "in-pv-list" if g["extId"] in pv else "late", pvc.group(1) if pvc else "-", ns.group(1) if ns else "-")
PY
```

`$limit` has a maximum of 100; a larger value gives `400`. On a 2.19 Prism Central the `v2.0` group endpoints do not answer: `volume_groups/list` gives `405` and `volumes/list` gives `404`. [live 2.19.1]

3. Delete one group at a time. The `DELETE` needs the `If-Match` ETag of a fresh `GET` **and** an `NTNX-Request-Id` header; without it the API gives `400 Missing Request Id header`. It answers `202` with a task, and the group stays until the task ends, about 3 s. Poll the `GET` until `404`. A `200` right after the `DELETE` is not a failure. [live 2.19.1]

```bash
# CHANGES  (deletes one volume group and its data; cannot be undone)
source ~/nkp-site.env 2>/dev/null
: "${vgext:?}"
u="${PC_ENDPOINT%/}/api/volumes/v4.0/config/volume-groups/$vgext"
et=$(curl -sk --netrc-file <(printf 'machine %s login %s password %s\n' "${PC_ENDPOINT#https://}" "$(printenv NUTANIX_USER)" "$(printenv NUTANIX_PASSWORD)") -D - -o /tmp/vg1.json "$u" | tr -d '\r' | awk -F': ' 'tolower($1)=="etag"{print $2}')
grep -q 'K8sClusterID:' /tmp/vg1.json && grep -q '"attachments": \[\]' /tmp/vg1.json && echo "gates ok" || echo "STOP: gate failed"
curl -sk --netrc-file <(printf 'machine %s login %s password %s\n' "${PC_ENDPOINT#https://}" "$(printenv NUTANIX_USER)" "$(printenv NUTANIX_PASSWORD)") -X DELETE -H "If-Match: $et" -H "NTNX-Request-Id: $(cat /proc/sys/kernel/random/uuid)" -o /dev/null -w 'delete: %{http_code}\n' "$u"
sleep 5
curl -sk --netrc-file <(printf 'machine %s login %s password %s\n' "${PC_ENDPOINT#https://}" "$(printenv NUTANIX_USER)" "$(printenv NUTANIX_PASSWORD)") -o /dev/null -w 'after: %{http_code}\n' "$u"
```

4. Run step 2 again, once for each group of the plan. Done when it prints nothing, and the total count of `GET …/volume-groups?$limit=100` fell by exactly the number of groups in the plan.

The companion skill `nutanix-storage` has the same procedure as Python recipes, under "What an NKP cluster leaves behind" and "Delete a volume group". For a wider check (VMs, floating IPs, IP reservations, categories), use skill `nutanix-nkp`, RECIPES.md "Leftover audit for a cluster" (READ-ONLY).

### D5.3 VPC objects

Cluster in a VPC: do skill `nkp-vpc`, step 7, now, before D5.4, because D5.4 removes the cluster env file.

### D5.4 Operator host files

Run these blocks from the folder where you ran the create: the dry-run files are in `$PWD`. List the files of the cluster. The list has exact names. Never use a `*` after the cluster name: `nkp-dev-*` also matches the files of cluster `dev-01`.

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
for f in "$HOME/nkp-$CLUSTER_NAME-create.sh" "$HOME/nkp-$CLUSTER_NAME-patch.json" "$HOME/nkp-$CLUSTER_NAME-nodepool.sh" "$HOME/nkp-$CLUSTER_NAME-nodepool-dryrun.yaml" "$HOME/nkp-$CLUSTER_NAME-inventory.yaml" "$PWD/$CLUSTER_NAME-dryrun.yaml" "$PWD/$CLUSTER_NAME-dryrun.err" "$PWD/$CLUSTER_NAME-metallb-conf.yaml" "$PWD/$CLUSTER_NAME-bootstrap.conf" "$HOME/nkp-$CLUSTER_NAME-create.log" "$HOME/nkp-$CLUSTER_NAME-delete.log" "$CLUSTER_KUBECONFIG" "$HOME/nkp-$CLUSTER_NAME.env"; do [ -e "$f" ] && ls -l "$f"; done; true
ls -a "$HOME" "$PWD" | grep -F -- "$CLUSTER_NAME"
```

- The second command finds files that the first list does not name (for example a test manifest). Show them to the user. Remove such a file only when the user names it.
- The name match also finds files of a cluster with a longer name (`dev-01` matches `dev-010`). Do not remove those.

Show the list as the plan. Remove the files only after "yes":

```bash
# CHANGES  (deletes the local files of the deleted cluster)
source ~/nkp-<cluster>.env 2>/dev/null
: "${CLUSTER_NAME:?}"
rm -f -- "$HOME/nkp-$CLUSTER_NAME-create.sh" "$HOME/nkp-$CLUSTER_NAME-patch.json" "$HOME/nkp-$CLUSTER_NAME-nodepool.sh" "$HOME/nkp-$CLUSTER_NAME-nodepool-dryrun.yaml" "$HOME/nkp-$CLUSTER_NAME-inventory.yaml" "$PWD/$CLUSTER_NAME-dryrun.yaml" "$PWD/$CLUSTER_NAME-dryrun.err" "$PWD/$CLUSTER_NAME-metallb-conf.yaml" "$PWD/$CLUSTER_NAME-bootstrap.conf" "$HOME/nkp-$CLUSTER_NAME-create.log" "$HOME/nkp-$CLUSTER_NAME-delete.log" ${CLUSTER_KUBECONFIG:+"$CLUSTER_KUBECONFIG"}; rm -f -- "$HOME/nkp-$CLUSTER_NAME.env"
```

- The `;` makes sure that the env file goes in all cases. Do not change it to `&&`.
- On the management cluster, `CLUSTER_KUBECONFIG` is the same file as `MGMT_KUBECONFIG`.
- Done when: the READ-ONLY list block prints nothing.

### D5.5 The site file after a management cluster delete

Never remove `~/nkp-site.env`. After a management cluster delete, `MGMT_KUBECONFIG` in it points to the deleted cluster or to a removed file. The file can have more than one `MGMT_KUBECONFIG` line. The last line wins.

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
grep -n '^export MGMT_KUBECONFIG=' ~/nkp-site.env
test -f "$MGMT_KUBECONFIG" && echo "MGMT_KUBECONFIG: file found" || echo "MGMT_KUBECONFIG: no file"
```

- Symptom: every block that uses `MGMT_KUBECONFIG` fails with `Unable to connect to the server: context deadline exceeded`, `no route to host`, or `no such file or directory`. [live 2.19.0]
- Tell the user: no block that uses `MGMT_KUBECONFIG` works until a new management cluster exists. Do not write a placeholder value (rule 4).
- Fix: after the next management cluster create, skill `nkp-install`, step "Set the kubeconfig variables", appends the new line. Then the check above prints `file found`.
