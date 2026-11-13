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

Use skill `nutanix-storage`, RECIPES.md:
1. "What an NKP cluster leaves behind" (READ-ONLY): it lists the groups of the cluster. It keeps a group only when the description has `for <cluster>,` (with the comma) and `K8sClusterID`, and `vm-attachments` is empty. It never takes a Prism Central group (`isHidden` or `INTERNAL`).
2. Compare the result with the D2 PV list (the `<uuid>` of `HANDLE` = `extId`). Show the plan: the count, and for each group the name, `extId`, PVC, and namespace. The delete destroys the PVC data. Stop for "yes".
3. "Delete a volume group" (CHANGES), for each group of the plan, after "yes".
4. Run step 1 again. Done when: it returns no group.

For a full check (VMs, volume groups, floating IPs, IP reservations, categories), use skill `nutanix-nkp`, RECIPES.md "Leftover audit for a cluster" (READ-ONLY). The recipes run on the operator host and read `PC_ENDPOINT`, `NUTANIX_USER`, `NUTANIX_PASSWORD` from `~/nkp-site.env`.

If skill `nutanix-storage` is not installed, the user does it in Prism Central: Storage, Volume Groups, search for the cluster name, check that each group has no VM attached, then delete. Give the user the D2 PV list.

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
