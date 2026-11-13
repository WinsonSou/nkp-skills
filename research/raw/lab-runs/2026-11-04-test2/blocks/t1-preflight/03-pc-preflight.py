# READ-ONLY
import sys, json, ipaddress
sys.path.insert(0, '~/Documents/projects/ntnx-skills/skills/nutanix-api/scripts')
from ntnx import *

C = '/clustermgmt/v4.0/config/clusters'
S4 = '/clustermgmt/v4.0/config/storage-containers'
N = '/networking/v4.4/config'
V = '/vmm/v4.1/ahv/config/vms'
I = '/vmm/v4.1/content/images'
G = '/volumes/v4.3/config/volume-groups'
CAT = '/prism/v4.0/config/categories'
GIB = 2 ** 30

def ipv(o):
    return ((o or {}).get('ipv4') or {}).get('value') if isinstance(o, dict) else None
def ipv_s(o):
    if isinstance(o, str): return o or None
    if not isinstance(o, dict): return None
    return (o.get('ipv4') or {}).get('value') or o.get('value')

out = {}
# --- PE cluster / network ---
c = next(x for x in list_all(C) if 'PRISM_CENTRAL' not in ((x.get('config') or {}).get('clusterFunction') or []))
out['PE_CLUSTER'] = c['name']; out['PE_CLUSTER_EXT_ID'] = c['extId']
nw = c.get('network') or {}
out['NTP_SERVERS'] = [ipv(x) for x in nw.get('ntpServerIpList') or []]
out['DNS_SERVERS'] = [ipv(x) for x in nw.get('nameServerIpList') or []]
out['CLUSTER_VIP'] = ipv(nw.get('externalAddress'))
out['DATA_SERVICES_IP'] = ipv(nw.get('externalDataServiceIp'))

# --- subnets ---
subs = []
for s in list_all(f'{N}/subnets'):
    v4 = ((s.get('ipConfig') or [{}])[0].get('ipv4') or {})
    ipp = v4.get('ipSubnet') or {}
    pool = v4.get('poolList') or []
    subs.append({'name': s['name'], 'extId': s['extId'], 'type': s.get('subnetType'),
                 'external': s.get('isExternal'), 'vlan': s.get('networkId'),
                 'cidr': f"{ipv_s(ipp.get('ip'))}/{ipp.get('prefixLength')}" if ipp else None,
                 'pool': [(p['startIp']['value'], p['endIp']['value']) for p in pool],
                 'gateway': ipv_s(v4.get('defaultGatewayIp'))})
out['SUBNETS'] = subs

# --- containers ---
out['CONTAINERS'] = [(s['name'], s.get('isInternal')) for s in list_all(S4) if s['clusterExtId'] == c['extId']]

# --- images ---
out['IMAGES'] = [(i['name'], i['type'], round(i['sizeBytes'] / GIB, 2),
                  [x == c['extId'] for x in (i.get('clusterLocationExtIds') or [])].count(True))
                 for i in list_all(I)]
print(json.dumps(out, indent=1, default=str))
