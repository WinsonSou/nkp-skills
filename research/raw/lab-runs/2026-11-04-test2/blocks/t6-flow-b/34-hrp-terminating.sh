# READ-ONLY  (is the old Flow HRP terminating? did CAAPH make a new one?)
source ~/nkp-skilltest-flow-b.env 2>/dev/null
K="kubectl --kubeconfig $MGMT_KUBECONFIG --request-timeout=30s"
$K -n "$WORKSPACE_NS" get helmreleaseproxies -o jsonpath='{range .items[*]}{.metadata.name}{"  created="}{.metadata.creationTimestamp}{"  deleting="}{.metadata.deletionTimestamp}{"  finalizers="}{.metadata.finalizers}{"\n"}{end}' 2>&1 | grep flow || echo "  no flow HRP"
echo "== the HCP still there? =="
$K -n "$WORKSPACE_NS" get helmchartproxies --no-headers 2>&1 | grep flow
echo "== caaph controller =="
$K -n caaph-system get pods --no-headers 2>&1 | awk '{print "  "$1, $2, $3}'
echo "== workload: hook job and namespaces =="
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" --request-timeout=30s get jobs -A 2>&1 | grep -E 'NAME|crd-hook' | head -5
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" --request-timeout=30s get ns --no-headers 2>&1 | awk '{print "  "$1, $2}'
