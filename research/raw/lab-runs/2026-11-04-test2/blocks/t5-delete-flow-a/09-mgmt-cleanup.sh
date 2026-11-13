# CHANGES  (deletes the Flow CNI HelmChartProxy, the 2 mirror Secrets and the 2 per-cluster ConfigMaps of the deleted cluster on the management cluster)
source ~/nkp-site.env 2>/dev/null
source ~/nkp-skilltest-flow-a.env 2>/dev/null
KC="--request-timeout=30s --kubeconfig=$MGMT_KUBECONFIG -n $WORKSPACE_NS"
echo "--- before"
kubectl $KC get helmchartproxy "$CLUSTER_NAME-flow-cni" secret "$CLUSTER_NAME-oci-cert" "$CLUSTER_NAME-oci-creds" configmap "kube-oidc-proxy-$CLUSTER_NAME" "traefik-forward-auth-kommander-$CLUSTER_NAME" 2>&1 | head -8
echo "--- delete"
kubectl $KC delete helmchartproxy "$CLUSTER_NAME-flow-cni" --ignore-not-found 2>&1
kubectl $KC delete secret "$CLUSTER_NAME-oci-cert" "$CLUSTER_NAME-oci-creds" --ignore-not-found 2>&1
kubectl $KC delete configmap "kube-oidc-proxy-$CLUSTER_NAME" "traefik-forward-auth-kommander-$CLUSTER_NAME" --ignore-not-found 2>&1
sleep 10
echo "--- after: anything left with the name in the workspace namespace"
kubectl $KC get helmchartproxies,helmreleaseproxies,secrets,configmaps 2>&1 | grep -F -- "$CLUSTER_NAME"; true
kubectl $KC get helmchartproxies 2>&1
