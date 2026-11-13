# READ-ONLY
source ~/nkp-site.env 2>/dev/null
h="${REGISTRY_URL#*://}"; h="${h%%/*}"
curl -s --cacert "$REGISTRY_CA_FILE" --netrc-file <(printf 'machine %s login %s password %s\n' "$h" "$(printenv REGISTRY_MIRROR_USERNAME)" "$(printenv REGISTRY_MIRROR_PASSWORD)") -o /tmp/_cat.json "https://$h/v2/_catalog?n=10000"
python3 -c "
import json;r=json.load(open('/tmp/_cat.json')).get('repositories',[])
dbl=[x for x in r if x.startswith('nutanix/nutanix/')]
print('total repos:',len(r),' doubled prefix:',len(dbl))
print('doubled sample:', sorted(dbl)[:8])
print('flow repos:', sorted(x for x in r if 'flow' in x))
"
rm -f /tmp/_cat.json
