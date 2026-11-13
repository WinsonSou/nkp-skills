# READ-ONLY
source ~/nkp-site.env 2>/dev/null
python3 -I - <<'PY'
import sys, os
sys.path.insert(0, os.path.expanduser('~/Documents/projects/ntnx-skills/skills/nutanix-api/scripts'))
from ntnx import *

V  = '/vmm/v4.1/ahv/config/vms'
G  = '/volumes/v4.3/config/volume-groups'
N  = '/networking/v4.4/config'
CAT= '/prism/v4.0/config/categories'

def ipv_s(o):
    """IPv4 string from a plain string, an IPv4Address or an IPAddress object."""
    if isinstance(o, str):
        return o or None
    if not isinstance(o, dict):
        return None
    return (o.get('ipv4') or {}).get('value') or o.get('value')


def vg_entries(g):
    d = g.get('description') or ''
    if 'K8sClusterID' not in d or ' for ' not in d:
        return None
    field = lambda k: next((p.split(':', 1)[1] for p in d.split(', ') if p.startswith(k + ':')), None)
    return d.split(' for ', 1)[1].split(',', 1)[0], field('PVC'), field('NS')

def audit(cluster):
    out = {'VMs': [], 'volume_groups': [], 'floating_ips': [], 'floating_ips_unnamed': [],
           'ip_reservations': [], 'categories': []}
    for v in list_all(V, filter=f"startswith(name,'{cluster}')"):
        out['VMs'].append({'name': v['name'], 'extId': v['extId'], 'power': v.get('powerState')})
    for g in list_all(G):
        e = vg_entries(g)
        if (not g.get('isHidden') and g.get('usageType') != 'INTERNAL' and e and e[0] == cluster
                and not (req(f'{G}/{g["extId"]}/vm-attachments')[2].get('data') or [])):
            out['volume_groups'].append({'name': g['name'], 'extId': g['extId'], 'pvc': e[1], 'ns': e[2]})
    for f in list_all(f'{N}/floating-ips'):
        row = {'address': ipv_s(f['floatingIp']['ipv4']), 'name': f['name'], 'extId': f['extId'],
               'status': f.get('associationStatus'),
               'private': ipv_s(((f.get('association') or {}).get('privateIp') or {}))}
        if cluster in (f.get('name') or ''):
            out['floating_ips'].append(row)
        elif f.get('name') == 'fip-dummy-name' and row['private']:
            out['floating_ips_unnamed'].append(row)
    for s in list_all(f'{N}/subnets'):
        for r in (req(f'{N}/subnets/{s["extId"]}/reserved-ips')[2].get('data') or []):
            if cluster in (r.get('clientContext') or ''):
                out['ip_reservations'].append({'ip': ipv_s(r.get('ipv4Address')),
                                               'subnet': s['name'], 'context': r.get('clientContext')})
    used = {c.get('extId') for v in list_all(V) for c in v.get('categories') or []}
    for c in list_all(CAT):
        if cluster in (c.get('key') or '') or cluster in (c.get('value') or ''):
            out['categories'].append({'key': c['key'], 'value': c['value'],
                                      'extId': c['extId'], 'inUse': c['extId'] in used})
    out['counts'] = {k: len(v) for k, v in out.items() if isinstance(v, list)}
    return out

for cluster in ('nkp-mgmt-01', 'skilltest-flow-a', 'skilltest-flow-b', 'skilltest-flow'):
    a = audit(cluster)
    print(f'== {cluster}: {a["counts"]}')
    for row in a['VMs']:
        print('   VM', row)
    for row in a['volume_groups']:
        print('   VG', row)
    for row in a['floating_ips'] + a['floating_ips_unnamed']:
        print('   FIP', row)
    for row in a['ip_reservations']:
        print('   RES', row)
    for row in a['categories']:
        print('   CAT', row)

print('== PC totals =="')
vms = list_all(V)
print('VMs', len(vms), '| named after a test cluster:',
      sum(1 for v in vms if any(k in v['name'] for k in ('nkp-mgmt-01','skilltest'))))
print('all VM names:', sorted(v['name'] for v in vms))
print('volume groups', len(list_all(G)))
print('floating IPs', len(list_all(f'{N}/floating-ips')))
print('VPCs', [(x['name'], x.get('vpcType')) for x in list_all(f'{N}/vpcs')])
print('subnets', [(x['name'], x.get('subnetType')) for x in list_all(f'{N}/subnets')])
print('== categories whose key or value is not a live test object ==')
cats = list_all(CAT)
print('categories in PC:', len(cats))
for c in cats:
    if any(k in (c.get('key') or '') + (c.get('value') or '') for k in ('KubernetesClusterName', 'KubernetesClusterUUID')):
        print('   ', c['key'], '=', c['value'], '| inUse:', c['extId'] in {x.get('extId') for v in vms for x in v.get('categories') or []})
PY
