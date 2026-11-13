# READ-ONLY  (clusterclass status.variables cni schema)
source ~/nkp-site.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" --request-timeout=30s -n skilltest-flow-dw97w get clusterclass nkp-nutanix-v2.19.0 -o json 2>/dev/null | python3 -c '
import json,sys
d=json.load(sys.stdin)
vd=d["status"]["variables"]
print("vars:", [v.get("name") for v in vd])
for var in vd:
    if var.get("name")!="clusterConfig": continue
    p=var["schema"]["openAPIV3Schema"]["properties"]
    cni=p["addons"]["properties"]["cni"]
    print("cni.required:", cni.get("required"))
    print("cni.properties:", sorted(cni.get("properties",{})))
    print("provider:", json.dumps(cni["properties"]["provider"])[:300])
    s=cni["properties"].get("strategy",{}); print("strategy:", s.get("enum"), "default", s.get("default"))
    ipc=cni["properties"].get("imagePullCredentials",{}); print("imagePullCredentials:", ipc.get("type"), "required", ipc.get("required"), json.dumps(ipc)[:400])
    v=cni["properties"].get("values",{}); print("values:", json.dumps(v)[:500])
' 2>&1
echo "done"
