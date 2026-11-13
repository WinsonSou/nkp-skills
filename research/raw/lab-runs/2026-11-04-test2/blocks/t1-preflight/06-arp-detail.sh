# READ-ONLY  [exploration]  why does the ARP probe say PRESENT for every candidate? Raw neighbour state + MACs.
ip -o neigh show | awk '$1 ~ /^10\.8\.49\./ {print $1, $5, $6, $7}' | sort -t. -k4 -n | head -40
echo "== macs =="
ip -o neigh show | awk '$1 ~ /^10\.8\.49\./ {print $5}' | sort | uniq -c | sort -rn | head
echo "== bastion own IP and MAC =="
ip -o -4 addr show | awk '{print $2, $4}'
ip -o link show | awk -F': ' '{print $2, $3}' | head -5
echo "== who answers for .55 (fresh probe) =="
ping -c 1 -W 1 <net>.55 >/dev/null 2>&1; ip neigh show <net>.55
echo "== who answers for .81 (in the IPAM pool) =="
ping -c 1 -W 1 <net>.81 >/dev/null 2>&1; ip neigh show <net>.81
echo "== who answers for a random unused .244 =="
ping -c 1 -W 1 <net>.244 >/dev/null 2>&1; ip neigh show <net>.244
