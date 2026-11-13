# READ-ONLY  (re-create progress: watcher log, flow HCP/HRP, nodes)
source ~/nkp-skilltest-flow-b.env 2>/dev/null
K="kubectl --kubeconfig $MGMT_KUBECONFIG --request-timeout=30s"
echo "== watcher log =="; cat "$HOME/nkp-$CLUSTER_NAME-nswatch.log" 2>&1 | tail -8
echo "== flow HCP conditions =="
hcp=$($K -n "$WORKSPACE_NS" get helmchartproxies --no-headers 2>/dev/null | awk '/flow-cni/{print $1}')
echo "  hcp=$hcp"
$K -n "$WORKSPACE_NS" get helmchartproxy "$hcp" -o jsonpath='{range .status.conditions[*]}{.type}={.status} {.reason}{"\n"}{end}' 2>&1 | head -4
echo "== flow HRP =="
$K -n "$WORKSPACE_NS" get helmreleaseproxies -o custom-columns='NAME:.metadata.name,CHART:.spec.chartName,READY:.status.conditions[?(@.type=="Ready")].status' --no-headers 2>&1 | grep -E 'flow'
$K -n "$WORKSPACE_NS" get helmreleaseproxies -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{range .status.conditions[*]}  {.type}={.status} {.message}{"\n"}{end}{end}' 2>&1 | grep -A3 flow-cni | head -6
echo "== nodes / flow pods on the workload cluster =="
K2="kubectl --kubeconfig $CLUSTER_KUBECONFIG --request-timeout=30s"
$K2 get nodes --no-headers 2>&1 | awk '{print "  "$1, $2}' | head -8
$K2 get ns --no-headers 2>&1 | awk '{print "  ns "$1}' | grep -E 'flow|ovn'
$K2 get pods -A 2>&1 | grep -E 'flow|ovn' | head -10
echo "== helm release versions =="; $K2 get secrets -n kube-system --no-headers 2>/dev/null | grep -c 'sh.helm.release.v1.flow-cni' | sed 's/^/  flow-cni release versions: /'
