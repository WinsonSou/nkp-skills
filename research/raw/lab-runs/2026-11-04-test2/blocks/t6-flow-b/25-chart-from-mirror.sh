# READ-ONLY  (read chart nutanix-flow-cni:1.1.0 from the site mirror Harbor, in memory: manifest -> blob -> template)
set -u
source ~/nkp-site.env 2>/dev/null
proj="${REGISTRY_URL##*/}"; hp="${REGISTRY_URL#*//}"; host="${hp%%/*}"
tok() { curl -sk -u "$REGISTRY_MIRROR_USERNAME:$REGISTRY_MIRROR_PASSWORD" "https://$host/service/token?service=harbor-registry&scope=repository:$proj/$1:pull" | python3 -c 'import json,sys;print(json.load(sys.stdin)["token"])'; }
t=$(tok nutanix-flow-cni)
echo "== manifest head =="
curl -sk -H "Authorization: Bearer $t" -H 'Accept: application/vnd.oci.image.manifest.v1+json' "https://$host/v2/$proj/nutanix-flow-cni/manifests/1.1.0" -o /tmp/fl-chart-manifest.json -w 'http=%{http_code}\n'
lay=$(python3 -c 'import json;print(json.load(open("/tmp/fl-chart-manifest.json"))["layers"][0]["digest"])' 2>/dev/null)
echo "layer=$lay"
[ -n "${lay:-}" ] || { head -c 300 /tmp/fl-chart-manifest.json; exit 1; }
curl -sk -H "Authorization: Bearer $t" "https://$host/v2/$proj/nutanix-flow-cni/blobs/$lay" -o /tmp/fl-chart.tgz -w 'blob http=%{http_code} bytes=%{size_download}\n'
echo "== templates =="
tar -tzf /tmp/fl-chart.tgz | grep -E 'templates/' | head -45
echo "== crd-upgrade-serviceaccount hook =="
tar -xzOf /tmp/fl-chart.tgz 'nutanix-flow-cni/templates/crd-upgrade-serviceaccount.yaml' 2>/dev/null | head -40
rm -f /tmp/fl-chart-manifest.json /tmp/fl-chart.tgz
