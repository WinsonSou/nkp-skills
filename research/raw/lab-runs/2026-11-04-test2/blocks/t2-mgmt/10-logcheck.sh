# READ-ONLY
source ~/nkp-nkp-mgmt-01.env 2>/dev/null
tail -n 6 ~/"nkp-$CLUSTER_NAME-create.log" 2>/dev/null | grep -v -i -E 'password|token|secret' | sed -E 's/Invalid value: "[^"]*"/Invalid value: "[masked]"/'
tmux ls 2>/dev/null || echo "no tmux session"
