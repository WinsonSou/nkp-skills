# READ-ONLY  (delete progress and end state)
source ~/nkp-skilltest-flow-b.env 2>/dev/null
echo "== delete log (filtered) =="
tail -n 12 "$HOME/nkp-$CLUSTER_NAME-delete.log" 2>&1 | grep -v -i -E 'password|token|secret'
echo "== objects left =="
kubectl --kubeconfig "$MGMT_KUBECONFIG" --request-timeout=30s -n "$WORKSPACE_NS" get nkpclusters,clusters.cluster.x-k8s.io,helmchartproxies,helmreleaseproxies --no-headers 2>&1 | grep -F -- "$CLUSTER_NAME" || echo "  none with the cluster name"
kubectl --kubeconfig "$MGMT_KUBECONFIG" --request-timeout=30s -n "$WORKSPACE_NS" get cm,secret --no-headers 2>&1 | grep -F -- "$CLUSTER_NAME" | awk '{print "  "$1, $2}' || echo "  none"
echo "== VIP / LB =="
curl -sk -o /dev/null -w ' cp_vip=%{http_code}\n' --max-time 5 "https://$CP_VIP:6443/version"
first=${LB_IP_RANGE%-*}; curl -sk -o /dev/null -w ' lb_first=%{http_code}\n' --max-time 5 "http://$first:80/"
