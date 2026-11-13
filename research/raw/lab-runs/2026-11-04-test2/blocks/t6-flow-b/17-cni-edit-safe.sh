# CHANGES  (safe redo of the dry-run file edit: try the path-filter form on a scratch copy, then apply to the real file)
source ~/nkp-skilltest-flow-b.env 2>/dev/null
f="$HOME/$CLUSTER_NAME-dryrun.yaml"; o="$f.orig"
t=/tmp/t6-cni-edit-test.yaml
cp -p "$o" "$t"
yq -i '(select(.kind == "NKPCluster") | .spec.capiCluster.topology.variables[] | select(.name == "clusterConfig") | .value.addons.cni.provider) = "Flow"' "$t"
echo "yq RC=$?"
python3 - "$t" <<'PY'
import sys,re
t=open(sys.argv[1]).read()
docs=[d for d in re.split(r'(?m)^---\s*$', t) if d.strip()]
for d in docs:
    k=re.search(r'(?m)^kind:\s*(\S+)',d); n=re.search(r'(?m)^  name:\s*(\S+)',d)
    top=re.findall(r'(?m)^([a-zA-Z]+):',d)
    print("  kind=%s name=%s toplevel=%s" % (k.group(1), n.group(1) if n else "?", top))
PY
echo "== cni in the scratch copy =="
yq 'select(.kind == "NKPCluster") | (.spec.capiCluster.topology.variables[] | select(.name == "clusterConfig") | .value.addons.cni)' "$t"
if [ "$(python3 - "$t" <<'PY'
import sys,re
t=open(sys.argv[1]).read()
docs=[d for d in re.split(r'(?m)^---\s*$', t) if d.strip()]
bad=sum(1 for d in docs if re.search(r'(?m)^kind:\s*Secret',d) and re.search(r'(?m)^spec:',d))
print(bad)
PY
)" = "0" ]; then cp -p "$t" "$f"; echo "applied to $f"; else echo "NOT applied: a Secret doc got a spec"; fi
rm -f "$t"
ls -l "$f" | awk '{print "mode="$1, "bytes="$5}'
