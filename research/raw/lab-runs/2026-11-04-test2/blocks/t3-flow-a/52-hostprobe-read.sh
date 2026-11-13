# READ-ONLY
source ~/nkp-skilltest-flow-a.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" --request-timeout=30s -n default get pod hostprobe -o jsonpath='{.status.phase}{"\n"}'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" --request-timeout=30s -n default logs hostprobe 2>&1 | head -12
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" --request-timeout=60s -n default delete pod hostprobe --wait=false 2>&1 | head -1
