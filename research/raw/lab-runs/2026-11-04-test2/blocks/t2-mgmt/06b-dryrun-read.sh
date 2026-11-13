# READ-ONLY
source ~/nkp-nkp-mgmt-01.env 2>/dev/null
echo "--- err tail (masked)"
tail -n 8 ~/"$CLUSTER_NAME"-dryrun.err 2>/dev/null | grep -v -i -E 'password|token|secret' | sed -E 's/Invalid value: "[^"]*"/Invalid value: "[masked]"/'
echo "--- yaml size / secrets count"
ls -l ~/"$CLUSTER_NAME"-dryrun.yaml 2>/dev/null | awk '{print $5, $NF}'
grep -c '^kind: Secret' ~/"$CLUSTER_NAME"-dryrun.yaml 2>/dev/null
echo "--- tmux"
tmux ls 2>/dev/null || echo "no tmux session"
