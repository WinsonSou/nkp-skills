# READ-ONLY
source ~/nkp-site.env 2>/dev/null
python3 -I - <<'PY'
import sys, os, ipaddress
sys.path.insert(0, os.path.expanduser('~/Documents/projects/ntnx-skills/skills/nutanix-api/scripts'))
from ntnx import *
V   = '/vmm/v4.1/ahv/config/vms'
G   = '/volumes/v4.3/config/volume-groups'
N   = '/networking/v4.4/config'
CAT = '/prism/v4.0/config/categories'
I   = '/vmm/v4.1/content/images'
S4  = '/clustermgmt/v4.0/config/storage-containers'

def ipv_s(o):
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
    out = {'VMs': [], 'volume_groups': [], 'floating_ips': [], 'ip_reservations': [], 'categories': []}
    for v in list_all(V, filter=f"startswith(name,'{cluster}')"):
        out['VMs'].append(v['name'])
    for g in list_all(G):
        e = vg_entries(g)
        if (not g.get('isHidden') and g.get('usageType') != 'INTERNAL' and e and e[0] == cluster
                and not (req(f'{G}/{g["extId"]}/vm-attachments')[2].get('data') or [])):
            out['volume_groups'].append(g['name'])
    for f in list_all(f'{N}/floating-ips'):
        if cluster in (f.get('name') or ''):
            out['floating_ips'].append(f['name'])
    for s in list_all(f'{N}/subnets'):
        for r in (req(f'{N}/subnets/{s["extId"]}/reserved-ips')[2].get('data') or []):
            if cluster in (r.get('clientContext') or ''):
                out['ip_reservations'].append(ipv_s(r.get('ipv4Address')))
    for c in list_all(CAT):
        if cluster in (c.get('key') or '') or cluster in (c.get('value') or ''):
            out['categories'].append(f"{c['key']}={c['value']}")
    return {k: len(v) for k, v in out.items()}, out

print('== A. leftover audit for the three deleted clusters (+ the workspace name)')
for cl in ('nkp-mgmt-01', 'skilltest-flow-a', 'skilltest-flow-b', 'skilltest-flow'):
    counts, rows = audit(cl)
    print(f'  {cl:18s} {counts}')
    for k, v in rows.items():
        for r in v:
            print('      LEFT', k, r)

print('== B. Prism Central totals')
vms = list_all(V)
print('  VMs:', len(vms), sorted(v['name'] for v in vms))
print('  volume groups:', len(list_all(G)))
print('  floating IPs:', len(list_all(f'{N}/floating-ips')),
      '| with a test name:', [f['name'] for f in list_all(f'{N}/floating-ips')
                               if any(k in (f.get('name') or '') for k in ('nkp-mgmt-01', 'skilltest'))])
print('  VPCs:', [(x['name'], x.get('vpcType')) for x in list_all(f'{N}/vpcs')])
print('  subnets:', [(x['name'], x.get('subnetType')) for x in list_all(f'{N}/subnets')])
print('  categories:', len(list_all(CAT)))
for c in list_all(CAT):
    blob = (c.get('key') or '') + (c.get('value') or '')
    if 'KubernetesCluster' in blob:
        print('      CAT', c['key'], '=', c['value'])
print('  images:', [(i['name'], i.get('type')) for i in list_all(I)])
print('  storage containers:', len(list_all(S4)))

print('== C. free-IP check, API half (the four PC sources)')
sid = by_name(f'{N}/subnets', os.environ.get('SUBNET') or 'PRIMARY-IPAM')['extId']
s = get(f'{N}/subnets/{sid}')[0]
cfg = ((s.get('ipConfig') or [{}])[0].get('ipv4') or {})
pool = set()
for p in cfg.get('poolList') or []:
    pool |= {ipaddress.IPv4Address(i) for i in range(int(ipaddress.IPv4Address(p['startIp']['value'])),
                                                     int(ipaddress.IPv4Address(p['endIp']['value'])) + 1)}
held = {}
for r in (req(f'{N}/subnets/{sid}/reserved-ips')[2].get('data') or []):
    held[ipv_s(r.get('ipv4Address'))] = f"reserved ({r.get('clientContext')})"
for vm in vms:
    for nic in vm.get('nics') or []:
        ni = nic.get('nicNetworkInfo') or {}
        for ip in [ipv_s((ni.get('ipv4Config') or {}).get('ipAddress'))] + \
                  [ipv_s(x) for x in (ni.get('ipv4Info') or {}).get('learnedIpAddresses') or []]:
            if ip:
                held[ip] = f'VM {vm["name"]}'
for f in list_all(f'{N}/floating-ips'):
    held[ipv_s(f['floatingIp']['ipv4'])] = f'floating IP {f["name"]}'
for ip in ('<net>.50', '<net>.51', '<net>.52', '<net>.53', '<net>.54', '<net>.55'):
    a = ipaddress.IPv4Address(ip)
    print(f'  {ip}: in_pool={a in pool} holder={held.get(ip)}')
PY
