# CHANGES  (deletes the exploration probe pod) then READ-ONLY status
source ~/nkp-skilltest-flow-a.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" --request-timeout=60s -n default delete pod dnsprobe --wait=false 2>&1 | head -2
echo "== pods not Running now =="
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" --request-timeout=30s get pods -A 2>/dev/null | awk 'NR==1 || $4!="Running"' | head -12
echo "== helmreleases on the workload cluster =="
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" --request-timeout=30s get helmreleases -A --no-headers 2>/dev/null | awk '{print $1, $2, $3, $4, $5}' | head -20
