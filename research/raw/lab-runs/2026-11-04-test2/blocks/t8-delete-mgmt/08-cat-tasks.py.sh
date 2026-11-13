# READ-ONLY
source ~/nkp-site.env 2>/dev/null
python3 -I - <<'PY'
import sys, os, json
sys.path.insert(0, os.path.expanduser('~/Documents/projects/ntnx-skills/skills/nutanix-api/scripts'))
from ntnx import *
T = '/prism/v4.0/config/tasks'
rows = []
for page in range(12):
    items = req(f'{T}?$limit=100&$page={page}')[2].get('data') or []
    if not items:
        break
    rows += items
print('tasks read:', len(rows))
print('one task keys:', sorted(rows[0].keys()))
cat = [t for t in rows if 'ategorie' in (t.get('operation') or '')]
print('category tasks:', len(cat))
for t in cat[:12]:
    print(' ', t.get('operation'), '|', t.get('status'), '|', t.get('createTime') or t.get('createdTime'),
          '|', [(e.get('name'), e.get('rel')) for e in (t.get('entitiesAffected') or [])][:3])
PY
