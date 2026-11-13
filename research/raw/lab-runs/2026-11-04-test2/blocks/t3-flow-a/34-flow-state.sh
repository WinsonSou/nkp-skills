# READ-ONLY
source ~/nkp-skilltest-flow-a.env 2>/dev/null
echo "== DaemonSets (cilium/kube-proxy/ovn/flow/multus) =="
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" --request-timeout=30s get ds -A 2>/dev/null | grep -E 'NAME|cilium|kube-proxy|ovn|flow|multus|nats'
echo "== CRDs (F-04) =="
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" --request-timeout=30s get crds 2>/dev/null | grep -i -E 'ovn|flow|nutanix' | head -12
echo "== MTU sources (F-05) =="
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" --request-timeout=30s -n ovn-kubernetes get cm 2>&1 | head -5
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" --request-timeout=30s -n flow-cni-system get cm 2>&1 | head -5
echo "== a pod interface MTU (node -> pod) =="
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" --request-timeout=30s get nodes -o jsonpath='{range .items[0:1]}{.metadata.name}{"\n"}{end}'
echo "== cluster-wide pull failures =="
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" --request-timeout=30s get events -A --field-selector reason=Failed 2>/dev/null | grep -i -E 'pull|Image' | tail -5
echo "== EgressIP / EgressService CRDs usable =="
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" --request-timeout=30s api-resources 2>/dev/null | grep -i -E 'egressip|egressservice|flow' | head -8
