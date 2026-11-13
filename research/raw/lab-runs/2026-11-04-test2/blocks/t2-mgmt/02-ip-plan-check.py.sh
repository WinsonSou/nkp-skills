# READ-ONLY
source ~/nkp-site.env 2>/dev/null
python3 - <<'PY' 2>&1 | tail -20
import os, ssl, json, base64, urllib.request, ipaddress
pc = os.environ['PC_ENDPOINT'].rstrip('/')
u = base64.b64encode(f"{os.environ['NUTANIX_USER']}:{os.environ['NUTANIX_PASSWORD']}".encode()).decode()
ctx = ssl.create_default_context(); ctx.check_hostname=False; ctx.verify_mode=ssl.CERT_NONE
def get(p):
    r = urllib.request.Request(pc+p, headers={'Authorization':'Basic '+u,'Accept':'application/json'})
    return json.load(urllib.request.urlopen(r, context=ctx, timeout=30))
name = os.environ['SUBNET']
d = get('/api/networking/v4.4/config/subnets?$filter=name%20eq%20%27'+name.replace(' ','%20')+'%27')
s = [x for x in d.get('data',[]) if x.get('name')==name][0]
ip = s['ipConfig'][0]['ipv4']
cidr = ipaddress.ip_network(f"{ip['ipSubnet']['ip']['value']}/{ip['ipSubnet']['prefixLength']}", strict=False)
pool = ip.get('poolList') or []
def last(a): return int(str(a).split('.')[-1])
if not pool: print('no poolList'); raise SystemExit(1)
p0, p1 = last(pool[0]['startIp']['value']), last(pool[0]['endIp']['value'])
net24 = ipaddress.ip_network(f"{ip['ipSubnet']['ip']['value']}/24", strict=False)
print(f"subnet_type={s.get('subnetType')} cidr_len={cidr.prefixlen} net24_last_octet={last(net24.network_address)}")
print(f"pool last octets: {p0}-{p1}")
base = str(net24.network_address).rsplit('.',1)[0]
cands = [f'{base}.{n}' for n in (50,51,55)]
print("CP_VIP .50: in_cidr=%s in_pool=%s" % (ipaddress.ip_address(cands[0]) in cidr, p0 <= 50 <= p1))
print("LB .51-.55: all_in_cidr=%s none_in_pool=%s" % (all(ipaddress.ip_address(f'{base}.{n}') in cidr for n in range(51,56)), not any(p0 <= n <= p1 for n in range(51,56))))
pods = ipaddress.ip_network('192.168.0.0/16'); svcs = ipaddress.ip_network('10.96.0.0/12')
print("node cidr overlaps default pod 192.168.0.0/16:", cidr.overlaps(pods))
print("node cidr overlaps default svc 10.96.0.0/12:", cidr.overlaps(svcs))
print("CP_VIP inside pod or svc CIDR:", any(ipaddress.ip_address(cands[0]) in n for n in (pods,svcs)))
print("node cidr inside pod CIDR:", cidr.subnet_of(pods))
PY
