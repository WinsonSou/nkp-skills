# READ-ONLY
source ~/nkp-site.env 2>/dev/null
python3 -I - <<'PY'
import sys, os
sys.path.insert(0, os.path.expanduser('~/Documents/projects/ntnx-skills/skills/nutanix-api/scripts'))
from ntnx import *
V = '/vmm/v4.1/ahv/config/vms'
vm = by_name(V, 'nkp-mgmt-01-jmqhc-8mvc7')
print('VM categories of one management node:')
for c in vm.get('categories') or []:
    print('  ', c.get('key'), '=', c.get('value'), '| extId', c.get('extId'))
print('VM cluster extId:', (vm.get('cluster') or {}).get('extId'))
print('NICs:')
for n in vm.get('nics') or []:
    ni = n.get('nicNetworkInfo') or {}
    print('   subnet', (ni.get('subnet') or {}).get('name'),
          'ip', ((ni.get('ipv4Config') or {}).get('ipAddress') or {}).get('value'))
PY
