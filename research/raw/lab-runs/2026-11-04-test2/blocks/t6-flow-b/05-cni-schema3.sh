# READ-ONLY  (clusterclass status.variables shape)
source ~/nkp-site.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" --request-timeout=30s -n skilltest-flow-dw97w get clusterclass nkp-nutanix-v2.19.0 -o json 2>/dev/null | python3 -c '
import json,sys
d=json.load(sys.stdin)
for var in d["status"]["variables"]:
    if var.get("name")!="clusterConfig": continue
    print("var keys:", sorted(var.keys()))
    defs=var.get("definitions") or []
    print("definitions:", len(defs))
    for df in defs:
        print("  def keys:", sorted(df.keys()))
        sch=df.get("schema") or {}
        p=(sch.get("openAPIV3Schema") or {}).get("properties")
        if not p: 
            print("  no properties"); continue
        cni=p.get("addons",{}).get("properties",{}).get("cni")
        if not cni: 
            print("  no cni"); continue
        print("cni.required:", cni.get("required"))
        print("cni.properties:", sorted(cni.get("properties",{})))
        print("provider:", json.dumps(cni["properties"]["provider"])[:300])
        s=cni["properties"].get("strategy",{}); print("strategy:", s.get("enum"), "default", s.get("default"))
        ipc=cni["properties"].get("imagePullCredentials",{}); print("imagePullCredentials:", ipc.get("type"), "required", ipc.get("required"), json.dumps(ipc)[:400])
        v=cni["properties"].get("values",{}); print("values:", json.dumps(v)[:500])
' 2>&1
echo "done"
