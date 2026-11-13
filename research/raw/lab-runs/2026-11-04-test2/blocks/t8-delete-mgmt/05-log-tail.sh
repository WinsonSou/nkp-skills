# READ-ONLY
source ~/nkp-nkp-mgmt-01.env 2>/dev/null
grep -v -i -E 'password|token|secret' "$HOME/nkp-$CLUSTER_NAME-delete.log" | tail -n 12
