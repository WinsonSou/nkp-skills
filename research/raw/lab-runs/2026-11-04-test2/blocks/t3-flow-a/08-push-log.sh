# READ-ONLY
source ~/nkp-site.env 2>/dev/null
tmux ls 2>/dev/null | grep push-flow-cni || echo "tmux session gone"
tail -n 12 ~/push-flow-cni.log 2>/dev/null | grep -v -i -E 'password|token|secret'
grep -c . ~/push-flow-cni.log 2>/dev/null
