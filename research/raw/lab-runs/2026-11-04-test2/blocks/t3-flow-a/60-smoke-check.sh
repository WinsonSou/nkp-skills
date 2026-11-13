# READ-ONLY  (C12 step 4)
source ~/nkp-skilltest-flow-a.env 2>/dev/null
ns='skilltest-smoke'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" --request-timeout=30s -n "$ns" get pods,pvc,svc 2>&1 | head -10
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" --request-timeout=30s get pv -o custom-columns='NAME:.metadata.name,NS:.spec.claimRef.namespace,PVC:.spec.claimRef.name,HANDLE:.spec.csi.volumeHandle,STATUS:.status.phase' | grep -E "^NAME|$ns"
ip=$(kubectl --kubeconfig "$CLUSTER_KUBECONFIG" --request-timeout=30s -n "$ns" get svc smoke-lb -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "ip=$ip"
[ -n "$ip" ] && { curl -s --noproxy '*' --max-time 10 -o /dev/null -w 'http=%{http_code}\n' "http://$ip/"; curl -s --noproxy '*' --max-time 10 "http://$ip/"; }
