# CHANGES  (deletes the management cluster: its VMs, nodes, and data; makes a kind bootstrap cluster on this host; cannot be undone)
source ~/nkp-<cluster>.env 2>/dev/null
: "${CLUSTER_NAME:?}"
tmux new-session -d -s "nkp-$CLUSTER_NAME-delete" -c "$PWD" "bash -c 'umask 077; source ~/nkp-$CLUSTER_NAME.env 2>/dev/null; nkp delete cluster --self-managed --cluster-name \"\$CLUSTER_NAME\" --namespace \"\$WORKSPACE_NS\" --kubeconfig \"\$MGMT_KUBECONFIG\" --timeout 60m \${BUNDLE_DIR:+--bootstrap-cluster-image \"\$(ls \"\$BUNDLE_DIR\"/konvoy-bootstrap-image-*.tar)\"} > ~/nkp-$CLUSTER_NAME-delete.log 2>&1; echo RC=\$? >> ~/nkp-$CLUSTER_NAME-delete.log'"
echo "start: $(date -u +%H:%M:%S) UTC"
tmux ls
