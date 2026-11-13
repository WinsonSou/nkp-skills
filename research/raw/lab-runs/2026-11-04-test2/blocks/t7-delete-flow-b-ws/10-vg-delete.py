# CHANGES  (deletes the 9 CSI volume groups of skilltest-flow-b in Prism Central; the PVC data goes with them)
import sys
sys.path.insert(0, '~/Documents/projects/ntnx-skills/skills/nutanix-api/scripts')
from ntnx import *
G = '/volumes/v4.3/config/volume-groups'
CLUSTER = 'skilltest-flow-b'
IDS = ['8263956e-9a2a-4c46-496c-f3b11aaf3b34','7b059105-9c47-43aa-5896-3a3dc369298d',
       '29ab864d-6869-4c06-61ae-1b80aa0f8370','2f303155-4239-4833-406c-468cc07f43df',
       '94bb6eff-20fe-4bd7-4016-962400ab2c99','240704b8-89c1-4b14-6b42-9d994e1717d2',
       'f53ea499-bf69-4f23-7b0c-d774ca293b69','7c89558e-6f39-49d7-718e-f5cf8e8eb119',
       '86a88e6d-e01b-45d9-4ee0-2f663ca7b0ad']
print('volume groups in PC before:', len(list_all(G)))
for vg_id in IDS:
    data, etag = get(f'{G}/{vg_id}')
    d = data.get('description') or ''
    att = req(f'{G}/{vg_id}/vm-attachments')[2].get('data') or []
    ok = f'for {CLUSTER},' in d and not att and not data.get('isHidden')
    print(' target', data['name'], '| desc names the cluster:', f'for {CLUSTER},' in d, '| attachments:', len(att), '| hidden:', data.get('isHidden'))
    if not ok:
        print('  SKIP: guard failed')
        continue
    delete(f'{G}/{vg_id}', get(f'{G}/{vg_id}')[1])
    try:
        get(f'{G}/{vg_id}')
        print('  STILL THERE')
    except ApiError as e:
        print('  deleted, get ->', e.status)
print('volume groups in PC after:', len(list_all(G)))
