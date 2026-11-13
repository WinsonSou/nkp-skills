# READ-ONLY
source ~/nkp-site.env 2>/dev/null
python3 -I - <<'PY'
import sys, os
sys.path.insert(0, os.path.expanduser('~/Documents/projects/ntnx-skills/skills/nutanix-api/scripts'))
from ntnx import *
CAT = '/prism/v4.0/config/categories'
for c in list_all(CAT):
    blob = (c.get('key') or '') + (c.get('value') or '')
    if 'KubernetesCluster' in blob:
        print(f"{c.get('key'):22s} {c.get('value'):50s} created {c.get('createTime')}  extId {c['extId']}")
PY
