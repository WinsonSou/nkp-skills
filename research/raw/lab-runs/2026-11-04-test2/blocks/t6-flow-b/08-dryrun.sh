# CHANGES  (writes the dry-run objects to ~/skilltest-flow-b-dryrun.yaml on the operator host; creates no VMs)
source ~/nkp-skilltest-flow-b.env 2>/dev/null
cd "$HOME" || exit 1
umask 077 && bash "$HOME/nkp-$CLUSTER_NAME-create.sh" --dry-run --output yaml > "$HOME/$CLUSTER_NAME-dryrun.yaml"
echo "RC=$?"
ls -l "$HOME/$CLUSTER_NAME-dryrun.yaml" | awk '{print "bytes="$5, "mode="$1}'
echo "== kinds =="
grep -E '^kind:' "$HOME/$CLUSTER_NAME-dryrun.yaml" | sort | uniq -c
echo "== key lines =="
grep -n -E '^kind:|^  name:|image:|host:|addressRanges:|start:|end:|url:|replicas:|vcpuSockets:|memorySize:|systemDiskSize:|servers:|insecure:' "$HOME/$CLUSTER_NAME-dryrun.yaml" | head -30
echo "== cni block as the CLI made it =="
yq 'select(.kind == "NKPCluster" or .kind == "Cluster") | (.spec.capiCluster.topology // .spec.topology).variables[] | select(.name == "clusterConfig") | .value.addons.cni' "$HOME/$CLUSTER_NAME-dryrun.yaml" 2>&1
