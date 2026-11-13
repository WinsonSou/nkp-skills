# CHANGES  (replaces the one DaemonSet on skilltest-flow-a: repairs its own glued /etc/hosts line and writes a correct one; no other object changes)
source ~/nkp-skilltest-flow-a.env 2>/dev/null
h="${REGISTRY_URL#*://}"; h="${h%%/*}"; regip=$(getent hosts "$h" | awk '{print $1}' | head -1)
: "${regip:?}" "${h:?}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" --request-timeout=60s -n kube-system delete ds registry-hosts-fix --wait=true --timeout=60s 2>&1 | tail -1
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
          awk -v ip="${regip}" -v h="${h}" '{gsub(ip" "h,"")} {print}' /etc/hosts | grep -v -x "" > /tmp/h
          grep -qE "(^| )${h}( |\$)" /tmp/h || printf '%s %s\n' "${regip}" "${h}" >> /tmp/h
          cat /tmp/h > /etc/hosts
          echo "--- /etc/hosts now:"; tail -3 /etc/hosts
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
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" --request-timeout=60s apply -f /tmp/registry-hosts-fix.yaml -o name
echo "RC=$?"
rm -f /tmp/registry-hosts-fix.yaml
