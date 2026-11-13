# READ-ONLY
source ~/nkp-site.env 2>/dev/null
source ~/nkp-skilltest-flow-a.env 2>/dev/null
KC="--request-timeout=30s"
echo "--- vars"
for v in CLUSTER_NAME WORKSPACE_NS CP_VIP LB_IP_RANGE CLUSTER_KUBECONFIG MGMT_KUBECONFIG; do
  if [ -n "$(printenv "$v")" ]; then echo "set: $v"; else echo "MISSING: $v"; fi
done
echo "--- D1 nkpcluster"
kubectl --kubeconfig "$MGMT_KUBECONFIG" $KC -n "$WORKSPACE_NS" get nkpcluster "$CLUSTER_NAME" -o custom-columns='NAMESPACE:.metadata.namespace,NAME:.metadata.name,MGMT:.metadata.labels.kommander\.d2iq\.io/host,PHASE:.status.phase,CP:.spec.capiCluster.topology.controlPlane.replicas' 2>&1
kubectl --kubeconfig "$MGMT_KUBECONFIG" $KC get nkpclusters -A 2>&1
echo "--- D2 workload: nodes / ns / pvc / pv / LB"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" $KC get nodes 2>&1 | head -20
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" $KC get ns 2>&1
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" $KC get pvc -A 2>&1
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" $KC get pv -o custom-columns='NAME:.metadata.name,NS:.spec.claimRef.namespace,PVC:.spec.claimRef.name,SIZE:.spec.capacity.storage,HANDLE:.spec.csi.volumeHandle' 2>&1
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" $KC get svc -A --field-selector spec.type=LoadBalancer 2>&1
echo "--- D2 child clusters?"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" $KC get nkpclusters -A 2>&1
echo "--- workspace namespace objects of this cluster (mgmt)"
kubectl --kubeconfig "$MGMT_KUBECONFIG" $KC -n "$WORKSPACE_NS" get helmchartproxies,helmreleaseproxies 2>&1
kubectl --kubeconfig "$MGMT_KUBECONFIG" $KC -n "$WORKSPACE_NS" get secrets 2>&1
kubectl --kubeconfig "$MGMT_KUBECONFIG" $KC -n "$WORKSPACE_NS" get kommanderclusters.apps.kommander.d2iq.io 2>&1
kubectl --kubeconfig "$MGMT_KUBECONFIG" $KC -n "$WORKSPACE_NS" get appdeployments 2>&1 | head -20
echo "--- operator host files"
for f in "$HOME/nkp-$CLUSTER_NAME-create.sh" "$HOME/nkp-$CLUSTER_NAME-patch.json" "$HOME/nkp-$CLUSTER_NAME-nodepool.sh" "$HOME/nkp-$CLUSTER_NAME-nodepool-dryrun.yaml" "$HOME/nkp-$CLUSTER_NAME-inventory.yaml" "$PWD/$CLUSTER_NAME-dryrun.yaml" "$PWD/$CLUSTER_NAME-dryrun.err" "$PWD/$CLUSTER_NAME-metallb-conf.yaml" "$PWD/$CLUSTER_NAME-bootstrap.conf" "$HOME/nkp-$CLUSTER_NAME-create.log" "$HOME/nkp-$CLUSTER_NAME-delete.log" "$CLUSTER_KUBECONFIG" "$HOME/nkp-$CLUSTER_NAME.env"; do [ -e "$f" ] && ls -l "$f"; done; true
echo "--- name grep HOME + PWD"
ls -a "$HOME" "$PWD" 2>/dev/null | grep -F -- "$CLUSTER_NAME"
echo "--- pwd"
pwd
