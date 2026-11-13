# READ-ONLY
source ~/nkp-site.env 2>/dev/null
python3 - <<'PY' 2>&1 | tail -30
import os, ssl, json, base64, urllib.request
pc = os.environ['PC_ENDPOINT'].rstrip('/')
u = base64.b64encode(f"{os.environ['NUTANIX_USER']}:{os.environ['NUTANIX_PASSWORD']}".encode()).decode()
ctx = ssl.create_default_context(); ctx.check_hostname=False; ctx.verify_mode=ssl.CERT_NONE
def get(p):
    r = urllib.request.Request(pc+p, headers={'Authorization':'Basic '+u,'Accept':'application/json'})
    return json.load(urllib.request.urlopen(r, context=ctx, timeout=30))
name = os.environ['SUBNET']
d = get('/api/networking/v4.4/config/subnets?$filter=name%20eq%20%27'+name.replace(' ','%20')+'%27')
s = [x for x in d.get('data',[]) if x.get('name')==name][0]
print('top keys:', sorted(s.keys()))
print('subnetType:', s.get('subnetType'), 'isAdvancedNetworking:', s.get('isAdvancedNetworking'))
ic = s.get('ipConfig')
print('ipConfig:', json.dumps(ic, sort_keys=True)[:600])
PY
