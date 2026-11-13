# CHANGES  (adds one line "<registry-ip> <registry-host>" to the /etc/hosts of the nodes of skilltest-flow-b only, through a privileged DaemonSet)
source ~/nkp-skilltest-flow-b.env 2>/dev/null
hp="${REGISTRY_URL#*//}"; host="${hp%%/*}"
ip=$(getent hosts "$host" | awk '{print $1}' | head -1)
: "${ip:?no registry ip}" "${host:?no registry host}"
echo "target line: $ip $host"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" --request-timeout=30s -n kube-system delete ds registry-hosts-fix --ignore-not-found >/dev/null 2>&1
(umask 077 && cat > /tmp/registry-hosts-fix.yaml <<EOF
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: registry-hosts-fix
  namespace: kube-system
  labels:
    app: registry-hosts-fix
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
      dnsPolicy: Default
      tolerations:
        - operator: Exists
      containers:
        - name: fix
          image: natsio/nats-box:0.14.1
          securityContext:
            privileged: true
          command: ["/bin/sh","-c"]
          args:
            - |
              host='$host'; ip='$ip'; f=/etc/hosts
              if grep -qxF "\$ip \$host" "\$f"; then echo "already: \$ip \$host"; else
                awk -v h="\$host" '{ o=""; for(i=1;i<=NF;i++){ if(\$i==h) continue; o=o (o==""?"":" ") \$i } if(o!="") print o }' "\$f" > /tmp/hosts.new
                printf '%s %s\n' "\$ip" "\$host" >> /tmp/hosts.new
                cat /tmp/hosts.new > "\$f"
                echo "written: \$ip \$host"
              fi
              echo "--- /etc/hosts ---"; cat "\$f"; echo "--- end ---"
              while true; do sleep 3600; done
          volumeMounts:
            - name: hosts
              mountPath: /etc/hosts
      volumes:
        - name: hosts
          hostPath:
            path: /etc/hosts
EOF
)
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" --request-timeout=30s apply -f /tmp/registry-hosts-fix.yaml
echo "RC=$?"
sleep 25
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" --request-timeout=30s -n kube-system get ds,pods -l app=registry-hosts-fix -o wide --no-headers 2>&1 | awk '{print "  "$1, $2, $3, $4}'
echo "== one node's written file (from the pod log) =="
p=$(kubectl --kubeconfig "$CLUSTER_KUBECONFIG" --request-timeout=30s -n kube-system get pods -l app=registry-hosts-fix --no-headers 2>/dev/null | awk 'NR==1{print $1}')
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" --request-timeout=30s -n kube-system logs "$p" 2>&1 | head -20
rm -f /tmp/registry-hosts-fix.yaml
