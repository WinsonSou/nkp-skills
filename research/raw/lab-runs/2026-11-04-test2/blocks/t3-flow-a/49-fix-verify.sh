# READ-ONLY
source ~/nkp-skilltest-flow-a.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" --request-timeout=30s -n kube-system get ds registry-hosts-fix
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" --request-timeout=30s -n kube-system get pods -l app=registry-hosts-fix -o custom-columns='NAME:.metadata.name,READY:.status.containerStatuses[0].ready,NODE:.spec.nodeName' | head -9
echo "== log of one fix pod =="
p=$(kubectl --kubeconfig "$CLUSTER_KUBECONFIG" --request-timeout=30s -n kube-system get pods -l app=registry-hosts-fix -o name | head -1)
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" --request-timeout=30s -n kube-system logs "$p" 2>&1 | head -3
