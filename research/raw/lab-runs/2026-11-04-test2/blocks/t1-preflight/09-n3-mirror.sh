# READ-ONLY  (nkp-install references/nutanix.md N3, registry blocks, site mirror case 4C/5)
source ~/nkp-site.env 2>/dev/null
reg=${REGISTRY_URL#https://}; reg=${reg%%/*}
curl -s --cacert "$REGISTRY_CA_FILE" -o /dev/null -w 'mirror: %{http_code}\n' "https://$reg/v2/"
curl -s --cacert "$REGISTRY_CA_FILE" --netrc-file <(printf 'machine %s login %s password %s\n' "${reg%%:*}" "$(printenv REGISTRY_MIRROR_USERNAME)" "$(printenv REGISTRY_MIRROR_PASSWORD)") -o /dev/null -w 'mirror login: %{http_code}\n' "https://$reg/v2/"
echo "== registry identity and project (Harbor-shaped read-only paths) =="
curl -s --cacert "$REGISTRY_CA_FILE" "https://$reg/v2/" | head -c 200; echo
for v in REGISTRY_MIRROR_USERNAME REGISTRY_MIRROR_PASSWORD; do printenv "$v" >/dev/null && echo "set: $v" || echo "MISSING: $v"; done
reg_host="${REGISTRY_URL#*://}"; echo "registry path part: ${reg_host#*/}"
echo "== CA file subject (no key material) =="
openssl x509 -in "$REGISTRY_CA_FILE" -noout -subject -issuer -enddate 2>&1
