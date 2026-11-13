# READ-ONLY
source ~/nkp-site.env 2>/dev/null
echo "== syntax (site file) =="
bash -n ~/nkp-site.env 2>&1 && echo "set: syntax" || echo "MISSING: syntax"
echo "== site variables (management create, site mirror 4C) =="
for v in PC_ENDPOINT PE_CLUSTER SUBNET STORAGE_CONTAINER VM_IMAGE SSH_PUBKEY_FILE BUNDLE_DIR IMAGE_BUNDLES REGISTRY_URL REGISTRY_CA_FILE NTP_SERVERS; do if [ -n "$(printenv "$v")" ]; then echo "set: $v"; else echo "MISSING: $v"; fi; done
echo "== optional site variables =="
for v in PC_CA_FILE PC_PROJECT NKP_HTTP_PROXY NKP_HTTPS_PROXY MGMT_KUBECONFIG; do if [ -n "$(printenv "$v")" ]; then echo "set: $v"; else echo "MISSING: $v"; fi; done
echo "== secrets (set/MISSING only) =="
for v in NUTANIX_USER NUTANIX_PASSWORD REGISTRY_MIRROR_USERNAME REGISTRY_MIRROR_PASSWORD NUTANIX_REGISTRY_USERNAME NUTANIX_REGISTRY_TOKEN NKP_LICENSE_KEY; do printenv "$v" >/dev/null && echo "set: $v" || echo "MISSING: $v"; done
echo "== non-secret values (names only) =="
echo "SUBNET=$SUBNET"; echo "VM_IMAGE=$VM_IMAGE"; echo "PE_CLUSTER=$PE_CLUSTER"; echo "STORAGE_CONTAINER=$STORAGE_CONTAINER"
echo "REGISTRY_URL path part: ${REGISTRY_URL#*://*/}"
echo "NTP_SERVERS count: $(printf '%s' "$NTP_SERVERS" | tr ',' '\n' | grep -c .)"
echo "== files that the variables point at =="
test -d "$BUNDLE_DIR" && echo "BUNDLE_DIR ok" || echo "BUNDLE_DIR MISSING"
for f in $(printf '%s' "$IMAGE_BUNDLES" | tr ',' ' '); do test -f "$f" && echo "IMAGE_BUNDLES ok: $(basename "$f")" || echo "IMAGE_BUNDLES MISSING: $(basename "$f")"; done
test -f "$REGISTRY_CA_FILE" && echo "REGISTRY_CA_FILE ok" || echo "REGISTRY_CA_FILE MISSING"
test -f "$SSH_PUBKEY_FILE" && echo "SSH_PUBKEY_FILE ok" || echo "SSH_PUBKEY_FILE MISSING"
test -f "$PC_CA_FILE" && echo "PC_CA_FILE ok" || echo "PC_CA_FILE not a file (optional)"
test -f "$MGMT_KUBECONFIG" && echo "MGMT_KUBECONFIG ok" || echo "MGMT_KUBECONFIG dangling (expected: no management cluster)"
echo "== other nkp env files in home =="
ls -a ~ | grep -E '^nkp-.*\.env$' || echo "(only the site file)"
