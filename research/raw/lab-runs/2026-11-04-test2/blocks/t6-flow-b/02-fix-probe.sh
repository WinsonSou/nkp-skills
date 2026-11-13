# READ-ONLY  (fix block 01: clusterclass JSON shape, mirror repo check)
source ~/nkp-site.env 2>/dev/null
echo "== clusterclass spec keys =="
kubectl --kubeconfig "$MGMT_KUBECONFIG" --request-timeout=30s -n skilltest-flow-dw97w get clusterclass nkp-nutanix-v2.19.0 -o json 2>/dev/null | python3 -c '
import json,sys
d=json.load(sys.stdin)
print("top keys:", sorted(d.keys()))
print("spec keys:", sorted(d["spec"].keys()))
for k in d["spec"]:
    print("  ", k, type(d["spec"][k]).__name__)
if "variables" in d["spec"]:
    print("var names:", [v["name"] for v in d["spec"]["variables"]])
' 2>&1
echo "== cni addon schema via variables[].schema =="
kubectl --kubeconfig "$MGMT_KUBECONFIG" --request-timeout=30s -n skilltest-flow-dw97w get clusterclass nkp-nutanix-v2.19.0 -o json 2>/dev/null | python3 -c '
import json,sys
d=json.load(sys.stdin)
vs = d["spec"].get("variables") or d["spec"].get("patches") and []
for var in (d["spec"].get("variables") or []):
    if var.get("name")!="clusterConfig": continue
    p=var["schema"]["openAPIV3Schema"]["properties"]
    cni=p["addons"]["properties"]["cni"]
    print("cni.required:", cni.get("required"))
    print("cni.properties:", sorted(cni.get("properties",{})))
    print("provider.enum:", cni["properties"]["provider"].get("enum"))
    st=cni["properties"].get("strategy",{}); print("strategy:", st.get("enum"), "default", st.get("default"))
    ipc=cni["properties"].get("imagePullCredentials",{}); print("imagePullCredentials:", ipc.get("type"), "required", ipc.get("required"))
    v=cni["properties"].get("values",{})
    print("values.type:", v.get("type"))
    print("values.sourceRef:", json.dumps((v.get("properties") or {}).get("sourceRef"))[:400])
' 2>&1
echo "== mirror repos (host stripped of scheme) =="
proj="${REGISTRY_URL##*/}"; hostport="${REGISTRY_URL#*//}"; host="${hostport%%/*}"
echo "  proj=$proj host=$host"
for r in nutanix/flow-cni nutanix/flow-container-security nutanix/flow-ovn-kubernetes nutanix-flow-cni natsio/nats-box; do
  t=$(curl -sk -u "$REGISTRY_MIRROR_USERNAME:$REGISTRY_MIRROR_PASSWORD" "https://$host/service/token?service=harbor-registry&scope=repository:$proj/$r:pull" | python3 -c 'import json,sys;print(json.load(sys.stdin).get("token",""))' 2>/dev/null)
  code=$(curl -sk -o /tmp/tt -w '%{http_code}' -H "Authorization: Bearer $t" "https://$host/v2/$proj/$r/tags/list")
  echo "  $r -> $code $(head -c 100 /tmp/tt 2>/dev/null)"; done
echo "done"
