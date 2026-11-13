# READ-ONLY
source ~/nkp-site.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" --request-timeout=30s get workspaces
kubectl --kubeconfig "$MGMT_KUBECONFIG" --request-timeout=30s get ns | grep -E 'skilltest'
