# READ-ONLY
source ~/nkp-nkp-mgmt-01.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" --request-timeout=30s -n kommander get nkpclusters
kubectl --kubeconfig "$MGMT_KUBECONFIG" --request-timeout=30s -n kommander get licenses.kommander.mesosphere.io nutanix-license -o jsonpath='tier={.status.dkpLevel} valid={.status.valid} end={.status.endDate}{"\n"}'
kubectl --kubeconfig "$MGMT_KUBECONFIG" --request-timeout=30s get workspaces
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" --request-timeout=30s get nodes --no-headers | awk '{print $2}' | sort | uniq -c
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" --request-timeout=30s get pods -A --field-selector=status.phase!=Running,status.phase!=Succeeded 2>/dev/null; echo "(end of not-running list)"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" --request-timeout=30s get pods -A --no-headers | wc -l
echo "--- block_node list (skill cross-check)"
kubectl --kubeconfig "$MGMT_KUBECONFIG" --request-timeout=30s -n kommander get nkpclusters -o custom-columns='NAME:.metadata.name,COMMANDER:.spec.kommanderCluster.spec.ociRegistry.mirrorURL'
