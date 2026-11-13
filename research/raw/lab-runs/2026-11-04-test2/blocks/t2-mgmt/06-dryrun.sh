# CHANGES  (writes the dry-run objects to a local file; creates no VMs)
source ~/nkp-nkp-mgmt-01.env 2>/dev/null
tmux new-session -d -s "dryrun-$CLUSTER_NAME" -c "$HOME" "bash -c 'umask 077; source ~/nkp-$CLUSTER_NAME.env 2>/dev/null; bash ~/nkp-$CLUSTER_NAME-create.sh --dry-run --output yaml > ~/$CLUSTER_NAME-dryrun.yaml 2> ~/$CLUSTER_NAME-dryrun.err; echo RC=\$? >> ~/$CLUSTER_NAME-dryrun.err'"
sleep 2
tmux ls
