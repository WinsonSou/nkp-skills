# READ-ONLY  (clusterclass cni schema from status.variableDiscovery)
source ~/nkp-site.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" --request-timeout=30s -n skilltest-flow-dw97w get clusterclass nkp-nutanix-v2.19.0 -o json 2>/dev/null | python3 -c '
import json,sys
d=json.load(sys.stdin)
st=d.get("status",{})
print("status keys:", sorted(st.keys()))
vd=st.get("variableDiscovery") or []
print("discovered vars:", len(vd))
for var in vd:
    if var.get("name")!="clusterConfig": continue
    p=var["schema"]["openAPIV3Schema"]["properties"]
    cni=p["addons"]["properties"]["cni"]
    print("cni.required:", cni.get("required"))
    print("cni.properties:", sorted(cni.get("properties",{})))
    print("provider:", json.dumps(cni["properties"]["provider"])[:300])
    st2=cni["properties"].get("strategy",{}); print("strategy:", st2.get("enum"), "default", st2.get("default"))
    ipc=cni["properties"].get("imagePullCredentials",{}); print("imagePullCredentials:", ipc.get("type"), "required", ipc.get("required"), json.dumps(ipc)[:400])
    v=cni["properties"].get("values",{}); print("values:", json.dumps(v)[:500])
' 2>&1
echo "done"
