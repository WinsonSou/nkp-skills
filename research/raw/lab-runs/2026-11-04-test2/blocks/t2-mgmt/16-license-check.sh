# READ-ONLY
source ~/nkp-site.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" --request-timeout=30s -n kommander get licenses.kommander.mesosphere.io nutanix-license -o jsonpath='tier={.status.dkpLevel} valid={.status.valid} end={.status.endDate}{"\n"}'
kubectl --kubeconfig "$MGMT_KUBECONFIG" --request-timeout=30s -n kommander get licenses.kommander.mesosphere.io nutanix-license -o jsonpath='ref={.spec.nutanixLicenseRef.name}{"\n"}'
echo "--- kommander helmrelease count"
kubectl --kubeconfig "$MGMT_KUBECONFIG" --request-timeout=30s -n kommander get helmreleases --no-headers | wc -l
echo "--- not ready"
kubectl --kubeconfig "$MGMT_KUBECONFIG" --request-timeout=30s get helmreleases -A | awk 'NR==1 || $4!="True"'
