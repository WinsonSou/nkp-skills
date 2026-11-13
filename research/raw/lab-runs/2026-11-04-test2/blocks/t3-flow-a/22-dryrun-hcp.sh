# READ-ONLY  (server dry run of the HCP file only: schema + CAAPH webhook, changes nothing)
source ~/nkp-skilltest-flow-a.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" --request-timeout=60s apply --server-side --dry-run=server -f "$PWD/$CLUSTER_NAME-flow-cni-hcp.yaml" -o name
echo "RC_hcp=$?"
