# CHANGES  (creates the workload cluster and its Flow CNI HelmChartProxy; Prism Central creates the VMs)
source ~/nkp-skilltest-flow-a.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" --request-timeout=60s apply --server-side -f "$PWD/$CLUSTER_NAME-dryrun.yaml" -f "$PWD/$CLUSTER_NAME-flow-cni-hcp.yaml" -o name
echo "RC_create=$?"
