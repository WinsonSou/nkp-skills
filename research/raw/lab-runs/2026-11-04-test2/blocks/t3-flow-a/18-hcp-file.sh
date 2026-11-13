# CHANGES  (writes the Flow CNI HelmChartProxy file on the operator host; dark site: no pull token; changes no cluster)
source ~/nkp-skilltest-flow-a.env 2>/dev/null
mode='darksite'; hostprefix='24'
case "$mode" in connected|darksite) ;; *) echo "set mode to connected or darksite"; exit 1;; esac
f="$PWD/$CLUSTER_NAME-dryrun.yaml"; out="$PWD/$CLUSTER_NAME-flow-cni-hcp.yaml"
ver=$(kubectl --kubeconfig "$MGMT_KUBECONFIG" --request-timeout=30s -n caren-system get configmap default-helm-addons-config -o jsonpath='{.data.nutanix-flow-cni}' | awk '/ChartVersion/{print $2}'); : "${ver:?no Flow chart version on the management cluster}"
pod=$(yq 'select(.kind == "NKPCluster" or .kind == "Cluster") | (.spec.capiCluster.clusterNetwork // .spec.clusterNetwork).pods.cidrBlocks[0]' "$f" | head -n 1)
svc=$(yq 'select(.kind == "NKPCluster" or .kind == "Cluster") | (.spec.capiCluster.clusterNetwork // .spec.clusterNetwork).services.cidrBlocks[0]' "$f" | head -n 1)
[ -n "$pod" ] && [ "$pod" != null ] && [ -n "$svc" ] && [ "$svc" != null ] || { echo "no CIDRs in the dry-run file"; exit 1; }
: "${CP_VIP:?}" "${CLUSTER_NAME:?}" "${WORKSPACE_NS:?}"
umask 077
cat > "$out" <<EOF
apiVersion: addons.cluster.x-k8s.io/v1alpha1
kind: HelmChartProxy
metadata:
  name: $CLUSTER_NAME-flow-cni
  namespace: $WORKSPACE_NS
spec:
  clusterSelector:
    matchLabels:
      cluster.x-k8s.io/cluster-name: $CLUSTER_NAME
  repoURL: oci://helm-repository.caren-system.svc/charts
  tlsConfig:
    caSecret:
      name: helm-repository-tls
      namespace: caren-system
  chartName: nutanix-flow-cni
  version: "$ver"
  namespace: flow-cni-system
  options:
    wait: true
    waitForJobs: true
    timeout: 30m
    install:
      createNamespace: true
  valuesTemplate: |
    nutanix-core-flow-ovn-kubernetes:
      k8sAPIServer: "https://$CP_VIP:6443"
      podNetwork: "$pod/$hostprefix"
      serviceNetwork: "$svc"
EOF
chmod 600 "$out"
echo "written: $out"
grep -v -E '^ +auth:' "$out"
