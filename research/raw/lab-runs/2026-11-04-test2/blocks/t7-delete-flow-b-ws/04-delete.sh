# CHANGES  (deletes the workload cluster skilltest-flow-b: its VMs, nodes, and data; cannot be undone)
source ~/nkp-skilltest-flow-b.env 2>/dev/null
: "${CLUSTER_NAME:?}" "${WORKSPACE_NS:?}" "${MGMT_KUBECONFIG:?}"
date -u +%H:%M:%S
tmux kill-session -t "nkp-$CLUSTER_NAME-delete-t7" 2>/dev/null
tmux new-session -d -s "nkp-$CLUSTER_NAME-delete-t7" -c "$PWD" "bash -c 'umask 077; source ~/nkp-$CLUSTER_NAME.env 2>/dev/null; nkp delete cluster --cluster-name \"\$CLUSTER_NAME\" --namespace \"\$WORKSPACE_NS\" --kubeconfig \"\$MGMT_KUBECONFIG\" --timeout 30m > ~/nkp-$CLUSTER_NAME-delete-t7.log 2>&1; echo RC=\$? >> ~/nkp-$CLUSTER_NAME-delete-t7.log'"
sleep 3
tmux ls
