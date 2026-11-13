# READ-ONLY  (C12 step 2: the image names come from the mirror, never guessed)
source ~/nkp-site.env 2>/dev/null
h="${REGISTRY_URL#*://}"; h="${h%%/*}"; proj="${REGISTRY_URL#*/}"
for repo in nginxinc/nginx-unprivileged library/busybox busybox; do
  tok=$(curl -s --cacert "$REGISTRY_CA_FILE" -u "$(printenv REGISTRY_MIRROR_USERNAME):$(printenv REGISTRY_MIRROR_PASSWORD)" "https://$h/service/token?service=harbor-registry&scope=repository:$proj/$repo:pull" | python3 -c 'import sys,json;print(json.load(sys.stdin).get("token",""))')
  code=$(curl -s --cacert "$REGISTRY_CA_FILE" -H "Authorization: Bearer $tok" -o /tmp/_t.json -w '%{http_code}' "https://$h/v2/$proj/$repo/tags/list")
  echo "$repo -> http=$code $(head -c 160 /tmp/_t.json)"
done
rm -f /tmp/_t.json
