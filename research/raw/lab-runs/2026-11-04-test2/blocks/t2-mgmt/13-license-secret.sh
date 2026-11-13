# CHANGES  (makes Secret kommander/nutanix-license-secret with the license key)
source ~/nkp-site.env 2>/dev/null
: "${NKP_LICENSE_KEY:?}"
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n kommander create secret generic nutanix-license-secret --from-file=nutanix-license-key=<(printf %s "$(printenv NKP_LICENSE_KEY)") --dry-run=client -o yaml | kubectl --kubeconfig "$MGMT_KUBECONFIG" apply -f - -o name
