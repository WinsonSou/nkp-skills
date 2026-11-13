# READ-ONLY
source ~/nkp-skilltest-flow-a.env 2>/dev/null
date '+%H:%M:%S'
kubectl --kubeconfig "$MGMT_KUBECONFIG" --request-timeout=30s -n "$WORKSPACE_NS" get kommanderclusters "$CLUSTER_NAME" -o jsonpath='{range .status.conditions[*]}{.type}={.status} {.message}{"\n"}{end}' 2>/dev/null | grep -E 'AppDeployments|Ingress' | head -3
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" --request-timeout=30s get helmreleases -A --no-headers 2>/dev/null | wc -l
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" --request-timeout=30s get helmreleases -A 2>/dev/null | awk 'NR==1 || $4!="True"' | head -10
kubectl --kubeconfig "$MGMT_KUBECONFIG" --request-timeout=30s -n "$WORKSPACE_NS" get nkpclusters -o custom-columns='PHASE:.status.phase' --no-headers
