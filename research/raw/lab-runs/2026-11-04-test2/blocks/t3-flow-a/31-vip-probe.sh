# READ-ONLY
source ~/nkp-skilltest-flow-a.env 2>/dev/null
echo "== kubeconfig server =="
grep -E '^ +server:' "$CLUSTER_KUBECONFIG"
echo "== VIP from the operator host =="
ping -c 2 -W 2 "$CP_VIP" >/dev/null 2>&1 && echo "ping VIP: reply" || echo "ping VIP: no reply"
curl -sk -o /dev/null -w 'vip:6443/version: %{http_code}\n' --max-time 10 "https://$CP_VIP:6443/version"
echo "== flow-processor image and events =="
pod=$(kubectl --kubeconfig "$CLUSTER_KUBECONFIG" --request-timeout=30s -n flow-cns-system get pods -o name | head -1)
echo "pod: $pod"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" --request-timeout=30s -n flow-cns-system get "$pod" -o jsonpath='{.spec.containers[*].image}{"\n"}'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" --request-timeout=30s -n flow-cns-system describe "$pod" 2>/dev/null | grep -A3 -E 'Failed|Warning|Error' | head -20
echo "== flow pods: all images =="
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" --request-timeout=30s -n flow-cni-system get pods -o jsonpath='{range .items[*]}{range .spec.containers[*]}{.image}{"\n"}{end}{end}' | sort -u
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" --request-timeout=30s -n flow-cns-system get pods -o jsonpath='{range .items[*]}{range .spec.containers[*]}{.image}{"\n"}{end}{end}' | sort -u
echo "== who serves the VIP =="
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" --request-timeout=30s get pods -A | grep -E 'kube-vip|keepalived' | head -5
