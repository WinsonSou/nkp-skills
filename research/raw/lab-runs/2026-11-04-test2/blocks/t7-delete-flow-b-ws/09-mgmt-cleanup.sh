# CHANGES  (deletes the 4 objects that stayed in the workspace namespace of the deleted cluster)
source ~/nkp-skilltest-flow-b.env 2>/dev/null
: "${CLUSTER_NAME:?}" "${WORKSPACE_NS:?}" "${MGMT_KUBECONFIG:?}"
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" delete configmap "kube-oidc-proxy-$CLUSTER_NAME" "traefik-forward-auth-kommander-$CLUSTER_NAME" --request-timeout=30s
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" delete secret "$CLUSTER_NAME-oci-cert" "$CLUSTER_NAME-oci-creds" --ignore-not-found --request-timeout=30s
echo "== after =="
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get cm,secret --request-timeout=30s | grep -F -- "$CLUSTER_NAME" || echo "no object with the cluster name"
