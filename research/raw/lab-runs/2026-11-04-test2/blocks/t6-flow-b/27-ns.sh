# CHANGES  (creates namespace flow-cni-system on workload cluster skilltest-flow-b only; the chart's hook needs it because CAREN releases the chart into kube-system)
source ~/nkp-skilltest-flow-b.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" --request-timeout=30s get ns flow-cni-system 2>/dev/null && echo "already there" || \
  kubectl --kubeconfig "$CLUSTER_KUBECONFIG" --request-timeout=30s create namespace flow-cni-system
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" --request-timeout=30s get ns 2>&1 | grep -E 'flow|ovn|NAME'
