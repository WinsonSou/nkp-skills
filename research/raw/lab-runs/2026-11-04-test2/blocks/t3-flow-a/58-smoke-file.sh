# CHANGES  (writes the smoke test file on the operator host; changes no cluster)
source ~/nkp-skilltest-flow-a.env 2>/dev/null
web_img='docker.io/nginxinc/nginx-unprivileged:1.29.5-alpine'
init_img='docker.io/library/busybox:1'
: "${web_img:?}" "${init_img:?}"
cat > "$PWD/$CLUSTER_NAME-smoke.yaml" <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: smoke-data
spec:
  accessModes: ["ReadWriteOnce"]
  resources:
    requests:
      storage: 1Gi
---
apiVersion: v1
kind: Pod
metadata:
  name: smoke
  labels:
    app: smoke
spec:
  initContainers:
  - name: seed
    image: $init_img
    command: ["sh", "-c", "echo smoke test $CLUSTER_NAME > /data/index.html"]
    volumeMounts:
    - name: data
      mountPath: /data
  containers:
  - name: web
    image: $web_img
    ports:
    - containerPort: 8080
    volumeMounts:
    - name: data
      mountPath: /usr/share/nginx/html
  volumes:
  - name: data
    persistentVolumeClaim:
      claimName: smoke-data
---
apiVersion: v1
kind: Service
metadata:
  name: smoke-lb
spec:
  type: LoadBalancer
  selector:
    app: smoke
  ports:
  - port: 80
    targetPort: 8080
EOF
echo "written: $PWD/$CLUSTER_NAME-smoke.yaml"
