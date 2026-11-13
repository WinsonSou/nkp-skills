# CHANGES  (creates the workspace and its namespace)
source ~/nkp-site.env 2>/dev/null
ws='skilltest-flow'; display='skilltest flow'
: "${ws:?}" "${display:?}"
nkp create workspace "$ws" --display-name "$display" --kubeconfig "$MGMT_KUBECONFIG"
kubectl --kubeconfig "$MGMT_KUBECONFIG" --request-timeout=30s get workspace "$ws"
