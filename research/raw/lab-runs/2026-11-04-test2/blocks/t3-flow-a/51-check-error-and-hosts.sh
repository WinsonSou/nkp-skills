# READ-ONLY
source ~/nkp-skilltest-flow-a.env 2>/dev/null
echo "== current pull error =="
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" --request-timeout=30s -n flow-cns-system get events --sort-by=.lastTimestamp 2>/dev/null | tail -3
echo "== a node /etc/hosts as seen from a hostNetwork pod =="
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" --request-timeout=60s -n default run hostprobe --image=natsio/nats-box:0.14.1 --restart=Never --image-pull-policy=IfNotPresent \
  --overrides='{"spec":{"hostNetwork":true,"dnsPolicy":"None","dnsConfig":{"nameservers":["127.0.0.53"]}}}' -- sh -c "cat /etc/hosts; echo STUB:; getent hosts <host>" >/dev/null 2>&1
h="${REGISTRY_URL#*://}"; h="${h%%/*}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" --request-timeout=60s -n default delete pod hostprobe --ignore-not-found >/dev/null 2>&1
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" --request-timeout=60s -n default run hostprobe --image=natsio/nats-box:0.14.1 --restart=Never --image-pull-policy=IfNotPresent \
  --overrides='{"spec":{"hostNetwork":true,"dnsPolicy":"None","dnsConfig":{"nameservers":["127.0.0.53"]}}}' -- sh -c "cat /etc/hosts; echo STUB:; getent hosts $h" >/dev/null 2>&1
echo "probe created ($h)"
