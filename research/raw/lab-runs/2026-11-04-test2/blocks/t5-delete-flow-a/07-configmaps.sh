# READ-ONLY
source ~/nkp-site.env 2>/dev/null
source ~/nkp-skilltest-flow-a.env 2>/dev/null
KC="--request-timeout=30s"
echo "--- the two configmaps with the cluster name: owner + labels"
kubectl --kubeconfig "$MGMT_KUBECONFIG" $KC -n "$WORKSPACE_NS" get cm -o custom-columns='NAME:.metadata.name,OWNER:.metadata.ownerReferences[*].kind,OWNERNAME:.metadata.ownerReferences[*].name,FLUX:.metadata.labels.kustomize\.toolkit\.fluxcd\.io/name,AGE:.metadata.creationTimestamp' 2>&1
echo "--- kustomizations in the workspace ns"
kubectl --kubeconfig "$MGMT_KUBECONFIG" $KC -n "$WORKSPACE_NS" get kustomizations.kustomize.toolkit.fluxcd.io 2>&1
echo "--- who references the cluster name in the flux objects"
kubectl --kubeconfig "$MGMT_KUBECONFIG" $KC -n "$WORKSPACE_NS" get kustomizations.kustomize.toolkit.fluxcd.io,gitrepositories.source.toolkit.fluxcd.io,ocirepositories.source.toolkit.fluxcd.io 2>&1 | head -20
echo "--- does anything still name the cluster in the mgmt cluster (secrets/configmaps, all namespaces)"
kubectl --kubeconfig "$MGMT_KUBECONFIG" $KC get cm,secret -A 2>/dev/null | grep -F -- "$CLUSTER_NAME"
