# READ-ONLY
# the ARP half of the free-IP check, on the host on the same L2 as the node subnet
IPS="<net>.50 <net>.51 <net>.52 <net>.53 <net>.54 <net>.55 <net>.60 <net>.61 <net>.62 <net>.63 <net>.64 <net>.65 <net>.70 <net>.71 <net>.72 <net>.73 <net>.74 <net>.75"
for ip in $IPS; do ping -c 1 -W 1 "$ip" >/dev/null 2>&1; done
sleep 1
for ip in $IPS; do
  line=$(ip neigh show "$ip" 2>/dev/null)
  case "$line" in
    *lladdr*) echo "  $ip -> ${line} -> PRESENT" ;;
    *)        echo "  $ip -> ${line:-<no entry>} -> FREE" ;;
  esac
done
echo "== control (addresses in use, must show lladdr) =="
for ip in <net>.37 <net>.39; do
  ping -c 1 -W 1 "$ip" >/dev/null 2>&1; sleep 1
  echo "  $ip -> $(ip neigh show "$ip" 2>/dev/null)"
done
