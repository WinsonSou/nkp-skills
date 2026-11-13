# READ-ONLY
source ~/nkp-site.env 2>/dev/null
h="${REGISTRY_URL#*://}"; h="${h%%/*}"; proj="${REGISTRY_URL#*/}"
curl -s --cacert "$REGISTRY_CA_FILE" --netrc-file <(printf 'machine %s login %s password %s\n' "$h" "$(printenv REGISTRY_MIRROR_USERNAME)" "$(printenv REGISTRY_MIRROR_PASSWORD)") -o /tmp/_cat.json -w 'catalog: %{http_code}\n' "https://$h/v2/_catalog?n=10000"
python3 - <<'PY'
import json
d=json.load(open('/tmp/_cat.json'))
r=d.get('repositories',[])
print('repositories:',len(r))
for x in sorted(r):
    if any(k in x for k in ('flow-cni','flow-ovn','flow-container','multus','/nats','nutanix-flow')):
        print('  ',x)
PY
rm -f /tmp/_cat.json
echo "== tags of the pushed flow repos via the token flow =="
for repo in flow-cni flow-ovn-kubernetes flow-container-security; do
  tok=$(curl -s --cacert "$REGISTRY_CA_FILE" -u "$(printenv REGISTRY_MIRROR_USERNAME):$(printenv REGISTRY_MIRROR_PASSWORD)" "https://$h/service/token?service=harbor-registry&scope=repository:$proj/$repo:pull" | python3 -c 'import sys,json;print(json.load(sys.stdin).get("token",""))')
  code=$(curl -s --cacert "$REGISTRY_CA_FILE" -H "Authorization: Bearer $tok" -o /tmp/_t.json -w '%{http_code}' "https://$h/v2/$proj/$repo/tags/list")
  echo "$repo -> http=$code $(head -c 100 /tmp/_t.json)"
done
rm -f /tmp/_t.json
