# CHANGES  (deletes the workload cluster skilltest-flow-a: its 7 VMs, nodes, disks, all data; cannot be undone)
source ~/nkp-site.env 2>/dev/null
source ~/nkp-skilltest-flow-a.env 2>/dev/null
: "${CLUSTER_NAME:?}" "${WORKSPACE_NS:?}" "${MGMT_KUBECONFIG:?}"
date '+start %F %T'
tmux new-session -d -s "nkp-$CLUSTER_NAME-delete" -c "$PWD" "bash -c 'source ~/nkp-site.env; source ~/nkp-$CLUSTER_NAME.env; nkp delete cluster --cluster-name \"\$CLUSTER_NAME\" --namespace \"\$WORKSPACE_NS\" --kubeconfig \"\$MGMT_KUBECONFIG\" --timeout 30m > ~/nkp-$CLUSTER_NAME-delete.log 2>&1; echo RC=\$? >> ~/nkp-$CLUSTER_NAME-delete.log'"
sleep 5
tmux ls 2>&1
tail -n 10 ~/nkp-$CLUSTER_NAME-delete.log 2>&1
