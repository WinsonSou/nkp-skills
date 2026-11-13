# READ-ONLY
source ~/nkp-nkp-mgmt-01.env 2>/dev/null
nkp describe cluster --cluster-name "$CLUSTER_NAME" --namespace "$WORKSPACE_NS" --kubeconfig "$MGMT_KUBECONFIG" 2>&1 | tail -20
echo "--- pods not Running/Succeeded (expect nothing)"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" --request-timeout=30s get pods -A --field-selector=status.phase!=Running,status.phase!=Succeeded 2>/dev/null
echo "--- N6"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" --request-timeout=30s get storageclass
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" --request-timeout=30s -n metallb-system get ipaddresspools
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" --request-timeout=30s -n ntnx-system get pods 2>&1 | tail -3
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" --request-timeout=30s -n kube-system get pods -l k8s-app=cilium --no-headers 2>&1 | awk '{print $2, $3}' | sort | uniq -c
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" --request-timeout=30s -n "$WORKSPACE_NS" get svc kommander-traefik -o custom-columns='NAME:.metadata.name,EXTERNAL-IP:.status.loadBalancer.ingress[*].ip'
echo "--- license state"
kubectl --kubeconfig "$MGMT_KUBECONFIG" --request-timeout=30s -n kommander get licenses.kommander.mesosphere.io nutanix-license -o jsonpath='tier={.status.dkpLevel} valid={.status.valid} end={.status.endDate}{"\n"}'
kubectl --kubeconfig "$MGMT_KUBECONFIG" --request-timeout=30s -n kommander get licenses.kommander.mesosphere.io nutanix-license -o jsonpath='ref={.spec.nutanixLicenseRef.name}{"\n"}'
echo "--- workers cpu/mem requests"
kubectl --kubeconfig "$MGMT_KUBECONFIG" --request-timeout=30s describe nodes -l '!node-role.kubernetes.io/control-plane' 2>/dev/null | grep -E '^Name:|^  (cpu|memory) +[0-9]'
