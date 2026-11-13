# READ-ONLY
source ~/nkp-site.env 2>/dev/null
h="${REGISTRY_URL#*://}"; h="${h%/}"; host="${h%%/*}"; p="${h#"$host"}"; p="${p#/}"; p="${p:+$p/}"
echo "registry host: $host | project path: $p"
netrc=$(mktemp); chmod 600 "$netrc"
printf 'machine %s login %s password %s\n' "$host" "$REGISTRY_MIRROR_USERNAME" "$REGISTRY_MIRROR_PASSWORD" > "$netrc"
for r in "${p}nutanix/flow-cni" "${p}nutanix/flow-container-security" "${p}nutanix/flow-ovn-kubernetes" \
         "${p}nutanix-flow-cni" "${p}nats" "${p}natso/nats-box" "${p}k8snetworkplumbingwg/multus-cni"; do
  code=$(curl -sk -o /dev/null -w '%{http_code}' --max-time 10 --netrc-file "$netrc" "https://$host/v2/$r/tags/list")
  echo "  $r -> $code"
done
curl -sk -o /dev/null -w '  /v2/_catalog -> %{http_code}\n' --max-time 15 --netrc-file "$netrc" "https://$host/v2/_catalog"
rm -f "$netrc"
