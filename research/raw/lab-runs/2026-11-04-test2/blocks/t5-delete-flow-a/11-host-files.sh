# CHANGES  (deletes the local files of the deleted cluster on the operator host)
source ~/nkp-site.env 2>/dev/null
source ~/nkp-skilltest-flow-a.env 2>/dev/null
: "${CLUSTER_NAME:?}"
find "$HOME" -maxdepth 1 -name "*$CLUSTER_NAME*" -printf '%f %s bytes\n' 2>/dev/null | sort
rm -f -- "$HOME/nkp-$CLUSTER_NAME-create.sh" "$HOME/$CLUSTER_NAME-dryrun.yaml" "$HOME/$CLUSTER_NAME-dryrun.yaml.orig" "$HOME/$CLUSTER_NAME-flow-cni-hcp.yaml" "$HOME/$CLUSTER_NAME-smoke.yaml" "$HOME/nkp-$CLUSTER_NAME-delete.log" ${CLUSTER_KUBECONFIG:+"$CLUSTER_KUBECONFIG"}; rm -f -- "$HOME/nkp-$CLUSTER_NAME.env"
echo "--- after"
find "$HOME" -maxdepth 1 -name "*$CLUSTER_NAME*" -printf '%f\n' 2>/dev/null | sort
echo "(empty above = no file is left)"
ls -l "$HOME/nkp-nkp-mgmt-01.env" "$HOME/nkp-mgmt-01.conf" ~/nkp-site.env 2>&1
