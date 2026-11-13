# READ-ONLY
source ~/nkp-site.env 2>/dev/null
ws='skilltest-flow'; wsns='skilltest-flow-dw97w'
KC="--request-timeout=30s"
echo "== workspaces =="
kubectl --kubeconfig "$MGMT_KUBECONFIG" $KC get workspaces
echo "== the workspace object =="
kubectl --kubeconfig "$MGMT_KUBECONFIG" $KC get workspace "$ws" -o jsonpath='{.metadata.name} deletionTimestamp={.metadata.deletionTimestamp} finalizers={.metadata.finalizers}{"\n"}'
echo "== clusters in the workspace namespace (must be empty) =="
kubectl --kubeconfig "$MGMT_KUBECONFIG" $KC -n "$wsns" get nkpclusters,kommanderclusters
echo "== the namespace before =="
kubectl --kubeconfig "$MGMT_KUBECONFIG" $KC get namespace "$wsns" -o jsonpath='{.status.phase}{"\n"}'
echo "== objects in the namespace =="
kubectl --kubeconfig "$MGMT_KUBECONFIG" $KC -n "$wsns" get all,configmaps,secrets,workspaceroles.workspaces.kommander.mesosphere.io 2>/dev/null | awk '{print $1}' | sort | uniq -c | sort -rn | head -20
