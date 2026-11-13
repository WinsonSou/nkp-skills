# READ-ONLY
source ~/nkp-skilltest-flow-a.env 2>/dev/null
echo "== kubeconfig server endpoint (not a secret) =="
grep -E '^ +server:' "$CLUSTER_KUBECONFIG"
echo "== from the operator host: VIP reachability =="
ping -c 2 -W 2 "$CP_VIP" >/dev/null 2>&1 && echo "ping VIP: reply" || echo "ping VIP: no reply"
curl -sk -o /dev/null -w 'vip api: %{http_code}\n' --max-time 10 "https://$CP_VIP:6443/version"
curl -sk -o /dev/null -w 'vip api by hostname-less GET: %{http_code}\n' --max-time 10 "https://$CP_VIP:6443/livez"
echo "== pods on the new cluster =="
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" --request-timeout=30s get pods -A -o wide 2>&1 | head -30
echo "== node conditions (first node) =="
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" --request-timeout=30s get nodes -o jsonpath='{range .items[0:1]}{.metadata.name}{"\n"}{range .status.conditions[*]}  {.type}={.status} {.reason}{"\n"}{end}{end}'
echo "== taints =="
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" --request-timeout=30s get nodes -o jsonpath='{range .items[*]}{.metadata.name}{" taints="}{.spec.taints}{"\n"}{end}'
