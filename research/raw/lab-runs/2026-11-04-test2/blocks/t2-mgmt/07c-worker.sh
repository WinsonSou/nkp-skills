# READ-ONLY
source ~/nkp-nkp-mgmt-01.env 2>/dev/null
f=~/"$CLUSTER_NAME"-dryrun.yaml
grep -n -i -E 'worker|nodePool|machineDeployment' "$f" | grep -v -i -E 'password|token|secret' | head -30
echo "--- NKPCluster spec block (lines 92-120):"
sed -n '92,125p' "$f" | sed -E 's#([0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3})\.[0-9]{1,3}#<net>.N#g'
