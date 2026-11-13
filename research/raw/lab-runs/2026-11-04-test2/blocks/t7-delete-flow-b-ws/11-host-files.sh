# CHANGES  (deletes the local files of the deleted cluster; the env file goes last)
source ~/nkp-skilltest-flow-b.env 2>/dev/null
: "${CLUSTER_NAME:?}"
rm -fv -- "$HOME/nkp-$CLUSTER_NAME-create.sh" "$HOME/nkp-$CLUSTER_NAME-delete.log" "$HOME/nkp-$CLUSTER_NAME-delete-t7.log" "$HOME/nkp-$CLUSTER_NAME-nswatch.sh" "$HOME/nkp-$CLUSTER_NAME-nswatch.log" "$PWD/$CLUSTER_NAME-dryrun.yaml" "$PWD/$CLUSTER_NAME-dryrun.yaml.orig" ${CLUSTER_KUBECONFIG:+"$CLUSTER_KUBECONFIG"}; rm -fv -- "$HOME/nkp-$CLUSTER_NAME.env"
echo "== after =="
ls -a "$HOME" "$PWD" | grep -F -- "$CLUSTER_NAME" || echo "no file with the cluster name"
echo "== kept =="
ls -l "$HOME/nkp-site.env" "$HOME/nkp-nkp-mgmt-01.env" "$HOME/nkp-mgmt-01.conf"
