# READ-ONLY  (ntnx nutanix-nkp RECIPES "Leftover audit for a cluster", baseline: no cluster of these names exists yet)
import sys, json
sys.path.insert(0, '~/Documents/projects/ntnx-skills/skills/nutanix-api/scripts')
from ntnx import *

N = '/networking/v4.4/config'
G = '/volumes/v4.3/config/volume-groups'
V = '/vmm/v4.1/ahv/config/vms'
CAT = '/prism/v4.0/config/categories'

def ipv_s(o):
    if isinstance(o, str): return o or None
    if not isinstance(o, dict): return None
    return (o.get('ipv4') or {}).get('value') or o.get('value')

def vg_entries(g):
    d = g.get('description') or ''
    if 'K8sClusterID' not in d or ' for ' not in d: return None
    field = lambda k: next((p.split(':', 1)[1] for p in d.split(', ') if p.startswith(k + ':')), None)
    return d.split(' for ', 1)[1].split(',', 1)[0], field('PVC'), field('NS')

def audit(cluster):
    out = {'VMs': [{'name': v['name'], 'extId': v['extId'], 'power': v.get('powerState')}
                   for v in list_all(V, filter=f"startswith(name,'{cluster}')")],
           'volume_groups': [], 'floating_ips': [], 'floating_ips_unnamed': [],
           'ip_reservations': [], 'categories': []}
    for g in list_all(G):
        e = vg_entries(g)
        if (not g.get('isHidden') and g.get('usageType') != 'INTERNAL' and e and e[0] == cluster
                and not (req(f'{G}/{g["extId"]}/vm-attachments')[2].get('data') or [])):
            out['volume_groups'].append({'name': g['name'], 'pvc': e[1], 'ns': e[2]})
    for f in list_all(f'{N}/floating-ips'):
        row = {'address': ipv_s(f['floatingIp']['ipv4']), 'name': f['name'],
               'status': f.get('associationStatus'),
               'private': ipv_s(((f.get('association') or {}).get('privateIp') or {}))}
        if cluster in (f.get('name') or ''): out['floating_ips'].append(row)
        elif f.get('name') == 'fip-dummy-name' and row['private']: out['floating_ips_unnamed'].append(row)
    for s in list_all(f'{N}/subnets'):
        for r in (req(f'{N}/subnets/{s["extId"]}/reserved-ips')[2].get('data') or []):
            if cluster in (r.get('clientContext') or ''):
                out['ip_reservations'].append({'ip': ipv_s(r.get('ipv4Address')), 'subnet': s['name'],
                                               'context': r.get('clientContext')})
    used = {c.get('extId') for v in list_all(V) for c in v.get('categories') or []}
    for c in list_all(CAT):
        if cluster in (c.get('key') or '') or cluster in (c.get('value') or ''):
            out['categories'].append({'key': c['key'], 'value': c['value'], 'inUse': c['extId'] in used})
    out['counts'] = {k: len(v) for k, v in out.items() if isinstance(v, list)}
    return out

for cluster in ['nkp-mgmt-01', 'skilltest']:
    print('###', cluster)
    print(json.dumps(audit(cluster), indent=1))
