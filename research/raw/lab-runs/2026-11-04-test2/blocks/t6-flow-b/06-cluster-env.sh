# CHANGES  (writes the cluster env file ~/nkp-skilltest-flow-b.env on the operator host; creates no cluster object)
source ~/nkp-site.env 2>/dev/null
source ~/nkp-nkp-mgmt-01.env 2>/dev/null
: "${MGMT_KUBECONFIG:?}" "${CP_VIP:?}"
net="${CP_VIP%.*}"
ns=$(kubectl --kubeconfig "$MGMT_KUBECONFIG" --request-timeout=30s get workspaces -A --no-headers 2>/dev/null | awk '$1=="skilltest-flow"{print $4}')
: "${ns:?workspace namespace not found}"
f="$HOME/nkp-skilltest-flow-b.env"
(umask 077 && cat > "$f" <<EOF
source ~/nkp-site.env 2>/dev/null
export CLUSTER_NAME='skilltest-flow-b'
export CP_VIP='$net.70'
export LB_IP_RANGE='$net.71-$net.75'
export WORKSPACE_NS='$ns'
EOF
)
chmod 600 "$f"
echo "written: $f"
bash -n "$f" && echo "syntax ok"
source "$f"
for v in CLUSTER_NAME CP_VIP LB_IP_RANGE WORKSPACE_NS; do [ -n "$(printenv "$v")" ] && echo "set: $v" || echo "MISSING: $v"; done
kubectl --kubeconfig "$MGMT_KUBECONFIG" --request-timeout=30s get ns "$WORKSPACE_NS" --no-headers 2>&1
