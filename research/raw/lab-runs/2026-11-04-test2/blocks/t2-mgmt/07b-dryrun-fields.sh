# READ-ONLY
source ~/nkp-nkp-mgmt-01.env 2>/dev/null
f=~/"$CLUSTER_NAME"-dryrun.yaml
echo "--- image references (count of the VM_IMAGE string):"; grep -c -F "$VM_IMAGE" "$f"
echo "--- all 'replicas:' lines with 2 lines of context (no secrets in this region):"
grep -n -E '^ +replicas: ' "$f"
echo "--- machinePool / nodepool kind names:"
grep -n -E '^kind: (NutanixMachineTemplate|.*MachinePool.*|Cluster)$' "$f"
echo "--- control plane / worker sections (indented names only):"
sed -n '100,115p;225,250p' "$f" | grep -E '^ +[a-zA-Z]+:|^ +- ' | grep -v -i -E 'password|token|key|secret'
echo "--- pod/service CIDR lines:"
grep -n -E 'pod|service|clusterNetwork|cidr' "$f" | head -12
