# READ-ONLY  (CAREN Flow addon: HCP/HRP shape and readiness; cluster kubeconfig variables)
source ~/nkp-skilltest-flow-b.env 2>/dev/null
echo "== all HCPs of this cluster =="
kubectl --kubeconfig "$MGMT_KUBECONFIG" --request-timeout=30s -n "$WORKSPACE_NS" get helmchartproxies -o custom-columns='NAME:.metadata.name,CHART:.spec.chartName,VER:.spec.version,RELEASE_NS:.spec.namespace,READY:.status.conditions[?(@.type=="Ready")].status' 2>&1 | grep -v -E 'cosi|konnector|metallb|multus|node-feature|snapshot' 
echo "== flow HCP: spec, without values =="
hcp=$(kubectl --kubeconfig "$MGMT_KUBECONFIG" --request-timeout=30s -n "$WORKSPACE_NS" get helmchartproxies --no-headers 2>/dev/null | awk '/flow-cni/{print $1}')
echo "  name=$hcp"
kubectl --kubeconfig "$MGMT_KUBECONFIG" --request-timeout=30s -n "$WORKSPACE_NS" get helmchartproxy "$hcp" -o jsonpath='{.spec.repoURL}{"\n"}{.spec.chartName}{"\n"}{.spec.version}{"\n"}{.spec.namespace}{"\n"}{.spec.clusterSelector.matchLabels}{"\n"}{.spec.options}{"\n"}' 2>&1
echo "  -- values (this is the CAREN Flow template rendered; dark site so no token) --"
kubectl --kubeconfig "$MGMT_KUBECONFIG" --request-timeout=30s -n "$WORKSPACE_NS" get helmchartproxy "$hcp" -o jsonpath='{.spec.valuesTemplate}' 2>&1 | sed 's/^/    /'
echo ""
echo "== flow HCP conditions =="
kubectl --kubeconfig "$MGMT_KUBECONFIG" --request-timeout=30s -n "$WORKSPACE_NS" get helmchartproxy "$hcp" -o jsonpath='{range .status.conditions[*]}{.type}={.status} {.reason} {.message}{"\n"}{end}' 2>&1 | head -6
echo "== HRPs of this cluster =="
kubectl --kubeconfig "$MGMT_KUBECONFIG" --request-timeout=30s -n "$WORKSPACE_NS" get helmreleaseproxies -o custom-columns='NAME:.metadata.name,CHART:.spec.chartName,NS:.spec.namespace,READY:.status.conditions[?(@.type=="Ready")].status' 2>&1 | tail -12
echo "== ownerReferences of the flow HCP =="
kubectl --kubeconfig "$MGMT_KUBECONFIG" --request-timeout=30s -n "$WORKSPACE_NS" get helmchartproxy "$hcp" -o jsonpath='{.metadata.ownerReferences[*].kind}/{.metadata.ownerReferences[*].name}{"\n"}{.metadata.labels}{"\n"}' 2>&1
echo "== pull secret on the workload side? (imagePullCredentials) =="
kubectl --kubeconfig "$MGMT_KUBECONFIG" --request-timeout=30s -n "$WORKSPACE_NS" get nkpcluster "$CLUSTER_NAME" -o jsonpath='{range .spec.capiCluster.topology.variables[*]}{select(.name=="clusterConfig")}{.value.addons.cni}{"\n"}{end}' 2>&1
