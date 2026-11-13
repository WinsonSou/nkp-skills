# READ-ONLY  (webhook sideEffects gate)
source ~/nkp-skilltest-flow-b.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" --request-timeout=30s get validatingwebhookconfigurations,mutatingwebhookconfigurations -o json 2>/dev/null | python3 -c '
import json,sys
d=json.load(sys.stdin)
for it in d["items"]:
    kind=it["kind"]; name=it["metadata"]["name"]
    for w in it.get("webhooks",[]):
        res=w.get("rules") or []
        hit=any(("nkpclusters" in (r.get("resources") or [])) or ("secrets" in (r.get("resources") or [])) or ("*" in (r.get("resources") or [])) for r in res)
        if hit:
            print("  %s %s/%s sideEffects=%s failurePolicy=%s" % (kind[:3], name, w.get("name"), w.get("sideEffects"), w.get("failurePolicy")))
'
