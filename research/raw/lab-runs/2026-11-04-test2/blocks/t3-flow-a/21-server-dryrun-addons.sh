# READ-ONLY  (server dry run again; prints only the addon key names after the webhooks)
source ~/nkp-skilltest-flow-a.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" --request-timeout=60s apply --server-side --dry-run=server -f "$PWD/$CLUSTER_NAME-dryrun.yaml" -f "$PWD/$CLUSTER_NAME-flow-cni-hcp.yaml" -o yaml | yq '(.items // [.]) | .[] | select(.kind == "NKPCluster" or .kind == "Cluster") | .kind + " " + .metadata.name + "  addons: " + ((.spec.capiCluster.topology // .spec.topology).variables[] | select(.name == "clusterConfig") | .value.addons | keys | join(","))'
echo "RC2=$?"
