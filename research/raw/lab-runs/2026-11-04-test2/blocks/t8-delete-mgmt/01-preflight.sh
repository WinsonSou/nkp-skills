# READ-ONLY
source ~/nkp-site.env 2>/dev/null
echo "== nkp + tools =="
nkp version 2>/dev/null | head -3
echo "== env files in HOME =="
ls -l ~/nkp-site.env ~/nkp-nkp-mgmt-01.env 2>&1 | sed 's/ ubuntu ubuntu / /'
grep -n '^export MGMT_KUBECONFIG=' ~/nkp-site.env
grep -n '^export CLUSTER_KUBECONFIG=' ~/nkp-site.env
test -f "$MGMT_KUBECONFIG" && echo "MGMT_KUBECONFIG: file found" || echo "MGMT_KUBECONFIG: no file"
source ~/nkp-nkp-mgmt-01.env 2>/dev/null
echo "CLUSTER_NAME=$CLUSTER_NAME CP_VIP=$CP_VIP LB=$LB_IP_RANGE WS_NS=$WORKSPACE_NS"
echo "== D4 gate: nkpclusters must be the management cluster only =="
kubectl --kubeconfig "$MGMT_KUBECONFIG" --request-timeout=30s get nkpclusters -A 2>&1
echo "== workspaces =="
kubectl --kubeconfig "$MGMT_KUBECONFIG" --request-timeout=30s get workspaces 2>&1
echo "== nodes (count by role) =="
kubectl --kubeconfig "$MGMT_KUBECONFIG" --request-timeout=30s get nodes --no-headers 2>&1 | awk '{print $2}' | sort | uniq -c
echo "== PVCs =="
kubectl --kubeconfig "$MGMT_KUBECONFIG" --request-timeout=30s get pvc -A --no-headers 2>&1 | awk '{print $1, $2, $3, $4}'
echo "== PVs (CSI handles) =="
kubectl --kubeconfig "$MGMT_KUBECONFIG" --request-timeout=30s get pv -o custom-columns='NAME:.metadata.name,NS:.spec.claimRef.namespace,PVC:.spec.claimRef.name,SIZE:.spec.capacity.storage,HANDLE:.spec.csi.volumeHandle' 2>&1
echo "== LoadBalancer services =="
kubectl --kubeconfig "$MGMT_KUBECONFIG" --request-timeout=30s get svc -A --field-selector spec.type=LoadBalancer 2>&1
echo "== bootstrap cluster / containers =="
docker ps -a --format '{{.Names}} {{.Status}}' 2>&1
tmux ls 2>&1
echo "== operator host files with the cluster name =="
ls -l ~/ | grep -F -- "$CLUSTER_NAME" 2>&1
ls -a ~ | grep -F -- "$CLUSTER_NAME" 2>&1
echo "== bundle + flow cni bundle (must stay) =="
ls -l "$BUNDLE_DIR"/konvoy-bootstrap-image-*.tar 2>&1 | sed 's/ ubuntu ubuntu / /'
ls -l ~/flow-cni-*.tar 2>&1 | sed 's/ ubuntu ubuntu / /'
echo "== disk free =="
df -h / | tail -1
