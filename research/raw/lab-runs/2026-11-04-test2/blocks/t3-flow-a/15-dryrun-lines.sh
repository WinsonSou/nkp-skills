# READ-ONLY  (anchored grep: the file holds Secrets)
source ~/nkp-skilltest-flow-a.env 2>/dev/null
f="$PWD/$CLUSTER_NAME-dryrun.yaml"
grep -n -E '^kind:|^  name:|^ +(image|host|url|insecure|replicas|vcpuSockets|memorySize|systemDiskSize|servers):|^ +- (start|end):|node-group-(min|max)-size|^ +class:' "$f"
