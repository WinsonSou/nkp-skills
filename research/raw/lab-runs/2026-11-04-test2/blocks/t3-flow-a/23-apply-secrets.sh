# CHANGES  (creates only the 5 PC/registry Secrets of the new cluster on the management cluster; creates no cluster, no VM)
source ~/nkp-skilltest-flow-a.env 2>/dev/null
yq 'select(.kind == "Secret")' "$PWD/$CLUSTER_NAME-dryrun.yaml" | kubectl --kubeconfig "$MGMT_KUBECONFIG" --request-timeout=60s apply --server-side -f - -o name
echo "RC_secrets=$?"
