# READ-ONLY
source ~/nkp-site.env 2>/dev/null
echo "== nkp / yq =="
nkp version 2>/dev/null | head -3
command -v yq >/dev/null && yq --version || echo "MISSING: yq"
echo "== workspaces (N5 step 1) =="
kubectl --kubeconfig "$MGMT_KUBECONFIG" --request-timeout=30s get workspaces -A
echo "== mgmt mirror URL (N5 step 1) =="
kubectl --kubeconfig "$MGMT_KUBECONFIG" --request-timeout=30s -n kommander get nkpclusters -o jsonpath='{.items[*].spec.kommanderCluster.spec.ociRegistry.mirrorURL}{"\n"}'
echo "== node image (site file) =="
echo "VM_IMAGE=$VM_IMAGE"
echo "== clusterclass in workspace ns (step 1) =="
ns=$(kubectl --kubeconfig "$MGMT_KUBECONFIG" --request-timeout=30s get workspaces -A -o jsonpath='{range .items[?(@.metadata.name=="skilltest-flow")]}{.status.namespace}{"\n"}{end}')
echo "skilltest-flow namespace: ${ns:-<none>}"
kubectl --kubeconfig "$MGMT_KUBECONFIG" --request-timeout=30s -n "${ns:-kommander}" get clusterclass -o custom-columns='NAME:.metadata.name'
echo "== caren flow addon config (step 1) =="
kubectl --kubeconfig "$MGMT_KUBECONFIG" --request-timeout=30s -n caren-system get configmap default-helm-addons-config -o jsonpath='{.data.nutanix-flow-cni}{"\n"}'
echo "== caren chart server tag list (step 1) =="
kubectl --kubeconfig "$MGMT_KUBECONFIG" --request-timeout=30s get --raw "/api/v1/namespaces/caren-system/services/https:helm-repository:443/proxy/v2/charts/nutanix-flow-cni/tags/list"; echo
echo "== mgmt cluster state =="
kubectl --kubeconfig "$MGMT_KUBECONFIG" --request-timeout=30s -n kommander get nkpclusters
kubectl --kubeconfig "$MGMT_KUBECONFIG" --request-timeout=30s get licenses.kommander.mesosphere.io -o jsonpath='{.items[*].status.dkpLevel}{"\n"}'
echo "== flow bundle on the operator host =="
ls -l <flow-bundle> 2>/dev/null || echo "MISSING: <flow-bundle>"
