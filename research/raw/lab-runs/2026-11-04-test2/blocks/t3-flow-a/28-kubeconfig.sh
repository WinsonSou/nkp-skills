# CHANGES  (writes a local kubeconfig file and appends its path to the cluster env file)
source ~/nkp-skilltest-flow-a.env 2>/dev/null
umask 077 && nkp get kubeconfig --cluster-name "$CLUSTER_NAME" --namespace "$WORKSPACE_NS" --kubeconfig "$MGMT_KUBECONFIG" > "$PWD/$CLUSTER_NAME.conf" && echo "export CLUSTER_KUBECONFIG='$PWD/$CLUSTER_NAME.conf'" >> "$HOME/nkp-$CLUSTER_NAME.env"
chmod 600 "$PWD/$CLUSTER_NAME.conf"
ls -l "$PWD/$CLUSTER_NAME.conf"
