# READ-ONLY
source ~/nkp-nkp-mgmt-01.env 2>/dev/null
grep -n -E '^kind:|^  name:|image:|host:|addressRanges:|start:|end:|url:|replicas:|vcpuSockets:|memorySize:|systemDiskSize:|servers:|insecure:' ~/"$CLUSTER_NAME"-dryrun.yaml
