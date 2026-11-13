# CHANGES  (creates the namespace, the PVC, the pod, and the LoadBalancer Service)
source ~/nkp-skilltest-flow-a.env 2>/dev/null
ns='skilltest-smoke'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" --request-timeout=60s create namespace "$ns"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" --request-timeout=60s -n "$ns" apply --dry-run=server -f "$PWD/$CLUSTER_NAME-smoke.yaml" && kubectl --kubeconfig "$CLUSTER_KUBECONFIG" --request-timeout=60s -n "$ns" apply -f "$PWD/$CLUSTER_NAME-smoke.yaml"
echo "RC=$?"
