# READ-ONLY  (does CAREN make a Flow CNI HelmChartProxy, and how far is the cluster?)
source ~/nkp-skilltest-flow-b.env 2>/dev/null
echo "== nkpcluster =="
kubectl --kubeconfig "$MGMT_KUBECONFIG" --request-timeout=30s -n "$WORKSPACE_NS" get nkpclusters "$CLUSTER_NAME" -o custom-columns='NAME:.metadata.name,PHASE:.status.phase' --no-headers 2>&1
echo "== machines =="
kubectl --kubeconfig "$MGMT_KUBECONFIG" --request-timeout=30s -n "$WORKSPACE_NS" get machines -l "cluster.x-k8s.io/cluster-name=$CLUSTER_NAME" --no-headers 2>&1 | awk '{print "  "$1, $2}'
echo "== helmchartproxies in the workspace ns =="
kubectl --kubeconfig "$MGMT_KUBECONFIG" --request-timeout=30s -n "$WORKSPACE_NS" get helmchartproxies -o custom-columns='NAME:.metadata.name,CHART:.spec.chartName,VER:.spec.version,NS:.spec.namespace,SELECTOR:.spec.clusterSelector.matchLabels.cluster\.x-k8s\.io/cluster-name' 2>&1
echo "== helmreleaseproxies =="
kubectl --kubeconfig "$MGMT_KUBECONFIG" --request-timeout=30s -n "$WORKSPACE_NS" get helmreleaseproxies -o custom-columns='NAME:.metadata.name,CHART:.spec.chartName,CLUSTER:.spec.clusterRef.name,READY:.status.conditions[?(@.type=="Ready")].status' 2>&1 | grep -i -E 'flow|NAME' || echo "  no flow HRP yet"
echo "== all HRPs count =="
kubectl --kubeconfig "$MGMT_KUBECONFIG" --request-timeout=30s -n "$WORKSPACE_NS" get helmreleaseproxies --no-headers 2>&1 | wc -l
echo "== CAREN Flow addon objects (any kind, name or label with flow) =="
kubectl --kubeconfig "$MGMT_KUBECONFIG" --request-timeout=30s -n "$WORKSPACE_NS" get all,cm,secret,helmchartproxy,helmreleaseproxy 2>/dev/null | grep -i flow | head -10 || echo "  none"
echo "== cluster kubeconfig secret =="
kubectl --kubeconfig "$MGMT_KUBECONFIG" --request-timeout=30s -n "$WORKSPACE_NS" get secrets --no-headers 2>/dev/null | awk '{print $1}' | grep -E "^$CLUSTER_NAME-(kubeconfig|ca)$"
