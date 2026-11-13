# CHANGES  (deletes the failed Flow HelmReleaseProxy so CAAPH recreates it as a fresh install; the CAREN HCP is unchanged)
source ~/nkp-skilltest-flow-b.env 2>/dev/null
hrp=$(kubectl --kubeconfig "$MGMT_KUBECONFIG" --request-timeout=30s -n "$WORKSPACE_NS" get helmreleaseproxies --no-headers 2>/dev/null | awk '/nutanix-flow-cni/{print $1}' | head -1)
echo "hrp=$hrp"
[ -n "$hrp" ] || { echo "no flow HRP"; exit 1; }
kubectl --kubeconfig "$MGMT_KUBECONFIG" --request-timeout=30s -n "$WORKSPACE_NS" delete helmreleaseproxy "$hrp"
echo "RC=$?"
sleep 20
echo "== HRPs after the delete =="
kubectl --kubeconfig "$MGMT_KUBECONFIG" --request-timeout=30s -n "$WORKSPACE_NS" get helmreleaseproxies -o custom-columns='NAME:.metadata.name,CHART:.spec.chartName,READY:.status.conditions[?(@.type=="Ready")].status' --no-headers 2>&1 | grep flow || echo "  none yet"
