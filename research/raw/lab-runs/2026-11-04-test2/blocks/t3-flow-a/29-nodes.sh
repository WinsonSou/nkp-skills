# READ-ONLY
source ~/nkp-skilltest-flow-a.env 2>/dev/null
date '+%H:%M:%S'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" --request-timeout=30s get nodes -o wide 2>&1 | head -10
echo "== HCP condition =="
kubectl --kubeconfig "$MGMT_KUBECONFIG" --request-timeout=30s -n "$WORKSPACE_NS" get helmchartproxy "$CLUSTER_NAME-flow-cni" -o jsonpath='{range .status.conditions[*]}{.type}={.status} {.reason}: {.message}{"\n"}{end}' 2>/dev/null | head -5
echo "== flow HRP condition =="
kubectl --kubeconfig "$MGMT_KUBECONFIG" --request-timeout=30s -n "$WORKSPACE_NS" get helmreleaseproxies -o jsonpath='{range .items[?(@.spec.chartName=="nutanix-flow-cni")]}{.metadata.name}{"\n"}{range .status.conditions[*]}  {.type}={.status} {.reason}: {.message}{"\n"}{end}{end}' 2>/dev/null | head -12
