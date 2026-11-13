# READ-ONLY
source ~/nkp-skilltest-flow-a.env 2>/dev/null
f="$PWD/$CLUSTER_NAME-dryrun.yaml"
yq '.kind + " " + .metadata.name' "$f"
yq 'select(.kind == "NKPCluster" or .kind == "Cluster") | ((.spec.capiCluster.topology // .spec.topology).variables[] | select(.name == "clusterConfig") | .value | "addons: " + (.addons | keys | join(",")) + "  kubeProxy: " + (.kubeProxy.mode // "none"))' "$f"
yq 'select(.kind == "NKPCluster" or .kind == "Cluster") | (.spec.capiCluster.clusterNetwork // .spec.clusterNetwork) | "pods: " + (.pods.cidrBlocks[0] // "?") + "  services: " + (.services.cidrBlocks[0] // "?")' "$f"
echo "== objects in the file =="
yq '.kind' "$f" | sort | uniq -c
