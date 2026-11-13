# READ-ONLY  (path B cluster state: nodes, flow/ovn pods, ovn-config, cilium/kube-proxy, pulls)
source ~/nkp-skilltest-flow-b.env 2>/dev/null
K="kubectl --kubeconfig $MGMT_KUBECONFIG --request-timeout=30s"
K2="kubectl --kubeconfig $CLUSTER_KUBECONFIG --request-timeout=30s"
echo "== flow HCP/HRP =="
$K -n "$WORKSPACE_NS" get helmchartproxies --no-headers 2>&1 | grep flow
$K -n "$WORKSPACE_NS" get helmreleaseproxies -o custom-columns='NAME:.metadata.name,READY:.status.conditions[?(@.type=="Ready")].status' --no-headers 2>&1 | grep flow
echo "== nodes =="; $K2 get nodes --no-headers 2>&1 | awk '{print "  "$1, $2}'
echo "== daemonsets =="; $K2 get ds -A 2>&1 | grep -E 'NAME|cilium|ovn|kube-proxy|flow|multus' | sed 's/^/  /'
echo "== ovn-config (CIDRs, MTU) =="
$K2 -n ovn-kubernetes get configmaps -o yaml 2>/dev/null | grep -E 'mtu|net_cidr|svc_cidr|k8s_apiserver|host_network_namespace' | sed 's/^/  /'
echo "== flow pods not Running =="
$K2 get pods -A 2>&1 | grep -E 'flow|ovn' | grep -v -E 'Running|Completed' | head -10
echo "== any pull failure (the t3 L-07 signature) =="
$K2 get events -A --request-timeout=30s 2>/dev/null | grep -i -E 'server misbehaving|ImagePullBackOff|ErrImagePull' | head -5 || echo "  none"
echo "== konnector =="; $K2 -n ntnx-system get pods --no-headers 2>&1 | awk '{print "  "$1, $2, $3}'
echo "== helmreleases on the workload cluster =="; $K2 get helmreleases -A --no-headers 2>&1 | wc -l
