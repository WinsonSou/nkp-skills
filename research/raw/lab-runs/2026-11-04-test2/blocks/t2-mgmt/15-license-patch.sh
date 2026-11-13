# CHANGES  (points the license to the new key; NKP changes the tier and installs the apps of that tier)
source ~/nkp-site.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n kommander patch licenses.kommander.mesosphere.io nutanix-license --type merge -p '{"spec":{"nutanixLicenseRef":{"name":"nutanix-license-secret"}}}' 2>&1 | sed -E 's/Invalid value: "[^"]*"/Invalid value: "[masked]"/'
