# READ-ONLY  (F-07: which platform apps do and do not work on a Flow CNI cluster)
source ~/nkp-skilltest-flow-a.env 2>/dev/null
date '+%H:%M:%S'
echo "== helmreleases on the workload cluster: total / per namespace =="
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" --request-timeout=30s get helmreleases -A --no-headers 2>/dev/null | wc -l
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" --request-timeout=30s get helmreleases -A --no-headers 2>/dev/null | awk '{print $1}' | sort | uniq -c
echo "== NOT ready =="
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" --request-timeout=30s get helmreleases -A 2>/dev/null | awk 'NR==1 || $4!="True"'
echo "== appdeployments (workspace view) =="
kubectl --kubeconfig "$MGMT_KUBECONFIG" --request-timeout=30s -n "$WORKSPACE_NS" get appdeployments --no-headers 2>/dev/null | wc -l
echo "== nkpcluster / kommandercluster =="
kubectl --kubeconfig "$MGMT_KUBECONFIG" --request-timeout=30s -n "$WORKSPACE_NS" get nkpclusters -o custom-columns='NAME:.metadata.name,PHASE:.status.phase'
kubectl --kubeconfig "$MGMT_KUBECONFIG" --request-timeout=30s -n "$WORKSPACE_NS" get kommanderclusters "$CLUSTER_NAME" -o jsonpath='{range .status.conditions[*]}{.type}={.status} {.message}{"\n"}{end}' 2>/dev/null | head -4
echo "== pods not Running =="
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" --request-timeout=30s get pods -A 2>/dev/null | awk 'NR==1 || $4!="Running"' | head -12
echo "== LB services now (traefik?) =="
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" --request-timeout=30s get svc -A --field-selector spec.type=LoadBalancer 2>/dev/null
