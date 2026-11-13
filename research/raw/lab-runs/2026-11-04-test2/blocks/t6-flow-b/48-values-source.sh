# CHANGES  (creates the Flow values ConfigMap in skilltest-flow-dw97w and points addons.cni.values.sourceRef at it; no cluster yet)
source ~/nkp-skilltest-flow-b.env 2>/dev/null
f="$HOME/$CLUSTER_NAME-dryrun.yaml"; test -s "$f" || { echo "no dry-run file"; exit 1; }
cm="$CLUSTER_NAME-flow-values"
(umask 077 && cat > /tmp/$cm.values.yaml <<EOF
nutanix-core-flow-ovn-kubernetes:
  k8sAPIServer: "https://$CP_VIP:6443"
  podNetwork: "192.168.0.0/16/24"
  serviceNetwork: "10.96.0.0/12"
EOF
)
kubectl --kubeconfig "$MGMT_KUBECONFIG" --request-timeout=30s -n "$WORKSPACE_NS" create configmap "$cm" --from-file=values.yaml=/tmp/$cm.values.yaml --dry-run=client -o yaml \
 | kubectl --kubeconfig "$MGMT_KUBECONFIG" --request-timeout=30s apply -f - -o name
echo "RC=$?"; rm -f /tmp/$cm.values.yaml
yq -i '(select(.kind == "NKPCluster") | .spec.capiCluster.topology.variables[] | select(.name == "clusterConfig") | .value.addons.cni.values) = {"sourceRef": {"kind": "ConfigMap", "name": "'$cm'"}}' "$f"
echo "yq RC=$?"
echo "== cni block =="
yq 'select(.kind == "NKPCluster") | (.spec.capiCluster.topology.variables[] | select(.name == "clusterConfig") | .value.addons.cni)' "$f"
echo "== doc count and kinds =="
python3 - "$f" <<'PY'
import sys,re
t=open(sys.argv[1]).read()
docs=[d for d in re.split(r'(?m)^---\s*$', t) if d.strip()]
print("docs:", len(docs), [re.search(r'(?m)^kind:\s*(\S+)',d).group(1) for d in docs])
PY
echo "== configmap on the management cluster (key names only) =="
kubectl --kubeconfig "$MGMT_KUBECONFIG" --request-timeout=30s -n "$WORKSPACE_NS" get configmap "$cm" -o jsonpath='{.data.values\.yaml}{"\n"}' 2>&1
