# READ-ONLY
source ~/nkp-site.env 2>/dev/null
source ~/nkp-skilltest-flow-a.env 2>/dev/null
date '+now %F %T'
tmux ls 2>&1
tail -n 15 ~/nkp-skilltest-flow-a-delete.log 2>&1 | grep -v -E 'password|token|secret'
