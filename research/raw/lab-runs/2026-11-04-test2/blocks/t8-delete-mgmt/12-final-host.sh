# READ-ONLY
source ~/nkp-site.env 2>/dev/null
echo "== operator host: any file of the three test clusters =="
ls -a ~ | grep -E 'nkp-mgmt-01|skilltest-flow|skilltest-mgmt-01' || echo "(no line)"
echo "== any container / kind cluster / tmux session =="
docker ps -a --format '{{.Names}}' | grep -i -E 'bootstrap|kind' || echo "no bootstrap or kind container"
docker ps -a --format '{{.Names}}' | wc -l
tmux ls 2>&1
echo "== kubeconfigs in HOME =="
ls -l ~/*.conf 2>&1 || echo "no .conf file"
echo "== site file =="
wc -l < ~/nkp-site.env
grep -n '^export MGMT_KUBECONFIG=' ~/nkp-site.env
test -f "$MGMT_KUBECONFIG" && echo "MGMT_KUBECONFIG: file found" || echo "MGMT_KUBECONFIG: no file"
test -f "$HOME/nkp-nkp-mgmt-01.env" && echo "cluster env file present" || echo "cluster env file gone"
echo "== kept bundle files =="
ls -l "$BUNDLE_DIR"/konvoy-bootstrap-image-*.tar ~/flow-cni-1.1.0.tar ~/nkp-bundle_v2.19.0_linux_amd64.tar.gz 2>&1 | sed 's/ ubuntu ubuntu / /'
echo "== free IP check, ICMP half (D3) =="
for ip in "${CP_VIP:-<net>.50}" <net>.51 <net>.52 <net>.53 <net>.54 <net>.55; do
  ping -c 1 -W 2 "$ip" >/dev/null 2>&1 && echo "$ip answers ICMP" || echo "$ip no ICMP reply"
done
echo "== registry: the Flow CNI repositories must stay (read-only tags/list) =="
netrc=$(mktemp); chmod 600 "$netrc"
printf 'machine %s login %s password %s\n' "$(printf '%s' "$REGISTRY_URL" | cut -d/ -f1)" "$REGISTRY_MIRROR_USERNAME" "$REGISTRY_MIRROR_PASSWORD" > "$netrc"
reg=$(printf '%s' "$REGISTRY_URL" | cut -d/ -f1); proj=$(printf '%s' "$REGISTRY_URL" | cut -d/ -f2)
for r in "$proj/nutanix/flow-cni" "$proj/nutanix/flow-container-security" "$proj/nutanix/flow-ovn-kubernetes" "$proj/nutanix-flow-cni" "$proj/nats" "$proj/k8snetworkplumbingwg/multus-cni"; do
  code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 --netrc-file "$netrc" "http://$reg/v2/$r/tags/list")
  echo "  $r -> $code"
done
curl -s -o /dev/null -w '  /v2/_catalog -> %{http_code}\n' --max-time 15 --netrc-file "$netrc" "http://$reg/v2/_catalog"
rm -f "$netrc"
