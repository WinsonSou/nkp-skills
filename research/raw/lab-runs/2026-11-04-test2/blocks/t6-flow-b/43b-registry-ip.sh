# READ-ONLY  (registry IP as seen from the operator host; which images are on the nodes)
source ~/nkp-skilltest-flow-b.env 2>/dev/null
hp="${REGISTRY_URL#*//}"; host="${hp%%/*}"
echo "registry host: $host"
echo -n "registry ip: "; getent hosts "$host" | awk '{print $1}' | head -1
K2="kubectl --kubeconfig $CLUSTER_KUBECONFIG --request-timeout=30s"
echo "== images currently on the cluster =="; $K2 get pods -A -o jsonpath='{range .items[*]}{.spec.containers[*].image}{"\n"}{end}' 2>/dev/null | sort -u | head -20
echo "== nats-box pod =="; $K2 get pods -A 2>&1 | grep -i 'nats-box' | head -3 || echo "  none"
echo "== nodes not Ready =="; $K2 get nodes --no-headers 2>&1 | awk '$2!="Ready"{print "  "$1, $2}'
echo "== pods in ImagePullBackOff =="; $K2 get pods -A --no-headers 2>&1 | awk '$4=="ImagePullBackOff"||$4=="ErrImagePull"{print "  "$1, $2}' | head -8
