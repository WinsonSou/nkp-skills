# READ-ONLY  (F-07 detail: what the Cilium-dependent app does on a Flow CNI cluster)
source ~/nkp-skilltest-flow-a.env 2>/dev/null
echo "== all helmreleases (workspace ns) =="
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" --request-timeout=30s -n "$WORKSPACE_NS" get helmreleases -o custom-columns='NAME:.metadata.name,READY:.status.conditions[?(@.type=="Ready")].status,CHART:.spec.chart.spec.chart,VERSION:.spec.chart.spec.version' --no-headers 2>/dev/null
echo "== cilium objects on the cluster =="
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" --request-timeout=30s get ds,deploy -A 2>/dev/null | grep -i cilium || echo "no cilium workload"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" --request-timeout=30s get svc -A 2>/dev/null | grep -i hubble || echo "no hubble service"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" --request-timeout=30s get crds 2>/dev/null | grep -i cilium | head -5 || echo "no cilium CRDs"
echo "== traefik ingressroutes =="
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" --request-timeout=30s get ingressroutes -A 2>/dev/null | head -8
echo "== total pods / nodes =="
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" --request-timeout=30s get pods -A --no-headers 2>/dev/null | wc -l
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" --request-timeout=30s get nodes --no-headers 2>/dev/null | wc -l
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" --request-timeout=30s get ns 2>/dev/null | grep flow
