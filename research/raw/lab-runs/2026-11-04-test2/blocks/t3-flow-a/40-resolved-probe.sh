# CHANGES  ([exploration] one short probe pod on each cluster to test the node systemd-resolved stub 127.0.0.53, hostNetwork, deleted after)
source ~/nkp-skilltest-flow-a.env 2>/dev/null
h="${REGISTRY_URL#*://}"; h="${h%%/*}"; regip=$(getent hosts "$h" | awk '{print $1}' | head -1)
up=$(awk '/^nameserver/{print $2; exit}' /run/systemd/resolve/resolv.conf 2>/dev/null || awk '/^nameserver/{print $2; exit}' /etc/resolv.conf)
echo "upstream dns: $up   registry ip: $regip"
probe() { # $1 kubeconfig  $2 namespace  $3 podname
  kubectl --kubeconfig "$1" --request-timeout=60s -n "$2" run "$3" --image=natsio/nats-box:0.14.1 --restart=Never --image-pull-policy=IfNotPresent \
    --overrides='{"spec":{"hostNetwork":true,"dnsPolicy":"None","dnsConfig":{"nameservers":["127.0.0.53"]}}}' -- \
    sh -c "echo RESOLV:; cat /etc/resolv.conf; echo STUB-127.0.0.53:; getent hosts $h || echo stub-failed; echo UPSTREAM-$up:; nslookup $h $up 2>&1 | tail -3" >/dev/null 2>&1
}
probe "$CLUSTER_KUBECONFIG" default dnsprobe-flow
probe "$MGMT_KUBECONFIG" kommander dnsprobe-mgmt
echo "probes created"
