# CHANGES  (redoes the local dry-run file edit: restore .orig, then set addons.cni.provider=Flow without dropping documents)
source ~/nkp-skilltest-flow-b.env 2>/dev/null
f="$HOME/$CLUSTER_NAME-dryrun.yaml"; o="$f.orig"
test -s "$o" || { echo "no .orig copy"; exit 1; }
cp -p "$o" "$f"
echo "before: $(( $(grep -c '^kind:' "$f") )) kind lines"
yq -i '(.spec.capiCluster.topology.variables[]? | select(.name == "clusterConfig") | .value.addons.cni.provider) = "Flow"' "$f"
echo "yq RC=$?"
echo "after: $(( $(grep -c '^kind:' "$f") )) kind lines"
echo "== kinds =="; yq 'select(.kind) | .kind + " " + .metadata.name' "$f"
echo "== addons / cni / CIDRs of the NKPCluster =="
yq '(.kind == "NKPCluster")' "$f" >/dev/null
python3 - "$f" <<'PY'
import sys,re,json
t=open(sys.argv[1]).read()
docs=[d for d in re.split(r'(?m)^---\s*$', t) if d.strip()]
print("docs:", len(docs), "->", [re.search(r'(?m)^kind:\s*(\S+)',d).group(1) for d in docs])
PY
yq 'select(.kind == "NKPCluster") | (.spec.capiCluster.topology.variables[] | select(.name == "clusterConfig") | .value | "addons: " + (.addons | keys | join(",")) + "  kubeProxy: " + (.kubeProxy.mode // "none"))' "$f"
yq 'select(.kind == "NKPCluster") | (.spec.capiCluster.topology.variables[] | select(.name == "clusterConfig") | .value.addons.cni)' "$f"
yq 'select(.kind == "NKPCluster") | (.spec.capiCluster.clusterNetwork) | "pods: " + .pods.cidrBlocks[0] + "  services: " + .services.cidrBlocks[0]' "$f"
ls -l "$f" | awk '{print "mode="$1, "bytes="$5}'
