# READ-ONLY  (nutanix-networking RECIPES "Free IP check": the four API sources; the ARP probe runs on the bastion, block 05)
import sys, json, ipaddress
sys.path.insert(0, '~/Documents/projects/ntnx-skills/skills/nutanix-api/scripts')
from ntnx import *

N = '/networking/v4.4/config'

def ipv(v):
    if isinstance(v, str): return v or None
    if not isinstance(v, dict): return None
    return (v.get('ipv4') or {}).get('value') or v.get('value')

def subnet_id(name): return by_name(f'{N}/subnets', name)['extId']

def pool(sid):
    s = get(f'{N}/subnets/{sid}')[0]
    cfg = ((s.get('ipConfig') or [{}])[0].get('ipv4') or {})
    return [ipaddress.IPv4Address(i) for p in cfg.get('poolList') or []
            for i in range(int(ipaddress.IPv4Address(p['startIp']['value'])),
                           int(ipaddress.IPv4Address(p['endIp']['value'])) + 1)]

def reserved(sid):
    return {ipv(r.get('ipv4Address')): r.get('clientContext')
            for r in (req(f'{N}/subnets/{sid}/reserved-ips')[2].get('data') or [])}

def nic_ips(sid=None):
    out = {}
    for vm in list_all('/vmm/v4.1/ahv/config/vms'):
        for nic in vm.get('nics') or []:
            ni = nic.get('nicNetworkInfo') or {}
            if sid and (ni.get('subnet') or {}).get('extId') != sid: continue
            for ip in [ipv((ni.get('ipv4Config') or {}).get('ipAddress'))] + \
                      [ipv(a) for a in (ni.get('ipv4Info') or {}).get('learnedIpAddresses') or []]:
                if ip: out[ip] = f'VM {vm["name"]}'
    return out

def fip_ips(sid):
    return {ipv(f['floatingIp']['ipv4']): f'floating IP {f["name"]}'
            for f in list_all(f'{N}/floating-ips')
            if f.get('externalSubnetReference') in (sid, {'extId': sid})}

def vpc_gateway_ips(sid):
    out = {}
    for v in list_all(f'{N}/vpcs'):
        for es in v.get('externalSubnets') or []:
            if es.get('subnetReference') not in (sid, {'extId': sid}): continue
            for a in es.get('externalIps') or []: out[ipv(a)] = f'VPC {v["name"]} gateway'
    return out

def platform_ips():
    out = {PC.split(':')[0]: 'Prism Central'}
    for c in list_all('/clustermgmt/v4.0/config/clusters'):
        nw = c.get('network') or {}
        for key, label in (('externalAddress', 'cluster VIP'), ('externalDataServiceIp', 'data services IP')):
            if ipv(nw.get(key)): out[ipv(nw[key])] = f'{c["name"]} {label}'
        for n in (c.get('nodes') or {}).get('nodeList') or []:
            for key, label in (('hostIp', 'host'), ('controllerVmIp', 'CVM')):
                if ipv(n.get(key)): out[ipv(n[key])] = f'{c["name"]} {label}'
    return out

def free_ip_api(subnet_name, candidates):
    sid = subnet_id(subnet_name)
    held = {**platform_ips(), **nic_ips(sid), **fip_ips(sid), **vpc_gateway_ips(sid)}
    held.update({ip: f'reserved ({ctx})' for ip, ctx in reserved(sid).items() if ip})
    poolset = {str(a) for a in pool(sid)}
    return [{'ip': ip, 'holder': held.get(ip), 'inPool': ip in poolset} for ip in candidates]

base = '<net>.'
cands = [base + str(n) for n in ([50] + list(range(51, 56)) + [60] + list(range(61, 66)) +
                                 [70] + list(range(71, 76)))]
print(json.dumps(free_ip_api('PRIMARY-IPAM', cands), indent=1))
