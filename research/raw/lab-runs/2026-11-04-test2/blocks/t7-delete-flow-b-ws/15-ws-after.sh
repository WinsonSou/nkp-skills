# READ-ONLY
source ~/nkp-site.env 2>/dev/null
ws='skilltest-flow'; wsns='skilltest-flow-dw97w'
KC="--request-timeout=30s"
date '+now %F %T'
echo "== workspaces =="
kubectl --kubeconfig "$MGMT_KUBECONFIG" $KC get workspaces
echo "== the workspace object =="
kubectl --kubeconfig "$MGMT_KUBECONFIG" $KC get workspace "$ws" -o jsonpath='{.metadata.name} deletionTimestamp={.metadata.deletionTimestamp} finalizers={.metadata.finalizers}{"\n"}'
kubectl --kubeconfig "$MGMT_KUBECONFIG" $KC get workspace "$ws" -o name 2>&1 | tail -1
echo "== the namespace =="
kubectl --kubeconfig "$MGMT_KUBECONFIG" $KC get namespace "$wsns" -o jsonpath='{.status.phase}{"\n"}' 2>&1
kubectl --kubeconfig "$MGMT_KUBECONFIG" $KC get namespace "$wsns" -o jsonpath='{range .status.conditions[*]}{.type}={.status} {.message}{"\n"}{end}' 2>&1 | cut -c1-300
echo "== any namespace still Terminating =="
kubectl --kubeconfig "$MGMT_KUBECONFIG" $KC get namespaces --field-selector status.phase=Terminating
echo "== the management cluster must stay =="
kubectl --kubeconfig "$MGMT_KUBECONFIG" $KC get nkpclusters -A
kubectl --kubeconfig "$MGMT_KUBECONFIG" $KC get nodes 2>&1 | grep -c ' Ready '
