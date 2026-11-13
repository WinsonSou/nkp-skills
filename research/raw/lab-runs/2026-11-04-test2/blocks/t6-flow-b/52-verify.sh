# READ-ONLY  (nkp-flow-cni step 4 Done-when + nkp-install verify, on path B)
source ~/nkp-skilltest-flow-b.env 2>/dev/null
K="kubectl --kubeconfig $MGMT_KUBECONFIG --request-timeout=30s"
K2="kubectl --kubeconfig $CLUSTER_KUBECONFIG --request-timeout=30s"
hcp=$($K -n "$WORKSPACE_NS" get helmchartproxies --no-headers 2>/dev/null | awk '/flow-cni/{print $1}')
echo "== HCP =="; $K -n "$WORKSPACE_NS" get helmchartproxy "$hcp" -o jsonpath='{range .status.conditions[*]}{.type}={.status} {.reason} {.message}{"\n"}{end}' 2>&1 | head -4
echo "== HRP with chart nutanix-flow-cni =="
$K -n "$WORKSPACE_NS" get helmreleaseproxies -o custom-columns='NAME:.metadata.name,CHART:.spec.chartName,READY:.status.conditions[?(@.type=="Ready")].status' --no-headers 2>&1 | grep -E 'flow-cni' 
echo "== nodes =="; $K2 get nodes --no-headers 2>&1 | awk '{print "  "$2}' | sort | uniq -c
echo "== flow / ovn pods =="; $K2 get pods -A 2>&1 | grep -E 'flow-cni|flow-cns|ovn|multus' | awk '{print "  "$1, $2, $3, $4}' | head -14
echo "== cilium / kube-proxy daemonsets (must be none) =="; $K2 get ds -A 2>&1 | grep -E 'cilium|kube-proxy' || echo "  none"
echo "== konnector-agent =="; $K2 -n ntnx-system get pods --no-headers 2>&1 | awk '{print "  "$1, $2, $3}' | head -3
echo "== nkpcluster phase =="; $K -n "$WORKSPACE_NS" get nkpclusters --no-headers 2>&1
echo "== kommandercluster =="; $K -n "$WORKSPACE_NS" get kommanderclusters --no-headers 2>&1 | head -3
echo "== helmreleases on the workload cluster =="; $K2 get helmreleases -A --no-headers 2>&1 | awk '{print "  "$1, $2, $3}' | head -22
echo "== count not Ready =="; $K2 get helmreleases -A --no-headers 2>&1 | awk '$2!="True"' | head -5
