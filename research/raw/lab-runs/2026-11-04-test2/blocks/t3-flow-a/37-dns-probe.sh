# CHANGES  ([exploration] one short probe pod on skilltest-flow-a in namespace default, hostNetwork, to see the node DNS path; deleted in the next block)
source ~/nkp-skilltest-flow-a.env 2>/dev/null
h="${REGISTRY_URL#*://}"; h="${h%%/*}"; regip=$(getent hosts "$h" | awk '{print $1}' | head -1)
: "${regip:?cannot resolve the registry name on the operator host}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" --request-timeout=60s -n default run dnsprobe --image=natsio/nats-box:0.14.1 --restart=Never --image-pull-policy=IfNotPresent \
  --overrides='{"spec":{"hostNetwork":true,"dnsPolicy":"Default"}}' -- sh -c "echo RESOLV:; cat /etc/resolv.conf; echo HOSTS:; getent hosts $h || echo getent-failed; echo ROUTE:; ip route 2>/dev/null | head -4; echo LINK:; ip -o link 2>/dev/null | awk '{print \$2}' | head -8; echo TCP:; (timeout 5 bash -c \"echo > /dev/tcp/$regip/443\") 2>&1 && echo tcp443-ok || echo tcp443-fail"
echo "RC=$?"
