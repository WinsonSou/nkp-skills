# READ-ONLY
source ~/nkp-site.env 2>/dev/null
KC="--request-timeout=30s"
echo "== namespaces =="
kubectl --kubeconfig "$MGMT_KUBECONFIG" $KC get ns | grep -F -- 'skilltest-flow' || echo "no namespace with the name"
echo "== workspaces =="
kubectl --kubeconfig "$MGMT_KUBECONFIG" $KC get workspaces
echo "== cluster-scoped RBAC and bindings with the name =="
kubectl --kubeconfig "$MGMT_KUBECONFIG" $KC get clusterroles,clusterrolebindings $KC 2>/dev/null | grep -F -- 'skilltest-flow' || echo "none"
echo "== all namespaced objects with the name (kinds in the API) =="
kubectl --kubeconfig "$MGMT_KUBECONFIG" $KC get all,cm,secrets,workspaces,appdeployments,projects.workspaces.kommander.mesosphere.io -A 2>/dev/null | grep -F -- 'skilltest-flow' || echo "none"
echo "== kubefed federated objects with the name =="
kubectl --kubeconfig "$MGMT_KUBECONFIG" $KC get federatednamespaces.types.kubefed.io,federatedroles.types.kubefed.io,federatedrolebindings.types.kubefed.io -A 2>/dev/null | grep -F -- 'skilltest-flow' || echo "none"
echo "== the management cluster must stay =="
kubectl --kubeconfig "$MGMT_KUBECONFIG" $KC get nkpclusters -A
