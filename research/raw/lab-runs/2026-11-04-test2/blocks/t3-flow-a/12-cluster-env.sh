# CHANGES  (writes the cluster env file ~/nkp-skilltest-flow-a.env; values derived from the management cluster file)
source ~/nkp-nkp-mgmt-01.env 2>/dev/null
: "${CP_VIP:?no CP_VIP in ~/nkp-nkp-mgmt-01.env}"
net="${CP_VIP%.*}"
umask 077
f="$HOME/nkp-skilltest-flow-a.env"
{
  echo 'source ~/nkp-site.env 2>/dev/null'
  echo "export CLUSTER_NAME='skilltest-flow-a'"
  echo "export CP_VIP='$net.60'"
  echo "export LB_IP_RANGE='$net.61-$net.65'"
  echo "export WORKSPACE_NS='skilltest-flow-dw97w'"
} > "$f"
chmod 600 "$f"
source "$f" 2>/dev/null
for v in CLUSTER_NAME CP_VIP LB_IP_RANGE WORKSPACE_NS; do if [ -n "$(printenv "$v")" ]; then echo "set: $v"; else echo "MISSING: $v"; fi; done
kubectl --kubeconfig "$MGMT_KUBECONFIG" --request-timeout=30s get ns "$WORKSPACE_NS" --no-headers
echo "CP_VIP last octet: ${CP_VIP##*.}   LB range: .${LB_IP_RANGE#*.}" | sed 's/\.[0-9]\{1,3\}-/.<start>-/'
