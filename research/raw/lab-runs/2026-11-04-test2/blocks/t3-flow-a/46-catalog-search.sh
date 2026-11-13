# READ-ONLY
source ~/nkp-site.env 2>/dev/null
h="${REGISTRY_URL#*://}"; h="${h%%/*}"
curl -s --cacert "$REGISTRY_CA_FILE" --netrc-file <(printf 'machine %s login %s password %s\n' "$h" "$(printenv REGISTRY_MIRROR_USERNAME)" "$(printenv REGISTRY_MIRROR_PASSWORD)") -o /tmp/_cat.json "https://$h/v2/_catalog?n=10000"
python3 -c "
import json
r=json.load(open('/tmp/_cat.json')).get('repositories',[])
for k in ('nginx','busybox','alpine','httpd','toolbox'):
    hits=sorted(x for x in r if k in x)
    print(k,'->',len(hits), hits[:6])
"
rm -f /tmp/_cat.json
