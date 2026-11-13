# READ-ONLY
source ~/nkp-skilltest-flow-a.env 2>/dev/null
date '+%H:%M:%S'
kubectl --kubeconfig "$MGMT_KUBECONFIG" --request-timeout=30s -n "$WORKSPACE_NS" get nkpclusters -o custom-columns='NAME:.metadata.name,PHASE:.status.phase'
kubectl --kubeconfig "$MGMT_KUBECONFIG" --request-timeout=30s -n "$WORKSPACE_NS" get clusters
kubectl --kubeconfig "$MGMT_KUBECONFIG" --request-timeout=30s -n "$WORKSPACE_NS" get machines -o custom-columns='NAME:.metadata.name,PHASE:.status.phase' 2>/dev/null | head -10
kubectl --kubeconfig "$MGMT_KUBECONFIG" --request-timeout=30s -n "$WORKSPACE_NS" get helmchartproxy "$CLUSTER_NAME-flow-cni" -o custom-columns='NAME:.metadata.name,STATUS:.status.conditions[?(@.type=="Ready")].status,REASON:.status.conditions[?(@.type=="Ready")].reason'
kubectl --kubeconfig "$MGMT_KUBECONFIG" --request-timeout=30s -n "$WORKSPACE_NS" get helmreleaseproxies -o custom-columns='NAME:.metadata.name,CLUSTER:.spec.clusterRef.name,CHART:.spec.chartName,VERSION:.spec.version,READY:.status.conditions[?(@.type=="Ready")].status' 2>/dev/null | head -8
