# READ-ONLY
source ~/nkp-skilltest-flow-a.env 2>/dev/null
h="${REGISTRY_URL#*://}"; h="${h%%/*}"
echo "== how the operator host resolves the registry =="
getent hosts "$h" || echo "getent: nothing"
grep -c "$h" /etc/hosts 2>/dev/null | sed 's/^/etc-hosts lines: /'
echo "== image present in the mirror (tags, token flow) =="
for repo in nutanix/nutanix/flow-cni nutanix/nutanix/flow-container-security nutanix/nutanix/flow-ovn-kubernetes; do
  tok=$(curl -s --cacert "$REGISTRY_CA_FILE" -u "$(printenv REGISTRY_MIRROR_USERNAME):$(printenv REGISTRY_MIRROR_PASSWORD)" "https://$h/service/token?service=harbor-registry&scope=repository:$repo:pull" | python3 -c 'import sys,json;print(json.load(sys.stdin).get("token",""))')
  code=$(curl -s --cacert "$REGISTRY_CA_FILE" -H "Authorization: Bearer $tok" -o /tmp/_t.json -w '%{http_code}' "https://$h/v2/$repo/tags/list")
  echo "$repo -> http=$code $(head -c 90 /tmp/_t.json)"
done
rm -f /tmp/_t.json
