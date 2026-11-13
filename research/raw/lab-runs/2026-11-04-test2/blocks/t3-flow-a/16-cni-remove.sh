# CHANGES  (edits the dry-run file on the operator host: removes addons.cni; changes no cluster)
source ~/nkp-skilltest-flow-a.env 2>/dev/null
f="$PWD/$CLUSTER_NAME-dryrun.yaml"; test -s "$f" || { echo "no dry-run file"; exit 1; }
cp -p "$f" "$f.orig"
yq -i 'del(select(.kind == "NKPCluster") | .spec.capiCluster.topology.variables[] | select(.name == "clusterConfig") | .value.addons.cni) | del(select(.kind == "Cluster") | .spec.topology.variables[] | select(.name == "clusterConfig") | .value.addons.cni)' "$f"
echo "yq RC=$?"
