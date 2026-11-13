# READ-ONLY
source ~/nkp-skilltest-flow-b.env 2>/dev/null
cat ~/nkp-skilltest-flow-b-delete-t7.log | grep -v -E 'password|token|secret'
