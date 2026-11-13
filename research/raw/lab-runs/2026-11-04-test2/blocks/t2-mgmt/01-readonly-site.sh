# READ-ONLY
source ~/nkp-site.env 2>/dev/null
echo "=== host"
nkp version | head -3
docker version --format '{{.Server.Version}}' 2>/dev/null
kubectl version --client 2>/dev/null | head -1
stat -fc %T /sys/fs/cgroup; tmux -V; command -v yq jq >/dev/null && echo "yq/jq ok"
nproc; free -g | awk 'NR<=2'; df -h "$HOME" | tail -1
echo "=== site env names"
bash -n ~/nkp-site.env && echo "set: syntax" || echo "MISSING: syntax"
for v in PC_ENDPOINT PE_CLUSTER SUBNET STORAGE_CONTAINER VM_IMAGE SSH_PUBKEY_FILE BUNDLE_DIR REGISTRY_URL REGISTRY_CA_FILE NTP_SERVERS NUTANIX_USER NUTANIX_PASSWORD REGISTRY_MIRROR_USERNAME REGISTRY_MIRROR_PASSWORD NKP_LICENSE_KEY MGMT_KUBECONFIG; do if [ -n "$(printenv "$v")" ]; then echo "set: $v"; else echo "MISSING: $v"; fi; done
echo "MGMT_KUBECONFIG file present:"; test -f "$MGMT_KUBECONFIG" && echo yes || echo no
echo "=== cluster env file (expected absent)"
ls -1 ~/nkp-*.env 2>/dev/null
echo "=== pc"
curl -sk -o /dev/null -w 'pc: %{http_code}\n' "$PC_ENDPOINT"
pc=${PC_ENDPOINT#https://}; pc=${pc%%[:/]*}
curl -sk --netrc-file <(printf 'machine %s login %s password %s\n' "$pc" "$(printenv NUTANIX_USER)" "$(printenv NUTANIX_PASSWORD)") -o /dev/null -w 'pc login: %{http_code}\n' "$PC_ENDPOINT/api/clustermgmt/v4.0/config/clusters"
openssl s_client -connect "$pc:9440" -servername "$pc" </dev/null 2>/dev/null | openssl x509 -noout -subject -ext subjectAltName
echo "=== mirror"
reg=${REGISTRY_URL#https://}; reg=${reg%%/*}
curl -s --cacert "$REGISTRY_CA_FILE" -o /dev/null -w 'mirror: %{http_code}\n' "https://$reg/v2/"
curl -s --cacert "$REGISTRY_CA_FILE" --netrc-file <(printf 'machine %s login %s password %s\n' "${reg%%:*}" "$(printenv REGISTRY_MIRROR_USERNAME)" "$(printenv REGISTRY_MIRROR_PASSWORD)") -o /dev/null -w 'mirror login: %{http_code}\n' "https://$reg/v2/"
echo "=== bundle bootstrap image + ssh key + ca files"
ls -1 "$BUNDLE_DIR"/konvoy-bootstrap-image-*.tar 2>/dev/null
test -f "$SSH_PUBKEY_FILE" && echo "ssh key file found"
test -f "$REGISTRY_CA_FILE" && echo "registry ca file found"
echo "=== leftover bootstrap/nkp procs"
docker ps -a --format '{{.Names}} {{.Image}}' | grep -i -e kind -e bootstrap || echo "no bootstrap container"
tmux ls 2>/dev/null || echo "no tmux session"
