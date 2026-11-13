# READ-ONLY  (server dry run; prints only the addon key names and kube-proxy mode after the webhooks)
source ~/nkp-skilltest-flow-a.env 2>/dev/null
yq 'select(.kind == "NKPCluster")' "$PWD/$CLUSTER_NAME-dryrun.yaml" | kubectl --kubeconfig "$MGMT_KUBECONFIG" --request-timeout=60s apply --server-side --dry-run=server -f - -o yaml | yq '(.items // [.]) | .[] | select(.kind == "NKPCluster" or .kind == "Cluster") | .kind + " " + .metadata.name + "  addons: " + ((.spec.capiCluster.topology // .spec.topology).variables[] | select(.name == "clusterConfig") | .value.addons | keys | join(",")) + "  kubeProxy: " + ((.spec.capiCluster.topology // .spec.topology).variables[] | select(.name == "clusterConfig") | .value.kubeProxy.mode // "none")'
echo "RC_addons=$?"
