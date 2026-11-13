# READ-ONLY  (nkp-airgap references/nodes.md, UNKNOWN A-31: can the pull account list all repositories? `url` line replaced by /v2/_catalog)
source ~/nkp-site.env 2>/dev/null
h="${REGISTRY_URL#*://}"; h="${h%/}"; host="${h%%/*}"
url="https://$host/v2/_catalog"
echo "url: /v2/_catalog"
curl -s --cacert "$REGISTRY_CA_FILE" --netrc-file /dev/stdin -w '\nhttp=%{http_code}\n' "$url" <<< "machine ${host%%:*} login $REGISTRY_MIRROR_USERNAME password $REGISTRY_MIRROR_PASSWORD" | head -c 600
echo
