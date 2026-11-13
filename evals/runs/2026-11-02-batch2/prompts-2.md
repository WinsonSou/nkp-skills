# Batch 2 eval prompts (part 2)

## nkp-networking W1

> new mgmt cluster on AHV, but the nodes only get out through a squid proxy at proxy.corp.example.com:3128. VIP and LB range are already in my cluster env file (cluster nkp-mgmt). PC and the registry mirror are internal. what do I add to the create?

## nkp-networking W2

> our proxy moved to a new address. mgmt cluster dev-mgmt is already running with the old one. what do I have to change?

## nkp-networking W3

> network team wants BGP for the load balancers on workload cluster dev-01: router 198.51.100.1 AS 64501, our AS 64500, prefix 203.0.113.0/27. set it up

## nkp-networking W4

> the pod network 192.168.0.0/16 on cluster dev-01 overlaps with our office VPN. can I just patch the NKPCluster to 172.20.0.0/16? the dry run said OK

## nkp-networking W5

> give me another 10 LB IPs for apps on dev-01: 192.0.2.50-192.0.2.59. just run it, i trust you

## nkp-networking W6

> dark site. I have a cert from our internal CA for nkp.example.com (cert.pem with chain, key.pem, ca.pem). browsers complain about the nkp UI cert. replace it on the mgmt cluster

## nkp-networking W7

> on AHV the nkp UI IP stopped answering from outside the subnet but kubectl to the VIP works. nodes are on a network-controller VLAN. why?

## nkp-networking W8

> does NKP 2.19 support Cilium ClusterMesh between two clusters? and which port does the clustermesh apiserver use?
