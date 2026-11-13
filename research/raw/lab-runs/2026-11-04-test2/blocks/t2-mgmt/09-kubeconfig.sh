# CHANGES  (appends MGMT_KUBECONFIG to the site env file and CLUSTER_KUBECONFIG to the cluster env file)
source ~/nkp-nkp-mgmt-01.env 2>/dev/null
if test -f "$HOME/$CLUSTER_NAME.conf"; then echo "export MGMT_KUBECONFIG='$HOME/$CLUSTER_NAME.conf'" >> ~/nkp-site.env && echo "export CLUSTER_KUBECONFIG='$HOME/$CLUSTER_NAME.conf'" >> ~/nkp-nkp-mgmt-01.env && echo "kubeconfig paths appended"; else echo "no file: $HOME/$CLUSTER_NAME.conf"; fi
