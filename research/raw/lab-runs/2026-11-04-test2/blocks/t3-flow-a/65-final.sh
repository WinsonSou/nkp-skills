# READ-ONLY
source ~/nkp-skilltest-flow-a.env 2>/dev/null
date '+%H:%M:%S'
kubectl --kubeconfig "$MGMT_KUBECONFIG" --request-timeout=30s -n "$WORKSPACE_NS" get nkpclusters -o custom-columns='NAME:.metadata.name,PHASE:.status.phase'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" --request-timeout=30s get nodes --no-headers | awk '{print $2}' | sort | uniq -c
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" --request-timeout=30s get pods -A --no-headers | awk '$4!="Running" && $4!="Completed"' | wc -l
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" --request-timeout=30s get ns --no-headers | awk '{print $1}' | grep -E 'skilltest|flow' ; echo "(no skilltest-smoke above = removed)"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" --request-timeout=30s -n kube-system get ds registry-hosts-fix --no-headers
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" --request-timeout=30s get pods -A --no-headers | grep -c probe || echo "no probe pod"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" --request-timeout=30s get svc -A --field-selector spec.type=LoadBalancer --no-headers
