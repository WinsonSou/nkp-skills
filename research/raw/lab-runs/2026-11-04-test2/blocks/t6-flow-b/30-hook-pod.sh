# READ-ONLY  (why the Flow CRD hook pod is Pending; the hook Job spec)
source ~/nkp-skilltest-flow-b.env 2>/dev/null
K="kubectl --kubeconfig $CLUSTER_KUBECONFIG --request-timeout=30s"
echo "== hook pods =="; $K get pods -n flow-cni-system -o wide 2>&1 | tail -5
echo "== events of the hook pod =="; $K -n flow-cni-system get events --sort-by=.lastTimestamp 2>&1 | tail -8
echo "== hook job: nodeSelector / tolerations / hostNetwork =="
JOB=$($K -n flow-cni-system get jobs --no-headers 2>/dev/null | awk '{print $1}' | head -1)
echo "  job=$JOB"
$K -n flow-cni-system get job "$JOB" -o jsonpath='{.spec.template.spec.hostNetwork}{" hostNetwork="}{.spec.template.spec.nodeSelector}{" nodeSelector="}{.spec.template.spec.tolerations}{"\n"}' 2>&1 | head -3
$K -n flow-cni-system get pods -o jsonpath='{range .items[*]}{.metadata.name}{" phase="}{.status.phase}{" reason="}{.status.conditions[?(@.type=="PodScheduled")].message}{"\n"}{end}' 2>&1 | head -5
echo "== node taints / readiness detail =="
$K get nodes -o jsonpath='{range .items[*]}{.metadata.name}{" ready="}{.status.conditions[?(@.type=="Ready")].status}{" taints="}{.spec.taints}{"\n"}{end}' 2>&1 | head -8
