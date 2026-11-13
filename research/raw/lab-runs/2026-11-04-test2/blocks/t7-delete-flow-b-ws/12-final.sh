# READ-ONLY
source ~/nkp-site.env 2>/dev/null
KC="--request-timeout=30s"
date '+now %F %T'
echo "--- the management cluster must stay"
kubectl --kubeconfig "$MGMT_KUBECONFIG" $KC get nkpclusters -A
kubectl --kubeconfig "$MGMT_KUBECONFIG" $KC get nodes 2>&1 | grep -c ' Ready '
kubectl --kubeconfig "$MGMT_KUBECONFIG" $KC get workspaces
kubectl --kubeconfig "$MGMT_KUBECONFIG" $KC get ns skilltest-flow-dw97w
echo "--- the workspace namespace: only its own objects"
kubectl --kubeconfig "$MGMT_KUBECONFIG" $KC -n skilltest-flow-dw97w get all,helmchartproxies,helmreleaseproxies,nkpclusters
echo "--- any remaining trace of the cluster name on the management cluster"
kubectl --kubeconfig "$MGMT_KUBECONFIG" $KC get all,nkpclusters,clusters.cluster.x-k8s.io,machines,secrets,configmaps,helmchartproxies -A 2>/dev/null | grep -F -- 'skilltest-flow-b'
echo "(no line above = clean)"
echo "--- mirror: the Flow CNI repositories stay (read-only token + tags/list)"
host="${REGISTRY_URL#https://}"; proj="${REGISTRY_URL##*/}"; host="${host%%/*}"
tok=$(curl -sk -u "$REGISTRY_MIRROR_USERNAME:$REGISTRY_MIRROR_PASSWORD" \
  "https://$host/service/token?service=harbor-registry&scope=repository:$proj/nutanix/flow-cni:pull" | sed -n 's/.*"token":"\([^"]*\)".*/\1/p')
for r in nutanix/flow-cni nutanix/flow-container-security nutanix/flow-ovn-kubernetes nutanix-flow-cni; do
  echo "repo $proj/$r -> $(curl -sk -o /dev/null -w '%{http_code}' -H "Authorization: Bearer $tok" "https://$host/v2/$proj/$r/tags/list")"
done
