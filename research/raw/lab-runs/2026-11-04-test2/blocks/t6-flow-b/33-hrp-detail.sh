# READ-ONLY  (is the Flow HRP a fresh install or still an upgrade? and what does Flux say?)
source ~/nkp-skilltest-flow-b.env 2>/dev/null
K="kubectl --kubeconfig $MGMT_KUBECONFIG --request-timeout=30s"
hrp=$($K -n "$WORKSPACE_NS" get helmreleaseproxies --no-headers 2>/dev/null | awk '/nutanix-flow-cni/{print $1}' | head -1)
echo "hrp=$hrp"
$K -n "$WORKSPACE_NS" get helmreleaseproxy "$hrp" -o jsonpath='{.metadata.creationTimestamp}{"  helmReleaseStatus="}{.status.helmReleaseStatus}{"\n"}' 2>&1
$K -n "$WORKSPACE_NS" get helmreleaseproxy "$hrp" -o jsonpath='{range .status.conditions[*]}{.type}={.status} {.reason} {.message}{"\n"}{end}' 2>&1 | head -5
echo "== flux helmreleases on the management cluster for this cluster =="
$K -n "$WORKSPACE_NS" get helmreleases.helm.toolkit.fluxcd.io 2>&1 | grep -E 'NAME|flow' | head -5
$K -n "$WORKSPACE_NS" get helmreleases.helm.toolkit.fluxcd.io -o custom-columns='NAME:.metadata.name,READY:.status.conditions[?(@.type=="Ready")].status,REV:.status.lastAttemptedRevision' --no-headers 2>&1 | grep flow | head -3
echo "== its message =="
$K -n "$WORKSPACE_NS" get helmreleases.helm.toolkit.fluxcd.io -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{range .status.conditions[*]}  {.type}={.status} {.message}{"\n"}{end}{end}' 2>&1 | grep -A3 flow-cni | head -8
