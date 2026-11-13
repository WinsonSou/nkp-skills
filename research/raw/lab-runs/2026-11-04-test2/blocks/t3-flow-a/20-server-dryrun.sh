# READ-ONLY  (server dry run: the API server and the webhooks check the objects and change nothing)
source ~/nkp-skilltest-flow-a.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" --request-timeout=60s apply --server-side --dry-run=server -f "$PWD/$CLUSTER_NAME-dryrun.yaml" -f "$PWD/$CLUSTER_NAME-flow-cni-hcp.yaml" -o name
echo "RC1=$?"
