# READ-ONLY  (the decisive check: are the nodes still reachable, and does net_cidr carry the host prefix?)
source ~/nkp-skilltest-flow-b.env 2>/dev/null
K2="kubectl --kubeconfig $CLUSTER_KUBECONFIG --request-timeout=20s"
echo -n "api from the operator host: "; $K2 get --raw /version >/dev/null 2>&1 && echo ok || echo NOT-REACHABLE
echo "== nodes =="; $K2 get nodes -o wide --no-headers 2>&1 | awk '{print "  "$1, $2, $6}'
echo "== ovn-config =="
$K2 -n ovn-kubernetes get configmaps -o yaml 2>/dev/null | grep -E 'mtu|net_cidr|svc_cidr|k8s_apiserver' | sed 's/^/  /'
echo "== pod IPs (per-node subnet size) =="
$K2 get pods -n flow-cni-system -o wide --no-headers 2>/dev/null | awk '{print "  "$1, $6}' | head -6
echo "== daemonsets =="
$K2 get ds -A --no-headers 2>&1 | grep -E 'ovnkube|ovs-node|conntrack|multus|cilium' | awk '{print "  "$1, $2, $3"/"$4}'
echo "== ARP/ping from the operator host to the nodes =="
for ip in $($K2 get nodes -o jsonpath='{range .items[*]}{.status.addresses[?(@.type=="InternalIP")].address}{" "}{end}' 2>/dev/null); do
  ping -c1 -W1 "$ip" >/dev/null 2>&1 && r=ok || r=no-ping
  sleep 1; nb=$(ip neigh show "$ip" 2>/dev/null); case "$nb" in *lladdr*) a=arp;; *) a=no-arp;; esac
  echo "  $ip $r $a"; done
echo "== pull failures / DNS signature =="
$K2 get pods -A --no-headers 2>&1 | awk '$4=="ImagePullBackOff"||$4=="ErrImagePull"{print "  "$1, $2, $4}' | head -8
$K2 get events -A --request-timeout=20s 2>/dev/null | grep -c 'server misbehaving' | sed 's/^/  events with "server misbehaving": /'
