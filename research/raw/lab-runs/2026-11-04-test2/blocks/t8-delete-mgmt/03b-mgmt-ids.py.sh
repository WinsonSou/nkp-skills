# READ-ONLY
source ~/nkp-site.env 2>/dev/null
python3 -I - <<'PY'
import sys, os
sys.path.insert(0, os.path.expanduser('~/Documents/projects/ntnx-skills/skills/nutanix-api/scripts'))
from ntnx import *
V   = '/vmm/v4.1/ahv/config/vms'
G   = '/volumes/v4.3/config/volume-groups'
CAT = '/prism/v4.0/config/categories'

cats = {c['extId']: f"{c['key']}={c['value']}" for c in list_all(CAT)}
print('== categories held by the 7 management VMs')
for v in list_all(V, filter="startswith(name,'nkp-mgmt-01')"):
    print(' ', v['name'], '->', [cats.get(c.get('extId')) for c in (v.get('categories') or [])])

print('== K8sClusterID of the management volume groups (from the description)')
ids = {}
for g in list_all(G):
    d = g.get('description') or ''
    if 'K8sClusterID' not in d:
        continue
    kid = next((p.split(':', 1)[1] for p in d.split(', ') if p.startswith('K8sClusterID:')), None)
    pvc = next((p.split(':', 1)[1] for p in d.split(', ') if p.startswith('PVC:')), None)
    ids.setdefault(kid, []).append((g['name'], pvc))
for kid, rows in ids.items():
    print(f'  K8sClusterID {kid}: {len(rows)} groups, e.g. {rows[0]}')
PY
