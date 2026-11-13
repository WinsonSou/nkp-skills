# READ-ONLY  (nkp-airgap references/nodes.md "Check that the site mirror has an image", UNKNOWN A-30, try 2: without the registry host)
source ~/nkp-site.env 2>/dev/null
repo='pause'
h="${REGISTRY_URL#*://}"; h="${h%/}"; host="${h%%/*}"; p="${h#"$host"}"; p="${p#/}"; p="${p:+$p/}"
url="https://$host/v2/$p$repo/tags/list"
echo "url path: /v2/$p$repo/tags/list"
curl -s --cacert "$REGISTRY_CA_FILE" --netrc-file /dev/stdin -w '\nhttp=%{http_code}\n' "$url" <<< "machine ${host%%:*} login $REGISTRY_MIRROR_USERNAME password $REGISTRY_MIRROR_PASSWORD"
