# READ-ONLY
source ~/nkp-skilltest-flow-a.env 2>/dev/null
echo "== ovn-config (F-05 MTU) =="
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" --request-timeout=30s -n ovn-kubernetes get cm ovn-config -o json | python3 -c "
import json,sys
d=json.load(sys.stdin)
for k,v in (d.get('data') or {}).items():
    print(k,'=',(v[:120].replace(chr(10),' ')))
"
echo "== ovnkube-node pod args (gateway mode / interfaces) =="
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" --request-timeout=30s -n ovn-kubernetes get ds ovnkube-node -o jsonpath='{.spec.template.spec.containers[*].args}' 2>/dev/null | tr ',' '\n' | grep -i -E 'mtu|gateway|iface|interconnect|encap' | head -12
echo "== ovs-node host mounts =="
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" --request-timeout=30s -n ovn-kubernetes get ds ovs-node -o jsonpath='{range .spec.template.spec.volumes[*]}{.name}{" hostPath="}{.hostPath.path}{"\n"}{end}' 2>/dev/null | head -10
