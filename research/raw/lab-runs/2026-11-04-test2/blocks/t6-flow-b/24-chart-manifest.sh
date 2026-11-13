# READ-ONLY  (what the CAREN chart server returns for the chart manifest without an Accept header)
source ~/nkp-skilltest-flow-b.env 2>/dev/null
P="/api/v1/namespaces/caren-system/services/https:helm-repository:443/proxy"
echo "== tags =="; kubectl --kubeconfig "$MGMT_KUBECONFIG" --request-timeout=30s get --raw "$P/v2/charts/nutanix-flow-cni/tags/list" 2>&1 | head -c 200; echo
echo "== manifest, default accept =="; kubectl --kubeconfig "$MGMT_KUBECONFIG" --request-timeout=30s get --raw "$P/v2/charts/nutanix-flow-cni/manifests/1.1.0" 2>&1 | head -c 600; echo
echo "== index? =="; kubectl --kubeconfig "$MGMT_KUBECONFIG" --request-timeout=30s get --raw "$P/v2/charts/nutanix-flow-cni/manifests/1.1.0" -v=0 2>&1 | head -c 300; echo
