import sys, json
sys.path.insert(0, '~/Documents/projects/ntnx-skills/skills/nutanix-api/scripts')
from ntnx import *

C = '/clustermgmt/v4.0/config/clusters'
N = '/networking/v4.4/config'
G = '/volumes/v4.3/config/volume-groups'
V = '/vmm/v4.1/ahv/config/vms'
CAT = '/prism/v4.0/config/categories'
IH = '/prism/v4.0/config/identity-providers'
CLUSTER = 'skilltest-flow-a'

def ipv_s(o):
    if isinstance(o, str):
        return o or None
    if not isinstance(o, dict):
        return None
    return (o.get('ipv4') or {}).get('value') or o.get('value')

print('== VMs with the cluster prefix, or category Cluster matching')
vms = list_all(V)
hit = []
for v in vms:
    name = v.get('name') or ''
    cats = v.get('categories') or []
    cvals = [(c.get('key'), c.get('value')) for c in cats]
    if name.startswith(CLUSTER) or any(CLUSTER in (k or '') or CLUSTER in (val or '') for k, val in cvals):
        hit.append({'name': name, 'extId': v['extId'], 'power': v.get('powerState'),
                    'cluster': ((v.get('cluster') or {}).get('extId')),
                    'cats': cvals})
for h in hit:
    print(' VM', h)
print(' total VMs in PC:', len(vms), ' matches:', len(hit))

print('== volume groups; description mentions the cluster')
vg_all = list_all(G)
print(' total volume groups:', len(vg_all))
for g in vg_all:
    d = g.get('description') or ''
    if CLUSTER in d or CLUSTER in (g.get('name') or ''):
        att = req(f'{G}/{g["extId"]}/vm-attachments')[2].get('data') or []
        print(' VG', {'name': g['name'], 'extId': g['extId'], 'hidden': g.get('isHidden'),
                      'usageType': g.get('usageType'), 'attachments': len(att), 'desc': d[:200]})

print('== VPCs')
for v in list_all(f'{N}/vpcs'):
    print(' VPC', {'name': v.get('name'), 'extId': v['extId'],
                   'desc': (v.get('description') or '')[:120]})

print('== floating IPs')
for f in list_all(f'{N}/floating-ips'):
    print(' FIP', {'name': f.get('name'), 'extId': f['extId'], 'addr': ipv_s(f['floatingIp']['ipv4']),
                   'private': ipv_s(((f.get('association') or {}).get('privateIp') or {})),
                   'status': f.get('associationStatus')})

print('== IP reservations that mention the cluster')
for s in list_all(f'{N}/subnets'):
    rows = req(f'{N}/subnets/{s["extId"]}/reserved-ips')[2].get('data') or []
    for r in rows:
        ctx = r.get('clientContext') or ''
        if CLUSTER in ctx:
            print(' RES', {'ip': ipv_s(r.get('ipv4Address')), 'subnet': s['name'], 'context': ctx})

print('== categories mentioning the cluster')
used = {c.get('extId') for v in vms for c in v.get('categories') or []}
for c in list_all(CAT):
    if CLUSTER in (c.get('key') or '') or CLUSTER in (c.get('value') or ''):
        print(' CAT', {'key': c['key'], 'value': c['value'], 'extId': c['extId'],
                       'inUse': c['extId'] in used})
