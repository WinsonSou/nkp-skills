# READ-ONLY  (chart helpers and values: where does the release namespace come from?)
set -u
source ~/nkp-site.env 2>/dev/null
proj="${REGISTRY_URL##*/}"; hp="${REGISTRY_URL#*//}"; host="${hp%%/*}"
t=$(curl -sk -u "$REGISTRY_MIRROR_USERNAME:$REGISTRY_MIRROR_PASSWORD" "https://$host/service/token?service=harbor-registry&scope=repository:$proj/nutanix-flow-cni:pull" | python3 -c 'import json,sys;print(json.load(sys.stdin)["token"])')
curl -sk -H "Authorization: Bearer $t" -H 'Accept: application/vnd.oci.image.manifest.v1+json' "https://$host/v2/$proj/nutanix-flow-cni/manifests/1.1.0" -o /tmp/fl-m.json
lay=$(python3 -c 'import json;print(json.load(open("/tmp/fl-m.json"))["layers"][0]["digest"])')
curl -sk -H "Authorization: Bearer $t" "https://$host/v2/$proj/nutanix-flow-cni/blobs/$lay" -o /tmp/fl-c.tgz
echo "== flow-cni.namespace helper =="
tar -xzOf /tmp/fl-c.tgz 'nutanix-flow-cni/templates/_helpers.tpl' | grep -n -A8 'define "flow-cni.namespace"'
echo "== values.yaml (namespace / crdUpgrade keys) =="
tar -xzOf /tmp/fl-c.tgz 'nutanix-flow-cni/values.yaml' | grep -n -E '^[a-zA-Z]|namespace|crdUpgrade|hostPrefix|podNetwork|serviceNetwork|k8sAPIServer|mtu' | head -40
echo "== namespace template =="
tar -tzf /tmp/fl-c.tgz | grep -E 'templates/.*namespace' || echo "  no Namespace template in the chart"
echo "== who creates flow-cni-system? grep all templates for the literal =="
for f in $(tar -tzf /tmp/fl-c.tgz | grep -E '^nutanix-flow-cni/templates/.*\.yaml$'); do
  n=$(tar -xzOf /tmp/fl-c.tgz "$f" | grep -c 'flow-cni-system' || true); [ "$n" != "0" ] && echo "  $f: $n"; done
rm -f /tmp/fl-m.json /tmp/fl-c.tgz
