import sys
sys.path.insert(0, '~/Documents/projects/ntnx-skills/skills/nutanix-api/scripts')
from ntnx import *
CAT = '/prism/v4.0/config/categories'
used = {}
for v in list_all('/vmm/v4.1/ahv/config/vms'):
    for c in v.get('categories') or []:
        used[c.get('extId')] = used.get(c.get('extId'), 0) + 1
for c in list_all(CAT):
    print(c.get('key'), '=', c.get('value'), '| vms:', used.get(c['extId'], 0))
