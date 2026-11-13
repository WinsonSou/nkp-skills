# CHANGES  (creates the 5 Secrets of the dry-run file in skilltest-flow-dw97w on the management cluster; no VMs)
source ~/nkp-skilltest-flow-b.env 2>/dev/null
f="$HOME/$CLUSTER_NAME-dryrun.yaml"; test -s "$f" || { echo "no dry-run file"; exit 1; }
yq 'select(.kind == "Secret")' "$f" | kubectl --kubeconfig "$MGMT_KUBECONFIG" --request-timeout=30s apply --server-side -f - -o name
echo "RC=$?"
kubectl --kubeconfig "$MGMT_KUBECONFIG" --request-timeout=30s -n "$WORKSPACE_NS" get secrets --no-headers 2>/dev/null | awk '{print "  " $1}' | grep -F -- "$CLUSTER_NAME" || echo "  none"
