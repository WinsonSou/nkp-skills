# CHANGES  (adds one DaemonSet on skilltest-flow-a: writes <registry-ip> <registry-host> into each node /etc/hosts; no other object changes)
source ~/nkp-skilltest-flow-a.env 2>/dev/null
h="${REGISTRY_URL#*://}"; h="${h%%/*}"; regip=$(getent hosts "$h" | awk '{print $1}' | head -1)
: "${regip:?cannot resolve the registry name on the operator host}" "${h:?}"
cat > /tmp/registry-hosts-fix.yaml <<EOF
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: registry-hosts-fix
  namespace: kube-system
spec:
  selector:
    matchLabels:
      app: registry-hosts-fix
  template:
    metadata:
      labels:
        app: registry-hosts-fix
    spec:
      hostNetwork: true
      priorityClassName: system-node-critical
      tolerations:
      - operator: Exists
      containers:
      - name: fix
        image: natsio/nats-box:0.14.1
        imagePullPolicy: IfNotPresent
        securityContext:
          privileged: true
          runAsUser: 0
        command: ["sh", "-c"]
        args:
        - |
          if grep -q " ${h}\$" /etc/hosts; then echo "already: ${h}"; else echo "${regip} ${h}" >> /etc/hosts && echo "added: ${h}"; fi
          sleep infinity
        volumeMounts:
        - name: hosts
          mountPath: /etc/hosts
      volumes:
      - name: hosts
        hostPath:
          path: /etc/hosts
          type: File
EOF
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" --request-timeout=60s apply --dry-run=server -f /tmp/registry-hosts-fix.yaml -o name && \
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" --request-timeout=60s apply -f /tmp/registry-hosts-fix.yaml -o name
echo "RC=$?"
rm -f /tmp/registry-hosts-fix.yaml
