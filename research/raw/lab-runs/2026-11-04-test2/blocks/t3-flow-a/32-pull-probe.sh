# READ-ONLY
source ~/nkp-skilltest-flow-a.env 2>/dev/null
echo "== pods not Running/Succeeded =="
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" --request-timeout=30s get pods -A --field-selector=status.phase!=Running,status.phase!=Succeeded 2>/dev/null
echo "== flow-processor events (last) =="
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" --request-timeout=30s -n flow-cns-system get events --sort-by=.lastTimestamp 2>/dev/null | tail -6
echo "== init containers of flow-processor =="
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" --request-timeout=30s -n flow-cns-system get pods -o jsonpath='{range .items[*]}{.metadata.name}{" init="}{.spec.initContainers[*].image}{" img="}{.spec.containers[*].image}{"\n"}{end}'
echo "== nodes ready =="
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" --request-timeout=30s get nodes --no-headers | awk '{print $1, $2}'
echo "== coredns config forward =="
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" --request-timeout=30s -n kube-system get cm coredns -o jsonpath='{.data.Corefile}' 2>/dev/null | head -12
