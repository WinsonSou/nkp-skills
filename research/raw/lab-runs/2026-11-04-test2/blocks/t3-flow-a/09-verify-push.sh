# READ-ONLY
source ~/nkp-site.env 2>/dev/null
h="${REGISTRY_URL#*://}"; h="${h%%/*}"; proj="${REGISTRY_URL#*/}"
auth=<(printf 'machine %s login %s password %s\n' "$h" "$(printenv REGISTRY_MIRROR_USERNAME)" "$(printenv REGISTRY_MIRROR_PASSWORD)")
for r in flow-cni flow-ovn-kubernetes flow-container-security k8snetworkplumbingwg/multus-cni nats nutanix-flow-cni; do
  code=$(curl -s --cacert "$REGISTRY_CA_FILE" --netrc-file "$auth" -o /tmp/_t.json -w '%{http_code}' "https://$h/v2/$proj/$r/tags/list")
  echo "$r -> http=$code $(head -c 120 /tmp/_t.json 2>/dev/null)"
done
rm -f /tmp/_t.json
echo "== first log lines of the push =="
head -n 6 ~/push-flow-cni.log | grep -v -i -E 'password|token|secret'
