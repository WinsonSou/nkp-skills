# READ-ONLY  (Prism Central leftover audit for the cluster, runs on this laptop)
import sys
sys.path.insert(0, '~/Documents/projects/ntnx-skills/skills/nutanix-api/scripts')
from ntnx import *

N = '/networking/v4.4/config'
G = '/volumes/v4.3/config/volume-groups'
V = '/vmm/v4.1/ahv/config/vms'
CAT = '/prism/v4.0/config/categories'
CLUSTER = 'skilltest-flow-b'

def ipv_s(o):
    if isinstance(o, str):
        return o or None
    if not isinstance(o, dict):
        return None
    return (o.get('ipv4') or {}).get('value') or o.get('value')

print('== VMs with the cluster prefix or a category that names it')
vms = list_all(V)
hit = []
for v in vms:
    name = v.get('name') or ''
    cats = v.get('categories') or []
    cvals = [(c.get('key'), c.get('value')) for c in cats]
    if name.startswith(CLUSTER) or any(CLUSTER in (k or '') or CLUSTER in (val or '') for k, val in cvals):
        hit.append({'name': name, 'extId': v['extId'], 'power': v.get('powerState'), 'cats': cvals})
for h in hit:
    print(' VM', h)
print(' total VMs in PC:', len(vms), ' matches:', len(hit))

print('== volume groups that mention the cluster')
vg_all = list_all(G)
print(' total volume groups:', len(vg_all))
for g in vg_all:
    d = g.get('description') or ''
    if CLUSTER in d or CLUSTER in (g.get('name') or ''):
        att = req(f'{G}/{g["extId"]}/vm-attachments')[2].get('data') or []
        print(' VG', {'name': g['name'], 'extId': g['extId'], 'hidden': g.get('isHidden'),
                      'usageType': g.get('usageType'), 'attachments': len(att), 'desc': d[:160]})

print('== VPCs')
vpcs = list_all(f'{N}/vpcs')
for v in vpcs:
    print(' VPC', {'name': v.get('name'), 'extId': v['extId'], 'desc': (v.get('description') or '')[:80]})
print(' total VPCs:', len(vpcs))

print('== floating IPs')
fips = list_all(f'{N}/floating-ips')
mine = [f for f in fips if CLUSTER in (f.get('name') or '') or CLUSTER in (f.get('description') or '')]
print(' total floating IPs:', len(fips), ' with the cluster name:', len(mine))
for f in mine:
    print(' FIP', {'name': f.get('name'), 'status': f.get('associationStatus'), 'addr': ipv_s(f['floatingIp']['ipv4'])})

print('== IP reservations that mention the cluster')
n = 0
for s in list_all(f'{N}/subnets'):
    rows = req(f'{N}/subnets/{s["extId"]}/reserved-ips')[2].get('data') or []
    for r in rows:
        ctx = r.get('clientContext') or ''
        if CLUSTER in ctx:
            n += 1
            print(' RES', {'ip': ipv_s(r.get('ipv4Address')), 'subnet': s['name']})
print(' reservations with the cluster name:', n)

print('== categories that mention the cluster')
for c in list_all(CAT):
    if CLUSTER in (c.get('key') or '') or CLUSTER in (c.get('value') or ''):
        print(' CAT', {'key': c['key'], 'value': c['value'], 'extId': c['extId']})
print('== total categories:', len(list_all(CAT)))
