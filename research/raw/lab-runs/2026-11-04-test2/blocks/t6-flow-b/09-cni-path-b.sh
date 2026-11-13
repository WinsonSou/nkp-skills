# CHANGES  (edits the local dry-run file: sets addons.cni.provider to Flow (path B); changes no cluster object)
source ~/nkp-skilltest-flow-b.env 2>/dev/null
f="$HOME/$CLUSTER_NAME-dryrun.yaml"; test -s "$f" || { echo "no dry-run file"; exit 1; }
cp -p "$f" "$f.orig"
yq -i 'select(.kind == "NKPCluster") | (.spec.capiCluster.topology.variables[] | select(.name == "clusterConfig") | .value.addons.cni.provider) = "Flow"' "$f"
echo "yq RC=$?"
echo "== kinds =="; yq '.kind + " " + .metadata.name' "$f"
echo "== addons and kubeProxy =="
yq 'select(.kind == "NKPCluster") | (.spec.capiCluster.topology.variables[] | select(.name == "clusterConfig") | .value | "addons: " + (.addons | keys | join(",")) + "  kubeProxy: " + (.kubeProxy.mode // "none"))' "$f"
echo "== cni after the edit =="
yq 'select(.kind == "NKPCluster") | (.spec.capiCluster.topology.variables[] | select(.name == "clusterConfig") | .value.addons.cni)' "$f"
echo "== CIDRs =="
yq 'select(.kind == "NKPCluster") | (.spec.capiCluster.clusterNetwork) | "pods: " + .pods.cidrBlocks[0] + "  services: " + .services.cidrBlocks[0]' "$f"
ls -l "$f" | awk '{print "mode="$1, "bytes="$5}'
