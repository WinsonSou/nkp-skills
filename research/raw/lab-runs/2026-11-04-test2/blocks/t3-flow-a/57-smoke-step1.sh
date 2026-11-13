# READ-ONLY  (C12 step 1)
source ~/nkp-skilltest-flow-a.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" --request-timeout=30s get storageclass
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" --request-timeout=30s -n metallb-system get ipaddresspools
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" --request-timeout=30s get svc -A --field-selector spec.type=LoadBalancer
