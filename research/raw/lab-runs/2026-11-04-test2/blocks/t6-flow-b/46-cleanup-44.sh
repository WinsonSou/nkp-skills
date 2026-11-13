# CHANGES  (deletes the registry-hosts-fix DaemonSet on skilltest-flow-b if the API answers; it goes with the cluster delete otherwise)
source ~/nkp-skilltest-flow-b.env 2>/dev/null
if kubectl --kubeconfig "$CLUSTER_KUBECONFIG" --request-timeout=15s get --raw /version >/dev/null 2>&1; then
  kubectl --kubeconfig "$CLUSTER_KUBECONFIG" --request-timeout=30s -n kube-system delete ds registry-hosts-fix --ignore-not-found
  echo "RC=$?"
else
  echo "workload API not reachable from the operator host; the DaemonSet goes with the cluster delete"
fi
