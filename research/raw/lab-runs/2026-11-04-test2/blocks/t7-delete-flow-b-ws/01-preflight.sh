# READ-ONLY
source ~/nkp-skilltest-flow-b.env 2>/dev/null
set -u
echo "== env =="
for v in CLUSTER_NAME CP_VIP LB_IP_RANGE WORKSPACE_NS CLUSTER_KUBECONFIG MGMT_KUBECONFIG; do
  if [ -n "${!v:-}" ]; then echo "$v set"; else echo "$v MISSING"; fi
done
echo "== D1 nkpclusters =="
kubectl --kubeconfig "$MGMT_KUBECONFIG" get nkpclusters -A --request-timeout=30s
echo "== D1 this cluster =="
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get nkpcluster "$CLUSTER_NAME" -o custom-columns='NS:.metadata.namespace,NAME:.metadata.name,MGMT:.metadata.labels.kommander\.d2iq\.io/host,PHASE:.status.phase' --request-timeout=30s
echo "== workspaces =="
kubectl --kubeconfig "$MGMT_KUBECONFIG" get workspaces --request-timeout=30s
echo "== D2 nodes =="
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get nodes --request-timeout=30s
echo "== D2 pvc =="
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get pvc -A --request-timeout=30s
echo "== D2 pv =="
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get pv -o custom-columns='NAME:.metadata.name,NS:.spec.claimRef.namespace,PVC:.spec.claimRef.name,SIZE:.spec.capacity.storage,HANDLE:.spec.csi.volumeHandle' --request-timeout=30s
echo "== D2 LB =="
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get svc -A --field-selector spec.type=LoadBalancer --request-timeout=30s
echo "== D2 child clusters =="
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get nkpclusters -A --request-timeout=30s 2>&1 | head -3
echo "== workspace ns helmchartproxies =="
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get helmchartproxies --request-timeout=30s
echo "== workspace ns cm,secret with the cluster name =="
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get cm,secret --request-timeout=30s | grep -F -- "$CLUSTER_NAME"
echo "== operator host files =="
ls -l "$HOME" | grep -F -- "$CLUSTER_NAME"
