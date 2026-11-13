# READ-ONLY
source ~/nkp-skilltest-flow-a.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" --request-timeout=30s -n kube-system get ds registry-hosts-fix
for p in $(kubectl --kubeconfig "$CLUSTER_KUBECONFIG" --request-timeout=30s -n kube-system get pods -l app=registry-hosts-fix -o name | head -2); do
  echo "== $p =="; kubectl --kubeconfig "$CLUSTER_KUBECONFIG" --request-timeout=30s -n kube-system logs "$p" 2>&1 | tail -5
done
