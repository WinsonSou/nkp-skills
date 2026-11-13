# READ-ONLY
source ~/nkp-nkp-mgmt-01.env 2>/dev/null
echo "CLUSTER_NAME=$CLUSTER_NAME WORKSPACE_NS=$WORKSPACE_NS"
echo "CP_VIP last octet: ${CP_VIP##*.}  (full IP masked), LB first/last: ${LB_IP_RANGE%-*}"
