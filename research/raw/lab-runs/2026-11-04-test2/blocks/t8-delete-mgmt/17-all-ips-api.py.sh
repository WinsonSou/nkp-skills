# READ-ONLY
python3 -I - <<'PY'
import sys, os, ipaddress
sys.path.insert(0, os.path.expanduser('~/Documents/projects/ntnx-skills/skills/nutanix-api/scripts'))
from ntnx import *
V = '/vmm/v4.1/ahv/config/vms'
N = '/networking/v4.4/config'

def ipv_s(o):
    if isinstance(o, str):
        return o or None
    if not isinstance(o, dict):
        return None
    return (o.get('ipv4') or {}).get('value') or o.get('value')

IPS = ([f'<net>.{n}' for n in (50,)]
       + [f'<net>.{n}' for n in range(51, 56)]
       + ['<net>.60'] + [f'<net>.{n}' for n in range(61, 66)]
       + ['<net>.70'] + [f'<net>.{n}' for n in range(71, 76)])

sid = by_name(f'{N}/subnets', 'PRIMARY-IPAM')['extId']
s = get(f'{N}/subnets/{sid}')[0]
cfg = ((s.get('ipConfig') or [{}])[0].get('ipv4') or {})
pool = set()
for p in cfg.get('poolList') or []:
    pool |= {str(ipaddress.IPv4Address(i)) for i in range(int(ipaddress.IPv4Address(p['startIp']['value'])),
                                                          int(ipaddress.IPv4Address(p['endIp']['value'])) + 1)}
held = {}
for r in (req(f'{N}/subnets/{sid}/reserved-ips')[2].get('data') or []):
    held[ipv_s(r.get('ipv4Address'))] = f"reserved ({r.get('clientContext')})"
for vm in list_all(V):
    for nic in vm.get('nics') or []:
        ni = nic.get('nicNetworkInfo') or {}
        for ip in [ipv_s((ni.get('ipv4Config') or {}).get('ipAddress'))] + \
                  [ipv_s(x) for x in (ni.get('ipv4Info') or {}).get('learnedIpAddresses') or []]:
            if ip:
                held[ip] = f'VM {vm["name"]}'
for f in list_all(f'{N}/floating-ips'):
    held[ipv_s(f['floatingIp']['ipv4'])] = f'floating IP {f["name"]}'
for ip in IPS:
    print(f'  {ip}: in_pool={ip in pool} holder={held.get(ip)}')
PY
