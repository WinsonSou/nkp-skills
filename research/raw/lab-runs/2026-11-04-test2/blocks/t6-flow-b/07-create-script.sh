# CHANGES  (writes the create script ~/nkp-skilltest-flow-b-create.sh on the operator host; creates nothing yet)
source ~/nkp-skilltest-flow-b.env 2>/dev/null
: "${CLUSTER_NAME:?}" "${CP_VIP:?}" "${WORKSPACE_NS:?}" "${MGMT_KUBECONFIG:?}"
(umask 077 && cat > "$HOME/nkp-$CLUSTER_NAME-create.sh" <<'EOF'
nkp create cluster nutanix \
  --kubeconfig "$MGMT_KUBECONFIG" \
  --namespace "$WORKSPACE_NS" \
  --airgapped \
  ${REGISTRY_URL:+--registry-mirror-url "$REGISTRY_URL" --registry-mirror-cacert "$REGISTRY_CA_FILE"} \
  ${REGISTRY_MIRROR_USERNAME:+--registry-mirror-username "$REGISTRY_MIRROR_USERNAME"} \
  ${REGISTRY_MIRROR_PASSWORD:+--registry-mirror-password "$REGISTRY_MIRROR_PASSWORD"} \
  --insecure \
  --cluster-name "$CLUSTER_NAME" \
  --endpoint "$PC_ENDPOINT" \
  --control-plane-endpoint-ip "$CP_VIP" \
  --control-plane-prism-element-cluster "$PE_CLUSTER" \
  --control-plane-subnets "$SUBNET" \
  --control-plane-vm-image "$VM_IMAGE" \
  --worker-prism-element-cluster "$PE_CLUSTER" \
  --worker-subnets "$SUBNET" \
  --worker-vm-image "$VM_IMAGE" \
  --csi-storage-container "$STORAGE_CONTAINER" \
  --kubernetes-service-load-balancer-ip-range "$LB_IP_RANGE" \
  --ssh-public-key-file "$SSH_PUBKEY_FILE" \
  ${NTP_SERVERS:+--ntp-servers "$NTP_SERVERS"} \
  ${PC_PROJECT:+--pc-project "$PC_PROJECT"} \
  ${PC_CA_FILE:+--additional-trust-bundle "$(base64 < "$PC_CA_FILE" | tr -d '\n')"} \
  "$@"
EOF
)
chmod 600 "$HOME/nkp-$CLUSTER_NAME-create.sh"
bash -n "$HOME/nkp-$CLUSTER_NAME-create.sh" && echo "syntax ok"
echo "flags: $(grep -c -- ' --' "$HOME/nkp-$CLUSTER_NAME-create.sh")"
grep -v -E 'password|PASSWORD' "$HOME/nkp-$CLUSTER_NAME-create.sh" | grep -E 'cluster-name|endpoint-ip|vm-image|mirror-url|ip-range|namespace|airgapped|insecure'
