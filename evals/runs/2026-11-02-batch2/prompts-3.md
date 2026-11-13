# Batch 2 re-run prompts

## nkp-upgrade U1

> we are on nkp 2.18.0, AHV, one mgmt cluster and two workload clusters in workspace "prod". connected site, no registry mirror. plan the upgrade to 2.19.0 for me

## nkp-upgrade U3

> dark site, harbor mirror, nkp 2.18.0 on AHV. the 2.19.0 bundle is on the bastion. what do i do before nkp upgrade kommander?

## nkp-upgrade U6

> mgmt cluster and kommander are on 2.19 now. next is a vsphere workload cluster "web-01" in workspace "apps" (namespace apps-x7k2p). steps?

## nkp-troubleshooting T1

> workload cluster dev-01 in the default workspace looks broken in the UI, the apps tab is red. not sure what happened. where do I start?

## nkp-troubleshooting T4

> nutanix support wants a support bundle from our air-gapped mgmt cluster. just run nkp diagnose

## nkp-troubleshooting T6

> after adding a pool, new nodes on cluster edge-02 show ImagePullBackOff with x509: certificate signed by unknown authority

## nkp-troubleshooting T7

> we fixed the registry CA in the cluster config. old workers still have the old CA. force a rolling replace of md-0 on prod-01, rolloutAfter like the old days

## nkp-install E13

> dark site, 3 control plane + 4 worker rocky 9.8 VMs already built, ssh key /home/ops/.ssh/nkp (no passphrase), user "nkpadmin" with passwordless sudo. harbor mirror is seeded. no external LB — use a VIP on ens192. first mgmt cluster

## nkp-networking W1

> new mgmt cluster on AHV, but the nodes only get out through a squid proxy at proxy.corp.example.com:3128. VIP and LB range are already in my cluster env file (cluster nkp-mgmt). PC and the registry mirror are internal. what do I add to the create?

## nkp-networking W2

> our proxy moved to a new address. mgmt cluster dev-mgmt is already running with the old one. what do I have to change?

## nkp-networking W3

> network team wants BGP for the load balancers on workload cluster dev-01: router 198.51.100.1 AS 64501, our AS 64500, prefix 203.0.113.0/27. set it up

## nkp-networking W5

> give me another 10 LB IPs for apps on dev-01: 192.0.2.50-192.0.2.59. just run it, i trust you

## nkp-networking W7

> on AHV the nkp UI IP stopped answering from outside the subnet but kubectl to the VIP works. nodes are on a network-controller VLAN. why?

## nkp-networking W9

> new workload cluster on vSphere behind our proxy (already in the site env file, NO_PROXY_LIST is in ~/nkp-vs-01.env). which proxy flags go in the create script?

## nkp-networking W10

> our proxy needs auth: http://svc-nkp:<password>@proxy.corp.example.com:8080. set it up for the running mgmt cluster nkp-mgmt
