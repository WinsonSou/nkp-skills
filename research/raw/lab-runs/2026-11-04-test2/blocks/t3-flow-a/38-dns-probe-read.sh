# READ-ONLY
source ~/nkp-skilltest-flow-a.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" --request-timeout=30s -n default get pod dnsprobe -o jsonpath='{.status.phase}{"\n"}'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" --request-timeout=30s -n default logs dnsprobe 2>&1 | head -30
