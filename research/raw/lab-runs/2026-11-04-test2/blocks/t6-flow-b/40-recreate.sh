# CHANGES  (re-creates skilltest-flow-b and pre-creates its three Flow namespaces as soon as the workload API answers)
source ~/nkp-skilltest-flow-b.env 2>/dev/null
cd "$HOME" || exit 1
f="$HOME/$CLUSTER_NAME-dryrun.yaml"; test -s "$f" || { echo "no dry-run file"; exit 1; }

# 1. the watcher script on the operator host
(umask 077 && cat > "$HOME/nkp-$CLUSTER_NAME-nswatch.sh" <<'EOS'
#!/bin/bash
source ~/nkp-skilltest-flow-b.env 2>/dev/null
kc="$HOME/skilltest-flow-b.conf"
for i in $(seq 1 180); do
  if ! kubectl --kubeconfig "$kc" --request-timeout=10s get ns >/dev/null 2>&1; then
    nkp get kubeconfig --cluster-name "$CLUSTER_NAME" --namespace "$WORKSPACE_NS" --kubeconfig "$MGMT_KUBECONFIG" > "$kc" 2>/dev/null && chmod 600 "$kc"
  fi
  all=1
  for n in flow-cni-system ovn-kubernetes flow-cns-system; do
    kubectl --kubeconfig "$kc" --request-timeout=10s get ns "$n" >/dev/null 2>&1 || all=0
  done
  [ "$all" = 1 ] && { echo "$(date +%H:%M:%S) all three namespaces exist"; exit 0; }
  for n in flow-cni-system ovn-kubernetes flow-cns-system; do
    kubectl --kubeconfig "$kc" --request-timeout=10s create namespace "$n" >/dev/null 2>&1 && echo "$(date +%H:%M:%S) created $n"
  done
  sleep 4
done
echo "$(date +%H:%M:%S) gave up"
EOS
)
chmod 700 "$HOME/nkp-$CLUSTER_NAME-nswatch.sh"
tmux kill-session -t "nkp-$CLUSTER_NAME-ns" 2>/dev/null
tmux new-session -d -s "nkp-$CLUSTER_NAME-ns" -c "$HOME" "bash -c 'bash ~/nkp-$CLUSTER_NAME-nswatch.sh > ~/nkp-$CLUSTER_NAME-nswatch.log 2>&1; echo RC=\$? >> ~/nkp-$CLUSTER_NAME-nswatch.log'"
echo "$(date +%H:%M:%S) watcher started"

# 2. recreate: Secrets + NKPCluster
yq 'select(.kind == "Secret")' "$f" | kubectl --kubeconfig "$MGMT_KUBECONFIG" --request-timeout=30s apply --server-side -f - -o name
yq 'select(.kind == "NKPCluster")' "$f" | kubectl --kubeconfig "$MGMT_KUBECONFIG" --request-timeout=30s apply --server-side -f - -o name
echo "$(date +%H:%M:%S) applied RC=$?"
sleep 30
echo "== watcher log =="; cat "$HOME/nkp-$CLUSTER_NAME-nswatch.log" 2>&1
echo "== cluster =="; kubectl --kubeconfig "$MGMT_KUBECONFIG" --request-timeout=30s -n "$WORKSPACE_NS" get nkpclusters --no-headers 2>&1
