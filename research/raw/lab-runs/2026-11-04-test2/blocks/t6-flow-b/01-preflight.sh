# READ-ONLY  (preflight: management cluster, workspace, CNI schema, mirror images, candidate IPs)
source ~/nkp-site.env 2>/dev/null
echo "== nkp version =="; nkp version 2>&1 | head -3
echo "== nkpclusters =="; kubectl --kubeconfig "$MGMT_KUBECONFIG" --request-timeout=30s get nkpclusters -A 2>&1
echo "== workspaces =="; kubectl --kubeconfig "$MGMT_KUBECONFIG" --request-timeout=30s get workspaces -A 2>&1
echo "== clusterclass in flow ns =="; kubectl --kubeconfig "$MGMT_KUBECONFIG" --request-timeout=30s -n skilltest-flow-dw97w get clusterclass -o custom-columns='NAME:.metadata.name' 2>&1
echo "== flow addon chart =="; kubectl --kubeconfig "$MGMT_KUBECONFIG" --request-timeout=30s -n caren-system get configmap default-helm-addons-config -o jsonpath='{.data.nutanix-flow-cni}' 2>&1; echo
echo "== flow values template present =="; kubectl --kubeconfig "$MGMT_KUBECONFIG" --request-timeout=30s -n caren-system get configmap default-nutanix-flow-cni-helm-values-template -o name 2>&1
echo "== cni addon schema =="
kubectl --kubeconfig "$MGMT_KUBECONFIG" --request-timeout=30s -n skilltest-flow-dw97w get clusterclass nkp-nutanix-v2.19.0 -o json 2>/dev/null | python3 -c '
import json,sys
d=json.load(sys.stdin)
for var in d["spec"]["variables"]:
    if var.get("name")!="clusterConfig": continue
    p=var["schema"]["openAPIV3Schema"]["properties"]
    cni=p["addons"]["properties"]["cni"]
    print("cni.required:", cni.get("required"))
    print("cni.properties:", sorted(cni.get("properties",{})))
    print("provider.enum:", cni["properties"]["provider"].get("enum"))
    st=cni["properties"].get("strategy",{}); print("strategy:", st.get("enum"), "default", st.get("default"))
    ipc=cni["properties"].get("imagePullCredentials",{}); print("imagePullCredentials:", ipc.get("type"), "required", ipc.get("required"))
    v=cni["properties"].get("values",{}); print("values.as:", v.get("type"), (v.get("properties") or {}).get("sourceRef"))
' 2>&1
echo "== image =="; echo "VM_IMAGE=$VM_IMAGE"
echo "== mgmt nodes ready count =="; kubectl --kubeconfig "$MGMT_KUBECONFIG" --request-timeout=30s get nodes --no-headers 2>&1 | awk '{print $2}' | sort | uniq -c
echo "== mirror: flow repos =="
proj="${REGISTRY_URL##*/}"; host="${REGISTRY_URL%%/*}"
for r in nutanix/flow-cni nutanix/flow-container-security nutanix/flow-ovn-kubernetes nutanix-flow-cni natsio/nats-box; do
  t=$(curl -sk -u "$REGISTRY_MIRROR_USERNAME:$REGISTRY_MIRROR_PASSWORD" "https://$host/service/token?service=harbor-registry&scope=repository:$proj/$r:pull" | python3 -c 'import json,sys;print(json.load(sys.stdin).get("token",""))' 2>/dev/null)
  code=$(curl -sk -o /tmp/tt -w '%{http_code}' -H "Authorization: Bearer $t" "https://$host/v2/$proj/$r/tags/list")
  echo "  $r -> $code $(head -c 100 /tmp/tt 2>/dev/null)"; done
echo "== candidate IPs (node /24 first three octets, .70 and .71-.75) =="
net3=$(kubectl --kubeconfig "$MGMT_KUBECONFIG" --request-timeout=30s get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}' | cut -d. -f1-3)
for n in 70 71 72 73 74 75; do
  ip="$net3.$n"
  ping -c1 -W1 "$ip" >/dev/null 2>&1 && r=ANSWER || r=no-answer
  sleep 1
  nb=$(ip neigh show "$ip" 2>/dev/null)
  case "$nb" in *lladdr*) a=ARP-PRESENT;; *) a=arp-free;; esac
  echo "  .$n $r $a"; done
echo "== leftovers of skilltest-flow-a =="
kubectl --kubeconfig "$MGMT_KUBECONFIG" --request-timeout=30s -n skilltest-flow-dw97w get cm,secret,helmchartproxy 2>&1 | grep -i 'flow-a' || echo "  none"
echo "done"
