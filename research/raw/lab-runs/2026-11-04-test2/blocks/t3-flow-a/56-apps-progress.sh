# READ-ONLY
source ~/nkp-skilltest-flow-a.env 2>/dev/null
date '+%H:%M:%S'
kubectl --kubeconfig "$MGMT_KUBECONFIG" --request-timeout=30s -n "$WORKSPACE_NS" get helmchartproxy "$CLUSTER_NAME-flow-cni" -o jsonpath='{range .status.conditions[*]}{.type}={.status} {.reason}{"\n"}{end}' | head -3
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" --request-timeout=30s get helmreleases -A --no-headers 2>/dev/null | awk '{print $1}' | sort | uniq -c
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" --request-timeout=30s get helmreleases -A --no-headers 2>/dev/null | wc -l
echo "== not ready =="
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" --request-timeout=30s get helmreleases -A 2>/dev/null | awk 'NR==1 || $4!="True"' | head -12
kubectl --kubeconfig "$MGMT_KUBECONFIG" --request-timeout=30s -n "$WORKSPACE_NS" get nkpclusters -o custom-columns='NAME:.metadata.name,PHASE:.status.phase'
