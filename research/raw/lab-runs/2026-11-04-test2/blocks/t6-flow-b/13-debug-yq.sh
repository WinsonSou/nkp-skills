# READ-ONLY  (why the yq|kubectl pipe is empty: shape of the dry-run file)
source ~/nkp-skilltest-flow-b.env 2>/dev/null
f="$HOME/$CLUSTER_NAME-dryrun.yaml"
echo "== first 3 lines (names only) =="; head -3 "$f" | sed -E 's/(data|stringData):.*/\1: <hidden>/'
echo "== doc separators =="; grep -c '^---' "$f"
echo "== yq select count =="
yq 'select(.kind == "Secret") | .kind' "$f" 2>&1 | sort | uniq -c
echo "== yq select, doc marker count =="
yq 'select(.kind == "Secret")' "$f" 2>/dev/null | grep -c '^kind:'
echo "== yq --no-doc? try ea =="
yq -N 'select(.kind == "Secret") | .metadata.name' "$f" 2>&1 | head
echo "== kubectl client dry run of the yq output =="
yq 'select(.kind == "Secret")' "$f" 2>/dev/null | kubectl --kubeconfig "$MGMT_KUBECONFIG" --request-timeout=30s apply --dry-run=client -f - -o name 2>&1 | head -6
echo "== python doc split count =="
python3 - "$f" <<'PY'
import sys,re
t=open(sys.argv[1]).read()
docs=[d for d in re.split(r'(?m)^---\s*$', t) if d.strip()]
print("docs:", len(docs))
for d in docs:
    m=re.search(r'(?m)^kind:\s*(\S+)',d); n=re.search(r'(?m)^  name:\s*(\S+)',d)
    print("  ", m.group(1) if m else "?", n.group(1) if n else "?")
PY
