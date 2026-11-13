# READ-ONLY  (nutanix-networking RECIPES "Free IP check", the arp() half only: the ntnx client runs on the laptop, so the block is split. Must run on the L2 host.)
source ~/nkp-site.env 2>/dev/null
python3 - <<'PY'
import subprocess
ips = ['<net>.50'] + ['<net>.%d' % n for n in range(51, 56)] + ['<net>.60'] + \
      ['<net>.%d' % n for n in range(61, 66)] + ['<net>.70'] + ['<net>.%d' % n for n in range(71, 76)]
def arp(ip, wait_s=1):
    subprocess.run(['ping', '-c', '1', '-W', str(wait_s), ip],
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    line = subprocess.run(['ip', 'neigh', 'show', ip], capture_output=True, text=True).stdout
    line = line.strip()
    return 'FAILED' if 'FAILED' in line else 'FREE?' if ('no entry' in line or not line) else 'PRESENT'
for ip in ips:
    print(ip, arp(ip))
PY
