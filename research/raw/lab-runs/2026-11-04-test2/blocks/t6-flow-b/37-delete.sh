# CHANGES  (deletes workload cluster skilltest-flow-b: VMs in Prism Central; my cluster only)
source ~/nkp-skilltest-flow-b.env 2>/dev/null
tmux kill-session -t "nkp-$CLUSTER_NAME-del" 2>/dev/null
tmux new-session -d -s "nkp-$CLUSTER_NAME-del" -c "$HOME" "bash -c 'umask 077; while [ ! -f $HOME/nkp-$CLUSTER_NAME.env ]; do sleep 5; done' > /dev/null 2>&1"
tmux kill-session -t "nkp-$CLUSTER_NAME-del" 2>/dev/null
tmux new-session -d -s "nkp-$CLUSTER_NAME-del" -c "$HOME" "bash -c 'source ~/nkp-$CLUSTER_NAME.env 2>/dev/null; nkp delete cluster --cluster-name \"\$CLUSTER_NAME\" --namespace \"\$WORKSPACE_NS\" --kubeconfig \"\$MGMT_KUBECONFIG\" --timeout 30m > ~/nkp-$CLUSTER_NAME-delete.log 2>&1; echo RC=\$? >> ~/nkp-$CLUSTER_NAME-delete.log'"
date '+%H:%M:%S delete started in tmux nkp-'"$CLUSTER_NAME-del"
