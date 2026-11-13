# READ-ONLY  (N2, case 4C)
source ~/nkp-nkp-mgmt-01.env 2>/dev/null
bash -n ~/nkp-site.env 2>/dev/null && bash -n ~/nkp-nkp-mgmt-01.env 2>/dev/null && echo "set: syntax" || echo "MISSING: syntax"
for v in CLUSTER_NAME CP_VIP LB_IP_RANGE WORKSPACE_NS PC_ENDPOINT PE_CLUSTER SUBNET STORAGE_CONTAINER VM_IMAGE SSH_PUBKEY_FILE NUTANIX_USER NUTANIX_PASSWORD; do if [ -n "$(printenv "$v")" ]; then echo "set: $v"; else echo "MISSING: $v"; fi; done
for v in NTP_SERVERS BUNDLE_DIR REGISTRY_URL REGISTRY_CA_FILE; do if [ -n "$(printenv "$v")" ]; then echo "set: $v"; else echo "MISSING: $v"; fi; done
for v in REGISTRY_MIRROR_USERNAME REGISTRY_MIRROR_PASSWORD; do printenv "$v" >/dev/null && echo "set: $v" || echo "MISSING: $v"; done
