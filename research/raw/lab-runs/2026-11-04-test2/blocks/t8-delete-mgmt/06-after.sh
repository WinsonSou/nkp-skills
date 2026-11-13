# READ-ONLY
source ~/nkp-nkp-mgmt-01.env 2>/dev/null
echo "== t8: delete log end =="
tail -n 3 "$HOME/nkp-$CLUSTER_NAME-delete.log"
echo "== D4 check: bootstrap cluster / files =="
docker ps -a --format '{{.Names}}' | grep -i bootstrap || echo "no container with bootstrap in its name"
ls -l "$PWD/$CLUSTER_NAME-bootstrap.conf" 2>&1
ls -a "$HOME" | grep -i bootstrap || echo "no bootstrap file in HOME"
tmux ls 2>&1
echo "== D3 IP check =="
ping -c 2 -W 2 "$CP_VIP" >/dev/null 2>&1 && echo "CP_VIP answers" || echo "CP_VIP no reply"
curl -sk -o /dev/null -w 'lb_first_ip=%{http_code}\n' --max-time 5 "https://${LB_IP_RANGE%%-*}/"
curl -sk -o /dev/null -w 'cp_vip_https=%{http_code}\n' --max-time 5 "https://${CP_VIP}:6443/"
echo "== management API =="
kubectl --kubeconfig "$MGMT_KUBECONFIG" --request-timeout=30s get nodes 2>&1 | tail -2
echo "== operator host files with the cluster name =="
ls -l ~/ | grep -F -- "$CLUSTER_NAME"
ls -a ~ | grep -F -- "$CLUSTER_NAME"
echo "== kind clusters (docker) =="
docker ps -a --format '{{.Names}} {{.Status}}' | grep -i -E 'bootstrap|kind' || echo "none"
echo "== kept =="
ls -l ~/nkp-site.env ~/flow-cni-1.1.0.tar 2>&1 | sed 's/ ubuntu ubuntu / /'
ls -l "$BUNDLE_DIR"/konvoy-bootstrap-image-*.tar | sed 's/ ubuntu ubuntu / /'
echo "== disk =="
df -h / | tail -1
