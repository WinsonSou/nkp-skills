# READ-ONLY
source ~/nkp-skilltest-flow-a.env 2>/dev/null
echo "== MANAGEMENT cluster: recent image pull failures (same site DNS) =="
kubectl --kubeconfig "$MGMT_KUBECONFIG" --request-timeout=30s get events -A --field-selector reason=Failed 2>/dev/null | grep -i -E 'pull image|ErrImagePull' | tail -4
echo "== MANAGEMENT cluster: pods not Running (any) =="
kubectl --kubeconfig "$MGMT_KUBECONFIG" --request-timeout=30s get pods -A --field-selector=status.phase!=Running,status.phase!=Succeeded 2>/dev/null | head -5
echo "== FLOW cluster: pull failures now =="
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" --request-timeout=30s get pods -A 2>/dev/null | grep -E 'ImagePull|ErrImage|Init:|0/' | head -10
echo "== FLOW cluster: coredns/ovn/nats/flow ready? =="
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" --request-timeout=30s get pods -n kube-system -n flow-cni-system 2>/dev/null | head -3
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" --request-timeout=30s get pods -A 2>/dev/null | awk 'NR==1 || $4!="Running"' | head -12
