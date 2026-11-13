# CHANGES  (deletes the 5 Prism Central categories of the three deleted test clusters)
source ~/nkp-site.env 2>/dev/null
python3 -I - <<'PY'
import sys, os
sys.path.insert(0, os.path.expanduser('~/Documents/projects/ntnx-skills/skills/nutanix-api/scripts'))
from ntnx import *
CAT = '/prism/v4.0/config/categories'
V   = '/vmm/v4.1/ahv/config/vms'
KEEP_NAME = {'skilltest-mgmt-01', '<mgmt-cluster>'}          # the user's two old categories
MINE_UUID = {'k8s-cf97f500-4355-4336-9222-3e29da7b1e73',   # nkp-mgmt-01
             'k8s-6e694f3b-92b3-45a4-9770-e813590709d7',   # skilltest-flow-a
             'k8s-adc70254-7980-4406-8d94-6d0c3f8cbe49',   # skilltest-flow-b
             'k8s-cd478812-bfd4-4ac4-a7b3-311130bf705d'}   # the earlier skilltest-flow-b attempt
used = {c.get('extId') for v in list_all(V) for c in v.get('categories') or []}
print('categories in PC before:', len(list_all(CAT)))
for c in list_all(CAT):
    key, val = c.get('key'), c.get('value')
    if key == 'KubernetesClusterName':
        mine = val == 'nkp-mgmt-01'
    elif key == 'KubernetesClusterUUID':
        mine = val in MINE_UUID
    else:
        continue
    tag = 'DELETE' if mine else 'KEEP'
    print(f'  {key}={val} inUse={c["extId"] in used} -> {tag}')
    if not mine:
        continue
    if c['extId'] in used:
        print('    SKIP: still in use')
        continue
    delete(f'{CAT}/{c["extId"]}', get(f'{CAT}/{c["extId"]}')[1])
    try:
        get(f'{CAT}/{c["extId"]}')
        print('    STILL THERE')
    except ApiError as e:
        print(f'    gone ({e.status})')
print('categories in PC after:', len(list_all(CAT)))
PY
