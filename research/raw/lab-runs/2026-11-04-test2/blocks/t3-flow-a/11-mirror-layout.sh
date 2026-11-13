# READ-ONLY
source ~/nkp-site.env 2>/dev/null
h="${REGISTRY_URL#*://}"; h="${h%%/*}"; proj="${REGISTRY_URL#*/}"
curl -s --cacert "$REGISTRY_CA_FILE" --netrc-file <(printf 'machine %s login %s password %s\n' "$h" "$(printenv REGISTRY_MIRROR_USERNAME)" "$(printenv REGISTRY_MIRROR_PASSWORD)") -o /tmp/_cat.json -w 'catalog: %{http_code}\n' "https://$h/v2/_catalog?n=10000"
python3 - <<'PY'
import json
r=json.load(open('/tmp/_cat.json')).get('repositories',[])
dbl=[x for x in r if x.startswith('nutanix/nutanix/')]
print('repos with the doubled prefix nutanix/nutanix/:', len(dbl))
for x in sorted(dbl)[:15]: print('  ',x)
print('--- how NKP own images sit (search konvoy/kommander/capi) ---')
for x in sorted(r):
    if any(k in x for k in ('konvoy','kommander','capi-operator','cluster-api-controller')):
        print('  ',x)
PY
rm -f /tmp/_cat.json
