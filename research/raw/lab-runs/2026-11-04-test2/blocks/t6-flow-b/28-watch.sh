# READ-ONLY  (did the Flow release retry after the namespace existed?)
source ~/nkp-skilltest-flow-b.env 2>/dev/null
echo "== flow HCP condition =="
hcp=$(kubectl --kubeconfig "$MGMT_KUBECONFIG" --request-timeout=30s -n "$WORKSPACE_NS" get helmchartproxies --no-headers 2>/dev/null | awk '/flow-cni/{print $1}')
kubectl --kubeconfig "$MGMT_KUBECONFIG" --request-timeout=30s -n "$WORKSPACE_NS" get helmchartproxy "$hcp" -o jsonpath='{range .status.conditions[*]}{.type}={.status} {.reason}{"\n"}{end}' 2>&1 | head -4
echo "== flow HRP =="
kubectl --kubeconfig "$MGMT_KUBECONFIG" --request-timeout=30s -n "$WORKSPACE_NS" get helmreleaseproxies -o custom-columns='NAME:.metadata.name,CHART:.spec.chartName,READY:.status.conditions[?(@.type=="Ready")].status' --no-headers 2>&1 | grep -E 'flow|helm'
echo "== flow HRP message (tail) =="
kubectl --kubeconfig "$MGMT_KUBECONFIG" --request-timeout=30s -n "$WORKSPACE_NS" get helmreleaseproxy -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{range .status.conditions[*]}  {.type}={.status} {.message}{"\n"}{end}{end}' 2>&1 | grep -A3 flow-cni | head -8
echo "== workload: namespaces and flow pods =="
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" --request-timeout=30s get ns 2>&1 | grep -E 'flow|ovn'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" --request-timeout=30s get pods -A 2>&1 | grep -E 'flow|ovn|multus' | head -12
echo "== nodes =="; kubectl --kubeconfig "$CLUSTER_KUBECONFIG" --request-timeout=30s get nodes --no-headers 2>&1 | awk '{print "  "$2}' | sort | uniq -c
