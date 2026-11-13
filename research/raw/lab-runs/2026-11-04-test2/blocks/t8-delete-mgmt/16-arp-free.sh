# READ-ONLY
# the ARP half of the free-IP check, run on the host on the same L2 as the node subnet
for ip in <net>.50 <net>.51 <net>.52 <net>.53 <net>.54 <net>.55; do
  ping -c 1 -W 1 "$ip" >/dev/null 2>&1
done
sleep 1
for ip in <net>.50 <net>.51 <net>.52 <net>.53 <net>.54 <net>.55; do
  line=$(ip neigh show "$ip" 2>/dev/null)
  case "$line" in
    *lladdr*) verdict="PRESENT (a host answered)" ;;
    *)        verdict="FREE" ;;
  esac
  echo "  $ip -> ${line:-<no entry>} -> $verdict"
done
echo "== control: two addresses that ARE in use =="
for ip in <net>.37 <net>.39; do
  ping -c 1 -W 1 "$ip" >/dev/null 2>&1
  sleep 1
  echo "  $ip -> $(ip neigh show "$ip" 2>/dev/null)"
done
