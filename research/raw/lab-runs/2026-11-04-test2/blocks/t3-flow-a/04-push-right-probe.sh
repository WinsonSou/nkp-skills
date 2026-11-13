# READ-ONLY  (asks Harbor for a scoped token and prints only the granted actions, never the token)
source ~/nkp-site.env 2>/dev/null
h="${REGISTRY_URL#*://}"; h="${h%%/*}"; proj="${REGISTRY_URL#*/}"
curl -s --cacert "$REGISTRY_CA_FILE" -u "$(printenv REGISTRY_MIRROR_USERNAME):$(printenv REGISTRY_MIRROR_PASSWORD)" "https://$h/service/token?service=harbor-registry&scope=repository:$proj/nats:pull,push" \
 | python3 -c "
import sys,json,base64
d=json.load(sys.stdin)
t=d.get('token') or ''
if not t: print('no token:', list(d.keys())); raise SystemExit
p=t.split('.')[1]; p+='='*(-len(p)%4)
j=json.loads(base64.urlsafe_b64decode(p))
print('granted access:', json.dumps(j.get('access')))
print('token type:', d.get('token_type') or d.get('expires_in'))
"
