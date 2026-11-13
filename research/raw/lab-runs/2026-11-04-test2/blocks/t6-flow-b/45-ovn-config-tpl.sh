# READ-ONLY  (how the ovn subchart consumes podNetwork: expected format)
set -u
source ~/nkp-site.env 2>/dev/null
proj="${REGISTRY_URL##*/}"; hp="${REGISTRY_URL#*//}"; host="${hp%%/*}"
t=$(curl -sk -u "$REGISTRY_MIRROR_USERNAME:$REGISTRY_MIRROR_PASSWORD" "https://$host/service/token?service=harbor-registry&scope=repository:$proj/nutanix-flow-cni:pull" | python3 -c 'import json,sys;print(json.load(sys.stdin)["token"])')
curl -sk -H "Authorization: Bearer $t" -H 'Accept: application/vnd.oci.image.manifest.v1+json' "https://$host/v2/$proj/nutanix-flow-cni/manifests/1.1.0" -o /tmp/fl-m.json
lay=$(python3 -c 'import json;print(json.load(open("/tmp/fl-m.json"))["layers"][0]["digest"])')
curl -sk -H "Authorization: Bearer $t" "https://$host/v2/$proj/nutanix-flow-cni/blobs/$lay" -o /tmp/fl-c.tgz
O='nutanix-flow-cni/charts/nutanix-core-flow-ovn-kubernetes'
echo "== ovn subchart templates =="; tar -tzf /tmp/fl-c.tgz | grep "$O/templates/" | head -20
echo "== who renders net_cidr =="
for f in $(tar -tzf /tmp/fl-c.tgz | grep "$O/templates/.*\.yaml$"); do
  n=$(tar -xzOf /tmp/fl-c.tgz "$f" | grep -c 'net_cidr' || true); [ "$n" != "0" ] && echo "  $f"; done
echo "== the net_cidr rendering lines =="
for f in $(tar -tzf /tmp/fl-c.tgz | grep "$O/templates/.*\.yaml$"); do
  out=$(tar -xzOf /tmp/fl-c.tgz "$f" | grep -n -B2 -A2 'net_cidr' || true); [ -n "$out" ] && { echo "  --- $f"; echo "$out" | sed 's/^/    /'; }; done
rm -f /tmp/fl-m.json /tmp/fl-c.tgz
