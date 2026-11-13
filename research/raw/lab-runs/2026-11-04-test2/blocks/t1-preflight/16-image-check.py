# READ-ONLY  (ntnx nutanix-vm RECIPES "Images: check before a create")
import sys, json
sys.path.insert(0, '~/Documents/projects/ntnx-skills/skills/nutanix-api/scripts')
from ntnx import *
I = '/vmm/v4.1/content/images'
name = 'nkp-ubuntu-24.04-release-cis-1.36.2-20261014170313'
img = by_name(I, name)
print(json.dumps({k: img.get(k) for k in ('name', 'type', 'sizeBytes', 'clusterLocationExtIds',
                                          'isSharedWithAllProjects', 'ownerName')}, indent=1))
print('size GiB:', round(img['sizeBytes'] / 2**30, 2))
print('source:', (img.get('source') or {}).get('$objectType'))
