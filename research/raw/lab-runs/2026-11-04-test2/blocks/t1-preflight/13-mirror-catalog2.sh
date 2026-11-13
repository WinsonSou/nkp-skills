# READ-ONLY  [exploration]  A-31 follow-up: the http code of /v2/_catalog, the repository count, and a name filter (head -c cut the code line)
source ~/nkp-site.env 2>/dev/null
h="${REGISTRY_URL#*://}"; h="${h%/}"; host="${h%%/*}"
tmp=$(mktemp)
code=$(curl -s --cacert "$REGISTRY_CA_FILE" --netrc-file /dev/stdin -o "$tmp" -w '%{http_code}' "https://$host/v2/_catalog" <<< "machine ${host%%:*} login $REGISTRY_MIRROR_USERNAME password $REGISTRY_MIRROR_PASSWORD")
echo "catalog http=$code"
python3 - "$tmp" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
r = d.get('repositories') or []
print('repositories:', len(r))
print('with a dot in the first path part (registry host kept):', sum(1 for x in r if '.' in x.split('/')[1] if x.count('/')>1))
print('flow/ovn images:', [x for x in r if 'flow' in x or 'ovn' in x] or 'none')
print('pause images:', [x for x in r if x.endswith('/pause') or x == 'pause'] or 'none')
PY
rm -f "$tmp"
