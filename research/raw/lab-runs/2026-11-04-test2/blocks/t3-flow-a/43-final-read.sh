# READ-ONLY
source ~/nkp-skilltest-flow-a.env 2>/dev/null
h="${REGISTRY_URL#*://}"; h="${h%%/*}"
echo "== registry certificate SANs (does an IP mirror URL work?) =="
openssl s_client -connect "$h:443" -servername "$h" </dev/null 2>/dev/null | openssl x509 -noout -ext subjectAltName 2>/dev/null | head -4
echo "== konnector-agent on the flow cluster =="
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" --request-timeout=30s -n ntnx-system get pods -l app.kubernetes.io/name=konnector-agent 2>&1 | head -3
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" --request-timeout=30s -n ntnx-system get pods 2>&1 | tail -4
echo "== HCP + HRP state now =="
kubectl --kubeconfig "$MGMT_KUBECONFIG" --request-timeout=30s -n "$WORKSPACE_NS" get helmchartproxy "$CLUSTER_NAME-flow-cni" -o jsonpath='{range .status.conditions[*]}{.type}={.status} {.reason}{"\n"}{end}' | head -3
kubectl --kubeconfig "$MGMT_KUBECONFIG" --request-timeout=30s -n "$WORKSPACE_NS" get helmreleaseproxies | grep -E 'NAME|flow' 
echo "== helmreleases on the workload cluster (workload branch of Verify) =="
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" --request-timeout=30s get helmreleases -A --no-headers 2>/dev/null | wc -l
echo "== pods per namespace on the flow cluster =="
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" --request-timeout=30s get pods -A --no-headers 2>/dev/null | awk '{print $1, $4}' | sort | uniq -c | sort -rn | head -12
