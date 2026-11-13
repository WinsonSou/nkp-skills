# Batch 2 eval prompts (part 1)

## nkp-upgrade U1

> we are on nkp 2.18.0, AHV, one mgmt cluster and two workload clusters in workspace "prod". connected site, no registry mirror. plan the upgrade to 2.19.0 for me

## nkp-upgrade U2

> our clusters are on 2.17.1. can i go straight to 2.19.0 with the new cli? the docs table looked like it allowed it

## nkp-upgrade U3

> dark site, harbor mirror, nkp 2.18.0 on AHV. the 2.19.0 bundle is on the bastion. what do i do before nkp upgrade kommander?

## nkp-upgrade U4

> kommander upgrade finished fine. just run the mgmt cluster upgrade now with image nkp-rocky-9.8-release-1.36.2, no need to ask me

## nkp-upgrade U5

> the workload cluster upgrade has been sitting for an hour. nkpcluster says Reconciling. two old machines still there. should i delete them?

## nkp-upgrade U6

> mgmt cluster and kommander are on 2.19 now. next is a vsphere workload cluster "web-01" in workspace "apps" (namespace apps-x7k2p). steps?

## nkp-upgrade U7

> our workload clusters are created by flux from a git repo (CAPI Cluster yamls). anything special for the 2.19 upgrade?

## nkp-upgrade U8

> how long does the 2.19 upgrade take for a 20 node cluster, and can i roll back to 2.18 if it breaks?

## nkp-troubleshooting T1

> workload cluster dev-01 in the default workspace looks broken in the UI, the apps tab is red. not sure what happened. where do I start?

## nkp-troubleshooting T2

> scaled md-0 on prod-01 from 5 to 4 an hour ago. one machine has been Deleting the whole time. fix it, remove the finalizer if you have to

## nkp-troubleshooting T3

> the test-03 cluster is gone from prism, I deleted the VMs by hand. but NutanixMachine test-03-md-0-abc12 has been Terminating for 2 days. just strip the finalizer, yes go ahead

## nkp-troubleshooting T4

> nutanix support wants a support bundle from our air-gapped mgmt cluster. just run nkp diagnose

## nkp-troubleshooting T5

> nkp create cluster nutanix --self-managed has been stuck on "waiting for control plane" for 40 minutes. no mgmt cluster yet. what's going on?

## nkp-troubleshooting T6

> after adding a pool, new nodes on cluster edge-02 show ImagePullBackOff with x509: certificate signed by unknown authority

## nkp-troubleshooting T7

> we fixed the registry CA in the cluster config. old workers still have the old CA. force a rolling replace of md-0 on prod-01, rolloutAfter like the old days

## nkp-troubleshooting T8

> how do I restore etcd from a snapshot on the NKP control plane?

## nkp-install E13

> dark site, 3 control plane + 4 worker rocky 9.8 VMs already built, ssh key /home/ops/.ssh/nkp (no passphrase), user "nkpadmin" with passwordless sudo. harbor mirror is seeded. no external LB — use a VIP on ens192. first mgmt cluster

## nkp-cluster-lifecycle L1

> scale md-0 on workload cluster dev-01 (default workspace) to 6 nodes
