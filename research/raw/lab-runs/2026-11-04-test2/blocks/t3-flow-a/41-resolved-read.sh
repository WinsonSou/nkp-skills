# READ-ONLY
source ~/nkp-skilltest-flow-a.env 2>/dev/null
for p in "default dnsprobe-flow $CLUSTER_KUBECONFIG" "kommander dnsprobe-mgmt $MGMT_KUBECONFIG"; do
  set -- $p; echo "===== $2 ====="
  kubectl --kubeconfig "$3" --request-timeout=30s -n "$1" get pod "$2" -o jsonpath='{.status.phase}{"\n"}' 2>/dev/null
  kubectl --kubeconfig "$3" --request-timeout=30s -n "$1" logs "$2" 2>&1 | head -14
done
