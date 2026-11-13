# READ-ONLY  (read the nutanix-flow-cni chart from the CAREN chart server through the API server proxy; nothing written to disk)
source ~/nkp-skilltest-flow-b.env 2>/dev/null
P="/api/v1/namespaces/caren-system/services/https:helm-repository:443/proxy"
echo "== manifest =="
kubectl --kubeconfig "$MGMT_KUBECONFIG" --request-timeout=30s get --raw "$P/v2/charts/nutanix-flow-cni/manifests/1.1.0" -H 'Accept: application/vnd.oci.image.manifest.v1+json' 2>/dev/null | head -c 400
echo
lay=$(kubectl --kubeconfig "$MGMT_KUBECONFIG" --request-timeout=30s get --raw "$P/v2/charts/nutanix-flow-cni/manifests/1.1.0" -H 'Accept: application/vnd.oci.image.manifest.v1+json' 2>/dev/null | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d["layers"][0]["digest"])' 2>/dev/null)
echo "layer digest: $lay"
[ -n "$lay" ] || { echo "no digest"; exit 1; }
echo "== chart file list (templates with namespace/hook) =="
kubectl --kubeconfig "$MGMT_KUBECONFIG" --request-timeout=60s get --raw "$P/v2/charts/nutanix-flow-cni/blobs/$lay" 2>/dev/null | tar -tzf - 2>/dev/null | grep -E 'templates/' | head -40
echo "== the failing hook =="
kubectl --kubeconfig "$MGMT_KUBECONFIG" --request-timeout=60s get --raw "$P/v2/charts/nutanix-flow-cni/blobs/$lay" 2>/dev/null | tar -xzOf - 'nutanix-flow-cni/templates/crd-upgrade-serviceaccount.yaml' 2>/dev/null | head -40
