# READ-ONLY  (Harbor scope probe: prints only the granted actions, never the token)
source ~/nkp-site.env 2>/dev/null
h="${REGISTRY_URL#*://}"; h="${h%%/*}"; proj="${REGISTRY_URL#*/}"
probe() {
  curl -s --cacert "$REGISTRY_CA_FILE" -u "$(printenv REGISTRY_MIRROR_USERNAME):$(printenv REGISTRY_MIRROR_PASSWORD)" \
    "https://$h/service/token?service=harbor-registry&scope=repository:$proj/pause:$1" \
  | python3 -c "
import sys,json,base64
d=json.load(sys.stdin); t=d.get('token') or ''
if not t: print('  scope $1 -> no token'); raise SystemExit
p=t.split('.')[1]; p+='='*(-len(p)%4)
j=json.loads(base64.urlsafe_b64decode(p))
print('  scope $1 ->', json.dumps(j.get('access')))
"
}
echo "pull account, repo pause (a pulled image):"
probe pull
echo "pull account, pull+push:"
probe pull,push
echo "=== anonymous ==="
curl -s --cacert "$REGISTRY_CA_FILE" "https://$h/service/token?service=harbor-registry&scope=repository:$proj/pause:pull" | head -c 80; echo
