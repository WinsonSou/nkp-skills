# READ-ONLY  (ntnx nutanix-networking RECIPES "VPCs": list only. Baseline before Flow CNI makes a Shared Services VPC.)
import sys, json
sys.path.insert(0, '~/Documents/projects/ntnx-skills/skills/nutanix-api/scripts')
from ntnx import *
N = '/networking/v4.4/config'
print(json.dumps([{'name': v['name'], 'type': v.get('vpcType'),
                   'externalSubnets': len(v.get('externalSubnets') or [])}
                  for v in list_all(f'{N}/vpcs')], indent=1))
print('flow-cni images in the mirror are checked in block 13; no VPC means no earlier Flow cluster')
