# READ-ONLY  (registry IP as seen from the operator host; is nats-box already on the nodes?)
source ~/nkp-site.env 2>/dev/null
hp="${REGISTRY_URL#*//}"; host="${hp%%/*}"
echo "registry host: $host"
echo -n "registry ip: "; getent hosts "$host" | awk '{print $1}' | head -1
echo "== pods that already run an image we can reuse (by image name) =="
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" --request-timeout=30s get pods -A -o jsonpath='{range .items[*]}{.spec.containers[*].image}{"\n"}{end}' 2>/dev/null | sort -u | head -20
echo "== nats-box pod present? =="
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" --request-timeout=30s get pods -A 2>&1 | grep -E 'nats-box' | head -3 || echo "  no nats-box pod (image may not be cached)"
echo "== nodes NotReady now =="
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" --request-timeout=30s get nodes --no-headers 2>&1 | awk '$2!="Ready"{print "  "$1}'
echo "== a node /etc/hosts shape (through a pod? not yet) — skip =="
