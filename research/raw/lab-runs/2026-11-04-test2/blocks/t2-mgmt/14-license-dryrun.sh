# READ-ONLY  (server dry run: changes nothing; the sed mask hides the key in a webhook error)
source ~/nkp-site.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n kommander patch licenses.kommander.mesosphere.io nutanix-license --type merge -p '{"spec":{"nutanixLicenseRef":{"name":"nutanix-license-secret"}}}' --dry-run=server -o jsonpath='{.spec}{"\n"}' 2>&1 | sed -E 's/Invalid value: "[^"]*"/Invalid value: "[masked]"/'
