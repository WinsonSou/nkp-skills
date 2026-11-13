# READ-ONLY  (all Helm hooks in the chart: phase, weights, tolerations of the CRD jobs)
set -u
source ~/nkp-site.env 2>/dev/null
proj="${REGISTRY_URL##*/}"; hp="${REGISTRY_URL#*//}"; host="${hp%%/*}"
t=$(curl -sk -u "$REGISTRY_MIRROR_USERNAME:$REGISTRY_MIRROR_PASSWORD" "https://$host/service/token?service=harbor-registry&scope=repository:$proj/nutanix-flow-cni:pull" | python3 -c 'import json,sys;print(json.load(sys.stdin)["token"])')
curl -sk -H "Authorization: Bearer $t" -H 'Accept: application/vnd.oci.image.manifest.v1+json' "https://$host/v2/$proj/nutanix-flow-cni/manifests/1.1.0" -o /tmp/fl-m.json
lay=$(python3 -c 'import json;print(json.load(open("/tmp/fl-m.json"))["layers"][0]["digest"])')
curl -sk -H "Authorization: Bearer $t" "https://$host/v2/$proj/nutanix-flow-cni/blobs/$lay" -o /tmp/fl-c.tgz
echo "== every hook annotation in the chart =="
for f in $(tar -tzf /tmp/fl-c.tgz | grep -E '\.yaml$' | grep templates); do
  a=$(tar -xzOf /tmp/fl-c.tgz "$f" 2>/dev/null | grep -E 'helm.sh/hook' | tr -d ' ' | paste -sd, -)
  [ -n "$a" ] && echo "  $f : $a"
done
echo "== crd-upgrade-job.yaml: hook, nodeSelector, tolerations =="
tar -xzOf /tmp/fl-c.tgz 'nutanix-flow-cni/templates/crd-upgrade-job.yaml' 2>/dev/null | grep -n -E 'hook|nodeSelector|tolerations|effect|key:|operator|hostNetwork|restartPolicy' | head -25
echo "== top-level values crdUpgrade block =="
tar -xzOf /tmp/fl-c.tgz 'nutanix-flow-cni/values.yaml' 2>/dev/null | sed -n '71,118p'
rm -f /tmp/fl-m.json /tmp/fl-c.tgz
