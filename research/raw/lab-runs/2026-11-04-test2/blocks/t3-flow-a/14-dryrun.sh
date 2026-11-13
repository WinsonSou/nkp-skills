# CHANGES  (writes the dry-run objects to a local file; creates no VMs)
source ~/nkp-skilltest-flow-a.env 2>/dev/null
umask 077 && bash "$HOME/nkp-$CLUSTER_NAME-create.sh" --dry-run --output yaml > "$PWD/$CLUSTER_NAME-dryrun.yaml"
echo "RC=$?  bytes=$(wc -c < "$PWD/$CLUSTER_NAME-dryrun.yaml")"
