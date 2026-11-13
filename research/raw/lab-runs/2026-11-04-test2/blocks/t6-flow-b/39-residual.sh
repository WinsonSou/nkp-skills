# READ-ONLY  (residual CAREN objects after the delete)
source ~/nkp-skilltest-flow-b.env 2>/dev/null
K="kubectl --kubeconfig $MGMT_KUBECONFIG --request-timeout=30s"
echo "== HCPs =="; $K -n "$WORKSPACE_NS" get helmchartproxies --no-headers 2>&1 | grep -F -- "$CLUSTER_NAME" || echo "  none"
echo "== HRPs (name, chart, deleting) =="
$K -n "$WORKSPACE_NS" get helmreleaseproxies -o jsonpath='{range .items[*]}{.metadata.name}{"  "}{.spec.chartName}{"  deleting="}{.metadata.deletionTimestamp}{"\n"}{end}' 2>&1 | grep -F -- "$CLUSTER_NAME" || echo "  none"
echo "== machines / secrets / cm =="
$K -n "$WORKSPACE_NS" get machines,secrets,cm --no-headers 2>&1 | grep -F -- "$CLUSTER_NAME" | awk '{print "  "$1, $2}' || echo "  none"
echo "== nkpclusters =="; $K -n "$WORKSPACE_NS" get nkpclusters --no-headers 2>&1 || echo "  none"
echo "== VMs in PC with the name (ntnx client runs on the laptop, skipped here) =="
date '+%H:%M:%S'
