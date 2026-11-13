# READ-ONLY  (what holds the terminating flow HRP: caaph log tail)
source ~/nkp-skilltest-flow-b.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" --request-timeout=30s -n caaph-system logs deploy/caaph-controller-manager --tail=40 2>&1 | grep -i -E 'flow|helmreleaseproxy|uninstall|finaliz' | tail -20
echo "== helm release secrets on the workload cluster (names only) =="
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" --request-timeout=30s get secrets -A 2>/dev/null | grep -E 'sh.helm.release' | awk '{print "  "$1, $2, $3}' | head -10
echo "== flux on the workload side? =="
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" --request-timeout=30s get ns 2>&1 | grep -E 'flux' || echo "  no flux ns on the workload cluster"
