# CHANGES  (deletes the pods that are stuck in ImagePullBackOff so that their controllers pull again now that the hosts entry exists)
source ~/nkp-skilltest-flow-a.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" --request-timeout=60s -n kommander-flux delete pods --all --wait=false 2>&1 | tail -3
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" --request-timeout=60s -n flow-cns-system delete pods --all --wait=false 2>&1 | tail -3
echo done
