# CHANGES  (creates namespaces ovn-kubernetes and flow-cns-system on workload cluster skilltest-flow-b only)
source ~/nkp-skilltest-flow-b.env 2>/dev/null
for n in ovn-kubernetes flow-cns-system; do
  kubectl --kubeconfig "$CLUSTER_KUBECONFIG" --request-timeout=30s get ns "$n" >/dev/null 2>&1 && echo "already there: $n" || kubectl --kubeconfig "$CLUSTER_KUBECONFIG" --request-timeout=30s create namespace "$n"
done
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" --request-timeout=30s get ns 2>&1 | grep -E 'flow|ovn'
echo "== subchart templates that ship a Namespace, and the ovn hook (chart read from the mirror, in memory) =="
source ~/nkp-site.env 2>/dev/null
proj="${REGISTRY_URL##*/}"; hp="${REGISTRY_URL#*//}"; host="${hp%%/*}"
t=$(curl -sk -u "$REGISTRY_MIRROR_USERNAME:$REGISTRY_MIRROR_PASSWORD" "https://$host/service/token?service=harbor-registry&scope=repository:$proj/nutanix-flow-cni:pull" | python3 -c 'import json,sys;print(json.load(sys.stdin)["token"])')
curl -sk -H "Authorization: Bearer $t" -H 'Accept: application/vnd.oci.image.manifest.v1+json' "https://$host/v2/$proj/nutanix-flow-cni/manifests/1.1.0" -o /tmp/fl-m.json
lay=$(python3 -c 'import json;print(json.load(open("/tmp/fl-m.json"))["layers"][0]["digest"])')
curl -sk -H "Authorization: Bearer $t" "https://$host/v2/$proj/nutanix-flow-cni/blobs/$lay" -o /tmp/fl-c.tgz
tar -tzf /tmp/fl-c.tgz | grep -E 'namespace' | sed 's/^/  /'
echo "  -- ovn subchart hook --"
tar -xzOf /tmp/fl-c.tgz 'nutanix-flow-cni/charts/nutanix-core-flow-ovn-kubernetes/templates/crd-upgrade-serviceaccount.yaml' 2>/dev/null | grep -E 'namespace|hook' | sed 's/^/    /'
echo "  -- ovn subchart values (namespace/crdUpgrade) --"
tar -xzOf /tmp/fl-c.tgz 'nutanix-flow-cni/charts/nutanix-core-flow-ovn-kubernetes/values.yaml' 2>/dev/null | grep -n -E 'namespaceOverride|crdUpgrade|mtu|hostSubnet|podNetwork|serviceNetwork' | head -12
rm -f /tmp/fl-m.json /tmp/fl-c.tgz
