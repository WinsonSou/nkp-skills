# READ-ONLY  (server dry run of the NKPCluster object now that its Secrets exist; changes nothing)
source ~/nkp-skilltest-flow-a.env 2>/dev/null
yq 'select(.kind == "NKPCluster")' "$PWD/$CLUSTER_NAME-dryrun.yaml" | kubectl --kubeconfig "$MGMT_KUBECONFIG" --request-timeout=60s apply --server-side --dry-run=server -f - -o name
echo "RC_nkp=$?"
