# READ-ONLY
source ~/nkp-site.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" --request-timeout=30s get workspaces -A
echo "--- existing workspace namespaces"
kubectl --kubeconfig "$MGMT_KUBECONFIG" --request-timeout=30s get ns | grep -E 'workspace|kommander |skilltest' || true
echo "--- nkp create workspace help (flags that matter)"
nkp create workspace --help 2>&1 | grep -E 'display-name|dry-run|namespace|kubeconfig' 
