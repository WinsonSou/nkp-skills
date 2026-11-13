# READ-ONLY
source ~/nkp-site.env 2>/dev/null
ns='skilltest-flow-dw97w'
echo "== clusterclass in $ns =="
kubectl --kubeconfig "$MGMT_KUBECONFIG" --request-timeout=30s -n "$ns" get clusterclass -o custom-columns='NAME:.metadata.name'
echo "== existing flow/ovn images in the site mirror =="
h="${REGISTRY_URL#https://}"; h="${h%%/*}"; proj="${REGISTRY_URL#*/}"
curl -s --cacert "$REGISTRY_CA_FILE" --netrc-file <(printf 'machine %s login %s password %s\n' "$h" "$(printenv REGISTRY_MIRROR_USERNAME)" "$(printenv REGISTRY_MIRROR_PASSWORD)") -o /tmp/_cat.json -w 'catalog: %{http_code}\n' "https://$h/v2/_catalog?n=10000"
python3 -c "import json;d=json.load(open('/tmp/_cat.json'));r=[x for x in d.get('repositories',[]) if 'flow' in x or 'ovn' in x or 'multus' in x or 'nats' in x];print('flow/ovn/multus/nats repos:',len(r));print(chr(10).join(sorted(r)[:20]))" 2>/dev/null || echo "catalog parse failed"
rm -f /tmp/_cat.json
echo "== push-account variables (presence only) =="
for v in REGISTRY_PUSH_USERNAME REGISTRY_PUSH_PASSWORD EXTRA_BUNDLE; do if [ -n "$(printenv "$v")" ]; then echo "set: $v"; else echo "MISSING: $v"; fi; done
echo "== flow bundle contents (N-30, read to stdout only) =="
tar -xOf <flow-bundle> images.yaml 2>/dev/null | head -40
echo "-- charts.yaml --"
tar -xOf <flow-bundle> charts.yaml 2>/dev/null | head -20
echo "-- tags in the bundle (skill command) --"
tar -tf <flow-bundle> | grep '/_manifests/tags/[^/]*/$' | sed -n 's#^docker/registry/v2/repositories/\(.*\)/_manifests/tags/\([^/]*\)/$#\1:\2#p' | sort -u
