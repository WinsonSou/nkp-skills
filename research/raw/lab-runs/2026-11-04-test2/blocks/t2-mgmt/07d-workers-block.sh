# READ-ONLY
source ~/nkp-nkp-mgmt-01.env 2>/dev/null
sed -n '215,232p' ~/"$CLUSTER_NAME"-dryrun.yaml | sed -E 's#([0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3})\.[0-9]{1,3}#<net>.N#g'
