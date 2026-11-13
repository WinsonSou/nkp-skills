# CHANGES  (creates the cluster in a tmux session named after the cluster: VMs in Prism Central; kind, pivot, Kommander)
source ~/nkp-nkp-mgmt-01.env 2>/dev/null
tmux new-session -d -s "nkp-$CLUSTER_NAME" -c "$PWD" "bash -c 'umask 077; source ~/nkp-$CLUSTER_NAME.env 2>/dev/null; bash ~/nkp-$CLUSTER_NAME-create.sh > ~/nkp-$CLUSTER_NAME-create.log 2>&1; echo RC=\$? >> ~/nkp-$CLUSTER_NAME-create.log'"
sleep 2; tmux ls
