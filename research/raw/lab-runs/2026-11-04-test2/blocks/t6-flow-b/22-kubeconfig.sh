# CHANGES  (writes the workload kubeconfig file ~/skilltest-flow-b.conf and appends CLUSTER_KUBECONFIG to the cluster env file)
source ~/nkp-skilltest-flow-b.env 2>/dev/null
cd "$HOME" || exit 1
umask 077 && nkp get kubeconfig --cluster-name "$CLUSTER_NAME" --namespace "$WORKSPACE_NS" --kubeconfig "$MGMT_KUBECONFIG" > "$HOME/$CLUSTER_NAME.conf" && echo "export CLUSTER_KUBECONFIG='$HOME/$CLUSTER_NAME.conf'" >> "$HOME/nkp-$CLUSTER_NAME.env"
echo "RC=$?"; ls -l "$HOME/$CLUSTER_NAME.conf" | awk '{print "mode="$1, "bytes="$5}'
source "$HOME/nkp-$CLUSTER_NAME.env"
test -f "$MGMT_KUBECONFIG" && echo "mgmt kubeconfig ok"
echo "== nodes =="; kubectl --kubeconfig "$CLUSTER_KUBECONFIG" --request-timeout=30s get nodes -o wide 2>&1 | head -9
echo "== flow namespaces on the cluster =="; kubectl --kubeconfig "$CLUSTER_KUBECONFIG" --request-timeout=30s get ns 2>&1 | grep -E 'flow|ovn|cni' || echo "  none"
echo "== pods in kube-system =="; kubectl --kubeconfig "$CLUSTER_KUBECONFIG" --request-timeout=30s get pods -n kube-system --no-headers 2>&1 | awk '{print "  "$1, $2, $3}' | head -20
echo "== helm releases / flux on the workload cluster =="; kubectl --kubeconfig "$CLUSTER_KUBECONFIG" --request-timeout=30s get helmreleases -A 2>&1 | head -5
