# CHANGES  (deletes the 20 volume groups of the deleted management cluster; the PVC data goes)
source ~/nkp-site.env 2>/dev/null
python3 -I - <<'PY'
import sys, os
sys.path.insert(0, os.path.expanduser('~/Documents/projects/ntnx-skills/skills/nutanix-api/scripts'))
from ntnx import *
G = '/volumes/v4.3/config/volume-groups'
KID = 'cf97f500-4355-4336-9222-3e29da7b1e73'

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

print('volume groups in PC before:', len(list_all(G)))
for h in HANDLES:
    g = get(f'{G}/{h}')[0]
    d = g.get('description') or ''
    kid = next((p.split(':', 1)[1] for p in d.split(', ') if p.startswith('K8sClusterID:')), None)
    att = req(f'{G}/{h}/vm-attachments')[2].get('data') or []
    ok = (kid == KID and not att and not g.get('isHidden') and g.get('usageType') != 'INTERNAL')
    print(f'  {g["name"]} kid={kid} attachments={len(att)} hidden={g.get("isHidden")} -> '
          + ('DELETE' if ok else 'SKIP (not this cluster)'))
    if not ok:
        continue
    for a in g.get('attachments') or []:
        post(f'{G}/{h}/$actions/detach-vm',
             {"$objectType": "volumes.v4.config.VmAttachment", "extId": a['attachment']['extId']})
    delete(f'{G}/{h}', get(f'{G}/{h}')[1])
    try:
        get(f'{G}/{h}')
        print('    STILL THERE')
    except ApiError as e:
        print(f'    gone ({e.status})')
print('volume groups in PC after:', len(list_all(G)))
PY
