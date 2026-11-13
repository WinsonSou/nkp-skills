# READ-ONLY
source ~/nkp-site.env 2>/dev/null
source ~/nkp-skilltest-flow-a.env 2>/dev/null
KC="--request-timeout=30s"
date '+now %F %T'
echo "--- D3 check on the management cluster"
kubectl --kubeconfig "$MGMT_KUBECONFIG" $KC -n "$WORKSPACE_NS" get nkpclusters,clusters.cluster.x-k8s.io,machines -l "cluster.x-k8s.io/cluster-name=$CLUSTER_NAME" 2>&1
kubectl --kubeconfig "$MGMT_KUBECONFIG" $KC -n "$WORKSPACE_NS" get nkpcluster "$CLUSTER_NAME" 2>&1
echo "--- IPs of the cluster"
ping -c 2 -W 2 "$CP_VIP" 2>&1 | tail -3
curl -sk -o /dev/null -w 'cp_vip_https=%{http_code}\n' --max-time 5 "https://${CP_VIP}:6443/version"
curl -sk -o /dev/null -w 'lb_first_ip=%{http_code}\n' --max-time 5 "https://${LB_IP_RANGE%%-*}/"
echo "--- what stays in the workspace namespace"
kubectl --kubeconfig "$MGMT_KUBECONFIG" $KC -n "$WORKSPACE_NS" get helmchartproxies 2>&1
kubectl --kubeconfig "$MGMT_KUBECONFIG" $KC -n "$WORKSPACE_NS" get helmreleaseproxies 2>&1
kubectl --kubeconfig "$MGMT_KUBECONFIG" $KC -n "$WORKSPACE_NS" get secrets 2>&1 | grep -F -- "$CLUSTER_NAME"
echo "--- anything else with the name on the management cluster (all ns)"
kubectl --kubeconfig "$MGMT_KUBECONFIG" $KC get all,nkpclusters,clusters.cluster.x-k8s.io,machines,machinedeployments,secrets,configmaps -A 2>/dev/null | grep -F -- "$CLUSTER_NAME" | head -30
echo "--- operator host files"
ls -a "$HOME" | grep -F -- "$CLUSTER_NAME"
echo "--- workspace and mgmt cluster still there"
kubectl --kubeconfig "$MGMT_KUBECONFIG" $KC get nkpclusters -A 2>&1
kubectl --kubeconfig "$MGMT_KUBECONFIG" $KC get workspaces 2>&1
kubectl --kubeconfig "$MGMT_KUBECONFIG" $KC get ns "$WORKSPACE_NS" 2>&1
