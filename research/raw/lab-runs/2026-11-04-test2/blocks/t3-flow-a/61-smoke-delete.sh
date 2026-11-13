# CHANGES  (deletes the namespace with the PVC, the pod, and the Service; frees the LB IP)
source ~/nkp-skilltest-flow-a.env 2>/dev/null
ns='skilltest-smoke'
date '+%H:%M:%S start'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" --request-timeout=300s delete namespace "$ns" --timeout=4m
echo "RC=$?"
date '+%H:%M:%S end'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" --request-timeout=30s get ns "$ns" 2>&1 | head -2
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" --request-timeout=30s get pv -o custom-columns='NAME:.metadata.name,HANDLE:.spec.csi.volumeHandle' | grep -c nutanix || true
