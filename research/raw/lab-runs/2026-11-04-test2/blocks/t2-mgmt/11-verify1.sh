# READ-ONLY
source ~/nkp-nkp-mgmt-01.env 2>/dev/null
test -f "$MGMT_KUBECONFIG" && echo "mgmt kubeconfig ok"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" --request-timeout=30s get nodes -o wide
echo "--- kommander helmreleases (count)"
kubectl --kubeconfig "$MGMT_KUBECONFIG" --request-timeout=30s -n kommander get helmreleases --no-headers | wc -l
echo "--- not-ready helmreleases (whole cluster)"
kubectl --kubeconfig "$MGMT_KUBECONFIG" --request-timeout=30s get helmreleases -A | awk 'NR==1 || $4!="True"'
echo "--- nkpcluster"
kubectl --kubeconfig "$MGMT_KUBECONFIG" --request-timeout=30s -n kommander get nkpclusters
