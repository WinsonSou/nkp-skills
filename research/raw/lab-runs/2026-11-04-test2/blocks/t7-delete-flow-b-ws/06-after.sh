# READ-ONLY
source ~/nkp-skilltest-flow-b.env 2>/dev/null
echo "== D3 check: cluster objects =="
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get nkpclusters,clusters.cluster.x-k8s.io,machines -l "cluster.x-k8s.io/cluster-name=$CLUSTER_NAME" --request-timeout=30s
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get nkpcluster "$CLUSTER_NAME" --request-timeout=30s
echo "== D3 check: IPs =="
ping -c 2 -W 2 "$CP_VIP" >/dev/null 2>&1 && echo "cp_vip answers" || echo "cp_vip no answer"
echo "cp_vip_https=$(curl -sk -o /dev/null -w '%{http_code}' --max-time 5 "https://${CP_VIP}:6443/")"
echo "lb_first_ip=$(curl -sk -o /dev/null -w '%{http_code}' --max-time 5 "https://${LB_IP_RANGE%%-*}/")"
echo "== what stayed: HCPs and HRPs in the workspace ns =="
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get helmchartproxies --request-timeout=30s
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get helmreleaseproxies --request-timeout=30s
echo "== what stayed: every object with the cluster name in the workspace ns =="
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get cm,secret --request-timeout=30s | grep -F -- "$CLUSTER_NAME"
echo "== what stayed: all namespaces, kinds cm,secret,deploy,svc,ds =="
kubectl --kubeconfig "$MGMT_KUBECONFIG" get cm,deploy,svc,ds -A --request-timeout=30s | grep -F -- "$CLUSTER_NAME"
echo "== kept as told =="
kubectl --kubeconfig "$MGMT_KUBECONFIG" get nkpclusters -A --request-timeout=30s
kubectl --kubeconfig "$MGMT_KUBECONFIG" get workspaces --request-timeout=30s
kubectl --kubeconfig "$MGMT_KUBECONFIG" get ns "$WORKSPACE_NS" --request-timeout=30s
echo "== operator host files =="
ls -l "$HOME" | grep -F -- "$CLUSTER_NAME"
