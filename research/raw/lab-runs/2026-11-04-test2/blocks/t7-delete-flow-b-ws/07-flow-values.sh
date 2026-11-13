# READ-ONLY
source ~/nkp-skilltest-flow-b.env 2>/dev/null
echo "== the path B values ConfigMap =="
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get configmap "$CLUSTER_NAME-flow-values" --request-timeout=30s
echo "== the 2 ConfigMaps: owner refs, labels, keys =="
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get cm "kube-oidc-proxy-$CLUSTER_NAME" "traefik-forward-auth-kommander-$CLUSTER_NAME" -o json --request-timeout=30s | jq -c '.items[] | {name: .metadata.name, owner: (.metadata.ownerReferences // []), labels: (.metadata.labels // {}), keys: (.data | keys)}'
echo "== more kinds with the cluster name =="
kubectl --kubeconfig "$MGMT_KUBECONFIG" get kommanderclusters,appdeployments,clusterapps -A --request-timeout=30s | grep -F -- "$CLUSTER_NAME" || echo "none"
echo "== objects left in the workspace ns (all the cluster-scoped ones) =="
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get nkpclusters,clusters.cluster.x-k8s.io,machines,machinedeployments,kommanderclusters,helmchartproxies,helmreleaseproxies --request-timeout=30s
