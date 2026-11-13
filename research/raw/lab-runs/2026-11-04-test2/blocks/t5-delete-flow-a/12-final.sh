# READ-ONLY
source ~/nkp-site.env 2>/dev/null
KC="--request-timeout=30s"
date '+now %F %T'
echo "--- clusters that must stay"
kubectl --kubeconfig "$MGMT_KUBECONFIG" $KC get nkpclusters -A 2>&1
kubectl --kubeconfig "$MGMT_KUBECONFIG" $KC get nodes 2>&1 | grep -c ' Ready '
kubectl --kubeconfig "$MGMT_KUBECONFIG" $KC get workspaces 2>&1
echo "--- the workspace namespace: no object of the deleted cluster"
kubectl --kubeconfig "$MGMT_KUBECONFIG" $KC -n skilltest-flow-dw97w get all,helmchartproxies,helmreleaseproxies,secrets,configmaps 2>&1 | tail -20
echo "--- any remaining trace of the name on the management cluster"
kubectl --kubeconfig "$MGMT_KUBECONFIG" $KC get all,nkpclusters,clusters.cluster.x-k8s.io,machines,secrets,configmaps,helmchartproxies -A 2>/dev/null | grep -F -- 'skilltest-flow-a'
echo "(no line above = clean)"
echo "--- site file and mgmt env file untouched"
ls -l ~/nkp-site.env ~/nkp-nkp-mgmt-01.env
grep -c . ~/nkp-site.env
echo "--- mirror: the Flow CNI repositories stay (read-only token + tags/list)"
host="${REGISTRY_URL#https://}"; proj="${REGISTRY_URL##*/}"; host="${host%%/*}"
tok=$(curl -sk -u "$REGISTRY_MIRROR_USERNAME:$REGISTRY_MIRROR_PASSWORD" \
  "https://$host/service/token?service=harbor-registry&scope=repository:$proj/nutanix/flow-cni:pull" | sed -n 's/.*"token":"\([^"]*\)".*/\1/p')
for r in nutanix/flow-cni nutanix/flow-container-security nutanix/flow-ovn-kubernetes nutanix-flow-cni; do
  code=$(curl -sk -o /dev/null -w '%{http_code}' -H "Authorization: Bearer $tok" "https://$host/v2/$proj/$r/tags/list")
  echo "repo $proj/$r -> $code"
done
