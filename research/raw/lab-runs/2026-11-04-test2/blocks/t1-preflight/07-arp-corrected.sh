# READ-ONLY  [exploration]  the recipe's arp() classifies a Linux `INCOMPLETE` neighbour entry as PRESENT.
# Correct classification: a neighbour entry with `lladdr` = a host answered ARP (PRESENT); FAILED/INCOMPLETE = no reply.
source ~/nkp-site.env 2>/dev/null
python3 - <<'PY'
import subprocess, time
ips = ['<net>.50'] + ['<net>.%d' % n for n in range(51, 56)] + ['<net>.60'] + \
      ['<net>.%d' % n for n in range(61, 66)] + ['<net>.70'] + ['<net>.%d' % n for n in range(71, 76)]
def arp2(ip, wait_s=1, settle=2):
    subprocess.run(['ping', '-c', '1', '-W', str(wait_s), ip],
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    time.sleep(settle)
    line = subprocess.run(['ip', 'neigh', 'show', ip], capture_output=True, text=True).stdout.strip()
    if 'lladdr' in line:  return 'PRESENT: ' + line
    if 'no entry' in line or not line: return 'FREE (no entry)'
    return 'FREE (%s)' % line.split('dev')[-1].strip()
for ip in ips:
    print(ip, arp2(ip), flush=True)
PY
