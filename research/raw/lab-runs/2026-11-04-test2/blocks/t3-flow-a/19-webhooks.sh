# READ-ONLY  (mutating webhooks that match the objects of the apply, and their sideEffects)
source ~/nkp-skilltest-flow-a.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" --request-timeout=30s get mutatingwebhookconfigurations -o json | python3 -c "
import json,sys
d=json.load(sys.stdin)
want={('clusters','cluster.x-k8s.io'),('nkpclusters','clusters.nkp.nutanix.com'),('helmchartproxies','addons.cluster.x-k8s.io'),('secrets','')}
for w in d.get('items',[]):
    for wh in w.get('webhooks',[]):
        rules=wh.get('rules') or []
        hit=[(r.get('apiGroups'),r.get('resources')) for r in rules if any(res in ('clusters','*','nkpclusters','helmchartproxies','secrets') for res in (r.get('resources') or []))]
        if hit:
            print(w['metadata']['name'], '| sideEffects=', wh.get('sideEffects'), '| failurePolicy=', wh.get('failurePolicy'), '| resources=', sorted({x for _,y in hit for x in y})[:8])
"
