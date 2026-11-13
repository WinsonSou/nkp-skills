# READ-ONLY
source ~/nkp-site.env 2>/dev/null
python3 -I - <<'PY'
import sys, os
sys.path.insert(0, os.path.expanduser('~/Documents/projects/ntnx-skills/skills/nutanix-api/scripts'))
from ntnx import *
V   = '/vmm/v4.1/ahv/config/vms'
G   = '/volumes/v4.3/config/volume-groups'
N   = '/networking/v4.4/config'
CAT = '/prism/v4.0/config/categories'

HANDLES = """ca97d999-91a3-47e5-4213-56a32eaae084 a1db5461-a9e0-4a6e-6f57-be481e2d2ef4
b645e8ac-00e9-4da3-43c6-c3d4e2a0b774 ac4750b1-4d8d-4f5f-6d7f-6779290c3a63
9d53c011-d5a0-44a5-537c-eb32d72351c2 6b963b39-4d73-45f5-65cc-516853ea852f
3e571543-1cdd-4790-7184-e5c352d11ecc 70ae01d6-060c-485b-441d-a8eded9f48a8
995675fd-0295-4fe9-45f9-404f5266f3a0 982b5d2d-821e-47b6-5000-323ee885bb70
0bda1835-5fab-4590-7efd-a3223e3e3c68 6bba0bf4-516e-4001-561e-ba351c624917
cadec553-bc0b-401a-7150-407bf9c5d438 e98b2770-0da0-4cb3-7532-cc6c52414a7c
f91ed10a-9d6e-454e-6f79-e2b3848b4282 bb834fae-e57d-4c70-4a1f-5d818b3bb916
19ea994e-6672-4bca-7c56-77a54de32693 ef1cf7ae-99f2-4f03-6ae1-b6135947c5fb
3d194d26-960d-4f8f-538c-da9546649648 66763ff3-fa0d-44a0-6b58-23f455bcd9ac""".split()

vms = list_all(V)
print('VMs in PC:', len(vms))
print('  with a test-cluster name:', [v['name'] for v in vms if any(k in v['name'] for k in ('nkp-mgmt-01','skilltest'))])
print('  all:', sorted(v['name'] for v in vms))
print('volume groups in PC:', len(list_all(G)))
for h in HANDLES:
    try:
        g = get(f'{G}/{h}')[0]
        att = req(f'{G}/{h}/vm-attachments')[2].get('data') or []
        d = g.get('description') or ''
        kid = next((p.split(':', 1)[1] for p in d.split(', ') if p.startswith('K8sClusterID:')), None)
        print(f'  LEFT {h} name={g["name"]} kid={kid} attachments={len(att)}')
    except ApiError as e:
        print(f'  gone {h} ({e.status})')
cats = list_all(CAT)
used = {c.get('extId') for v in vms for c in v.get('categories') or []}
print('categories in PC:', len(cats))
for c in cats:
    blob = (c.get('key') or '') + (c.get('value') or '')
    if 'KubernetesClusterName' in blob or 'KubernetesClusterUUID' in blob:
        print(f'  CAT {c["key"]} = {c["value"]:<50s} inUse={c["extId"] in used}')
print('floating IPs:', len(list_all(f'{N}/floating-ips')))
print('VPCs:', [(x['name'], x.get('vpcType')) for x in list_all(f'{N}/vpcs')])
print('reservations with a test name:',
      [(ipv_s(r.get('ipv4Address')), r.get('clientContext'))
       for s in list_all(f'{N}/subnets')
       for r in (req(f'{N}/subnets/{s["extId"]}/reserved-ips')[2].get('data') or [])
       if any(k in (r.get('clientContext') or '') for k in ('nkp-mgmt-01','skilltest'))])
I = '/vmm/v4.1/content/images'
print('images:', [(i['name'], i.get('type')) for i in list_all(I)])
PY
