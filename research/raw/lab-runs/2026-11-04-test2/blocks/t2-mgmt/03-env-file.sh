# CHANGES  (makes ~/nkp-nkp-mgmt-01.env and appends the 4 cluster values)
source ~/nkp-site.env 2>/dev/null
test -e ~/nkp-nkp-mgmt-01.env || { (umask 077 && echo 'source ~/nkp-site.env 2>/dev/null' > ~/nkp-nkp-mgmt-01.env); }
net=$(python3 - <<'PY'
import os, ssl, json, base64, urllib.request, ipaddress
pc = os.environ['PC_ENDPOINT'].rstrip('/')
u = base64.b64encode(f"{os.environ['NUTANIX_USER']}:{os.environ['NUTANIX_PASSWORD']}".encode()).decode()
ctx = ssl.create_default_context(); ctx.check_hostname=False; ctx.verify_mode=ssl.CERT_NONE
r = urllib.request.Request(pc+'/api/networking/v4.4/config/subnets?$filter=name%20eq%20%27'+os.environ['SUBNET'].replace(' ','%20')+'%27', headers={'Authorization':'Basic '+u})
d = json.load(urllib.request.urlopen(r, context=ctx, timeout=30))
s = [x for x in d['data'] if x['name']==os.environ['SUBNET']][0]
ip = s['ipConfig'][0]['ipv4']['ipSubnet']
print(str(ipaddress.ip_network(f"{ip['ip']['value']}/{ip['prefixLength']}", strict=False).network_address).rsplit('.',1)[0])
PY
)
: "${net:?}"
echo "export CLUSTER_NAME='nkp-mgmt-01'"      >> ~/nkp-nkp-mgmt-01.env
echo "export CP_VIP='${net}.50'"              >> ~/nkp-nkp-mgmt-01.env
echo "export LB_IP_RANGE='${net}.51-${net}.55'" >> ~/nkp-nkp-mgmt-01.env
echo "export WORKSPACE_NS='kommander'"        >> ~/nkp-nkp-mgmt-01.env
echo "--- lines added (variable names + last octets only)"
grep -oE '^export [A-Z_]+' ~/nkp-nkp-mgmt-01.env
echo "CP_VIP last octet: ${CP_VIP##*.}   LB range last octets: ${LB_IP_RANGE##*-}"
echo "syntax:"; bash -n ~/nkp-nkp-mgmt-01.env && echo ok
