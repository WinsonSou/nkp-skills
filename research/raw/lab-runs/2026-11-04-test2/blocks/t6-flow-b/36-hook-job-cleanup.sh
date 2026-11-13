# CHANGES  (deletes the pending Flow CRD hook Job on workload cluster skilltest-flow-b only; it is one failed upgrade's hook artifact)
source ~/nkp-skilltest-flow-b.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" --request-timeout=30s -n flow-cni-system get jobs 2>&1
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" --request-timeout=30s -n flow-cni-system delete job flow-cni-crd-hook --ignore-not-found
echo "RC=$?"
echo "== labeler hook: hostNetwork? (chart read from the mirror) =="
source ~/nkp-site.env 2>/dev/null
proj="${REGISTRY_URL##*/}"; hp="${REGISTRY_URL#*//}"; host="${hp%%/*}"
t=$(curl -sk -u "$REGISTRY_MIRROR_USERNAME:$REGISTRY_MIRROR_PASSWORD" "https://$host/service/token?service=harbor-registry&scope=repository:$proj/nutanix-flow-cni:pull" | python3 -c 'import json,sys;print(json.load(sys.stdin)["token"])')
curl -sk -H "Authorization: Bearer $t" -H 'Accept: application/vnd.oci.image.manifest.v1+json' "https://$host/v2/$proj/nutanix-flow-cni/manifests/1.1.0" -o /tmp/fl-m.json
lay=$(python3 -c 'import json;print(json.load(open("/tmp/fl-m.json"))["layers"][0]["digest"])')
curl -sk -H "Authorization: Bearer $t" "https://$host/v2/$proj/nutanix-flow-cni/blobs/$lay" -o /tmp/fl-c.tgz
tar -xzOf /tmp/fl-c.tgz 'nutanix-flow-cni/templates/namespace-labeler-hook.yaml' 2>/dev/null | grep -n -E 'hostNetwork|namespace:|tolerations|effect|serviceAccount|kind:' | head -20
rm -f /tmp/fl-m.json /tmp/fl-c.tgz
echo "== the CRD hook job: hostNetwork? =="
