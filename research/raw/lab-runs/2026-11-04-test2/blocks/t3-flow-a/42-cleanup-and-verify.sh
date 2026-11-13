# CHANGES  (deletes the two exploration probe pods) then READ-ONLY verify (nkp-install "Verify", workload branch)
source ~/nkp-skilltest-flow-a.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" --request-timeout=60s -n default delete pod dnsprobe-flow --wait=false 2>&1 | head -2
kubectl --kubeconfig "$MGMT_KUBECONFIG" --request-timeout=60s -n kommander delete pod dnsprobe-mgmt --wait=false 2>&1 | head -2
echo "== ntnx-system + metallb on the flow cluster =="
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" --request-timeout=30s -n ntnx-system get pods 2>&1 | head -5
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" --request-timeout=30s -n metallb-system get pods,ipaddresspools 2>&1 | head -8
echo "== kommanderclusters / nkpclusters (mgmt view) =="
kubectl --kubeconfig "$MGMT_KUBECONFIG" --request-timeout=30s -n "$WORKSPACE_NS" get kommanderclusters "$CLUSTER_NAME" -o custom-columns='NAME:.metadata.name,STATUS:.status.conditions[?(@.type=="Ready")].status' 2>&1 | head -4
kubectl --kubeconfig "$MGMT_KUBECONFIG" --request-timeout=30s -n "$WORKSPACE_NS" get nkpclusters -o custom-columns='NAME:.metadata.name,PHASE:.status.phase'
echo "== nkp describe (machine rows) =="
nkp describe cluster --cluster-name "$CLUSTER_NAME" --namespace "$WORKSPACE_NS" --kubeconfig "$MGMT_KUBECONFIG" 2>&1 | tail -20
