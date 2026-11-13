# CHANGES  (deletes the 6 CSI volume groups of the deleted cluster in Prism Central; the PVC data goes with them)
import sys
sys.path.insert(0, '~/Documents/projects/ntnx-skills/skills/nutanix-api/scripts')
from ntnx import *

G = '/volumes/v4.3/config/volume-groups'
CLUSTER = 'skilltest-flow-a'
IDS = ['669037f8-7f89-4291-79f7-8956d821ce83', '92a2035e-dc72-4a10-51e4-4d4508955d30',
       '05ae6034-71e2-4922-55ba-2a33513c751a', 'c1ac623d-2659-4085-649d-19480a9f0737',
       '4902b716-a9f3-441b-47bf-9327a6bce58d', '78be9dbe-de3b-42fd-5565-dd181d62c152']

print('volume groups in PC before:', len(list_all(G)))
for vg_id in IDS:
    data, etag = get(f'{G}/{vg_id}')
    d = data.get('description') or ''
    att = req(f'{G}/{vg_id}/vm-attachments')[2].get('data') or []
    print(' target', data['name'], '| for this cluster:', f'for {CLUSTER},' in d, '| attachments:', len(att))
    if f'for {CLUSTER},' not in d or att:
        print('  SKIP: not unattached, or not this cluster')
        continue
    delete(f'{G}/{vg_id}', get(f'{G}/{vg_id}')[1])
    try:
        get(f'{G}/{vg_id}')
        print('  STILL THERE')
    except ApiError as e:
        print('  deleted, get ->', e.status)
print('volume groups in PC after:', len(list_all(G)))
