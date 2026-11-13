# CHANGES  (deletes the pods in ImagePullBackOff/ErrImagePull on skilltest-flow-b so their controllers retry now)
source ~/nkp-skilltest-flow-b.env 2>/dev/null
K2="kubectl --kubeconfig $CLUSTER_KUBECONFIG --request-timeout=30s"
echo "== before =="; $K2 get pods -A --no-headers 2>&1 | awk '$4=="ImagePullBackOff"||$4=="ErrImagePull"{print "  "$1, $2, $4}'
for ns in flow-cns-system kommander-flux; do
  for p in $($K2 -n "$ns" get pods --no-headers 2>/dev/null | awk '$3=="ImagePullBackOff"||$3=="ErrImagePull"{print $1}'); do
    $K2 -n "$ns" delete pod "$p" --wait=false 2>&1 | sed 's/^/  /'
  done
done
echo "== 20 s later =="; sleep 20
$K2 get pods -A --no-headers 2>&1 | awk '$4=="ImagePullBackOff"||$4=="ErrImagePull"{print "  "$1, $2, $4}' | head -10
$K2 get pods -A --no-headers 2>&1 | awk '{print "  "$1, $3}' | grep -E 'flow-cns|kommander-flux' | head -12
