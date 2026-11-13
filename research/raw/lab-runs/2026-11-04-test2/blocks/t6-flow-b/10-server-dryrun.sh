# READ-ONLY  (webhook sideEffects gate + server dry run of the NKPCluster alone; changes nothing)
source ~/nkp-skilltest-flow-b.env 2>/dev/null
echo "== mutating webhooks that match nkpclusters/secrets, and their sideEffects =="
kubectl --kubeconfig "$MGMT_KUBECONFIG" --request-timeout=30s get validatingwebhookconfigurations,mutatingwebhookconfigurations -o json 2>/dev/null | python3 -c '
import json,sys
d=json.load(sys.stdin)
for it in d["items"]:
    kind=it["kind"]; name=it["metadata"]["name"]
    for w in it.get("webhooks",[]):
        res=w.get("rules") or []
        hit=any(("nkpclusters" in (r.get("resources") or [])) or ("secrets" in (r.get("resources") or [])) or ("*" in (r.get("resources") or [])) for r in res)
        if hit: print(f"  {kind[:3]} {name}/{w[\"name\"]} sideEffects={w.get(\"sideEffects\")} failurePolicy={w.get(\"failurePolicy\")}")
'
echo "== server dry run: NKPCluster only =="
f="$HOME/$CLUSTER_NAME-dryrun.yaml"
yq 'select(.kind == "NKPCluster")' "$f" | kubectl --kubeconfig "$MGMT_KUBECONFIG" --request-timeout=30s apply --server-side --dry-run=server -f - -o yaml 2>&1 \
 | sed -E 's/Invalid value: "[^"]*"/Invalid value: "[masked]"/' | yq 'select(.kind == "NKPCluster") | (.spec.capiCluster.topology.variables[] | select(.name == "clusterConfig") | "addons: " + (.value.addons | keys | join(",")) + "  cni: " + (.value.addons.cni.provider // "-") + "/" + (.value.addons.cni.strategy // "-"))' 2>&1 | head -20
echo "== raw error, if any =="
yq 'select(.kind == "NKPCluster")' "$f" | kubectl --kubeconfig "$MGMT_KUBECONFIG" --request-timeout=30s apply --server-side --dry-run=server -f - -o name 2>&1 \
 | sed -E 's/Invalid value: "[^"]*"/Invalid value: "[masked]"/' | head -10
