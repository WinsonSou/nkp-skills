# READ-ONLY  (structure of the dry-run file docs: top-level keys only, no values)
source ~/nkp-skilltest-flow-b.env 2>/dev/null
for f in "$HOME/$CLUSTER_NAME-dryrun.yaml.orig" "$HOME/$CLUSTER_NAME-dryrun.yaml"; do
echo "== $f"
python3 - "$f" <<'PY'
import sys,re,json
t=open(sys.argv[1]).read()
docs=[d for d in re.split(r'(?m)^---\s*$', t) if d.strip()]
for d in docs:
    kinds=re.findall(r'(?m)^kind:\s*(\S+)',d); names=re.findall(r'(?m)^  name:\s*(\S+)',d)
    top=re.findall(r'(?m)^([a-zA-Z]+):',d)
    print("  kind=%s name=%s toplevel=%s" % (kinds[0] if kinds else "?", names[0] if names else "?", top))
PY
done
