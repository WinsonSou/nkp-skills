# CHANGES  (creates workload cluster skilltest-flow-b with Flow CNI in its cluster config; Prism Central makes 7 VMs)
source ~/nkp-skilltest-flow-b.env 2>/dev/null
f="$HOME/$CLUSTER_NAME-dryrun.yaml"; test -s "$f" || { echo "no dry-run file"; exit 1; }
yq 'select(.kind == "NKPCluster")' "$f" | kubectl --kubeconfig "$MGMT_KUBECONFIG" --request-timeout=30s apply --server-side -f - -o name
echo "RC_apply=$?"
date '+%H:%M:%S applied'
for i in $(seq 1 6); do
  sleep 5
  kubectl --kubeconfig "$MGMT_KUBECONFIG" --request-timeout=30s -n "$WORKSPACE_NS" get nkpclusters "$CLUSTER_NAME" --no-headers 2>&1
  kubectl --kubeconfig "$MGMT_KUBECONFIG" --request-timeout=30s -n "$WORKSPACE_NS" get clusters.cluster.x-k8s.io,machines --no-headers 2>&1 | awk '{print "  " $1, $2}' | head -5
done
