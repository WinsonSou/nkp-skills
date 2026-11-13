# CHANGES  (deletes the local files of the deleted management cluster; the env file goes last)
source ~/nkp-nkp-mgmt-01.env 2>/dev/null
: "${CLUSTER_NAME:?}"
rm -f -- "$HOME/nkp-$CLUSTER_NAME-create.sh" "$HOME/nkp-$CLUSTER_NAME-patch.json" "$HOME/nkp-$CLUSTER_NAME-nodepool.sh" "$HOME/nkp-$CLUSTER_NAME-nodepool-dryrun.yaml" "$HOME/nkp-$CLUSTER_NAME-inventory.yaml" "$PWD/$CLUSTER_NAME-dryrun.yaml" "$PWD/$CLUSTER_NAME-dryrun.err" "$PWD/$CLUSTER_NAME-metallb-conf.yaml" "$PWD/$CLUSTER_NAME-bootstrap.conf" "$HOME/nkp-$CLUSTER_NAME-create.log" "$HOME/nkp-$CLUSTER_NAME-delete.log" ${CLUSTER_KUBECONFIG:+"$CLUSTER_KUBECONFIG"}; rm -f -- "$HOME/nkp-$CLUSTER_NAME.env"
echo "== after: no file with the cluster name =="
ls -a "$HOME" "$PWD" | grep -F -- "$CLUSTER_NAME" || echo "(no line)"
echo "== kept =="
ls -l ~/nkp-site.env ~/flow-cni-1.1.0.tar | sed 's/ ubuntu ubuntu / /'
grep -c . ~/nkp-site.env
