# READ-ONLY  (server dry run of the path-B NKPCluster after the defaulting webhooks; changes nothing)
source ~/nkp-skilltest-flow-b.env 2>/dev/null
f="$HOME/$CLUSTER_NAME-dryrun.yaml"
tmp=/tmp/t6-flow-b-nkpcluster.yaml
yq 'select(.kind == "NKPCluster")' "$f" > "$tmp"
echo "== -o name =="
kubectl --kubeconfig "$MGMT_KUBECONFIG" --request-timeout=30s apply --server-side --dry-run=server -f "$tmp" -o name 2>&1 | sed -E 's/Invalid value: "[^"]*"/Invalid value: "[masked]"/'
echo "== after the webhooks: addons, cni, kubeProxy =="
kubectl --kubeconfig "$MGMT_KUBECONFIG" --request-timeout=30s apply --server-side --dry-run=server -f "$tmp" -o yaml 2>/dev/null \
 | yq 'select(.kind == "NKPCluster") | (.spec.capiCluster.topology.variables[] | select(.name == "clusterConfig") | .value | "addons: " + (.addons | keys | join(",")) + "  cni: " + (.addons.cni.provider // "-") + "/" + (.addons.cni.strategy // "-") + "  kubeProxy: " + (.kubeProxy.mode // "none"))'
echo "== does anything Cilium-specific appear? =="
kubectl --kubeconfig "$MGMT_KUBECONFIG" --request-timeout=30s apply --server-side --dry-run=server -f "$tmp" -o yaml 2>/dev/null | grep -c -i cilium | sed 's/^/  cilium mentions: /'
rm -f "$tmp"
