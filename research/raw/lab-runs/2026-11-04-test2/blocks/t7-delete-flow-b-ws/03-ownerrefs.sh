# READ-ONLY
source ~/nkp-skilltest-flow-b.env 2>/dev/null
echo "== HCP owner refs =="
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get helmchartproxies --request-timeout=30s -o custom-columns='NAME:.metadata.name,OWNER:.metadata.ownerReferences[0].kind,OWNERNAME:.metadata.ownerReferences[0].name'
echo "== HRP owner refs =="
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get helmreleaseproxies --request-timeout=30s -o custom-columns='NAME:.metadata.name,READY:.status.conditions[?(@.type=="Ready")].status,OWNER:.metadata.ownerReferences[0].kind'
echo "== objects with the cluster name, all namespaces (kinds cm,secret,deploy,svc,ds) =="
kubectl --kubeconfig "$MGMT_KUBECONFIG" get cm,deploy,svc,ds -A --request-timeout=30s | grep -F -- "$CLUSTER_NAME"
echo "== the resolver DS on the cluster =="
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n kube-system get ds registry-hosts-fix --request-timeout=30s
echo "== namespaces on the workspace =="
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get appdeployments --request-timeout=30s | head -5
