# READ-ONLY
source ~/nkp-skilltest-flow-a.env 2>/dev/null
echo "== pods not Running =="
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" --request-timeout=30s get pods -A 2>/dev/null | awk 'NR==1 || $4!="Running"' | head -12
echo "== kommander-flux pods =="
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" --request-timeout=30s -n kommander-flux get pods 2>/dev/null | head -12
echo "== helmreleases count on the workload cluster =="
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" --request-timeout=30s get helmreleases -A --no-headers 2>/dev/null | wc -l
echo "== flow-processor =="
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" --request-timeout=30s -n flow-cns-system get pods 2>/dev/null
