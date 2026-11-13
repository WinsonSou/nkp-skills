# Batch 5 re-run prompts (r2)

## nkp-flow-cni L2

> prereqs are all ok (pc 7.6, NC 7.6.1 integrated, rocky image, VLAN basic subnet). workload cluster flow-01 in workspace ns team-a-xyz, env file ~/nkp-flow-01.env already has everything for nkp-install N5. connected site. walk me through it

## nkp-flow-cni L5

> on flow-01, pods with app=payments in namespace payments must leave the cluster from one fixed IP. set it up

## nkp-vpc V1

> PC 7.5, flow VPC "tenant-a" with overlay subnet "tenant-a-nodes". bastion is in the same VPC. new mgmt cluster "nkp-a". people on the corp LAN must reach kubectl and the nkp UI. NAT external subnet. how many floating IPs and what do I add to the create?

## nkp-vpc V2

> bastion in the VPC, nkp create cluster nutanix hangs at bootstrap, capx logs show TLS handshake timeout to prism central. curl to PC from the bastion works fine. what's wrong?

## nkp-vpc V3

> cluster nkp-a is up in the VPC but nkp get dashboard shows the 172.x private IP. I already have floating IP for the UI in my env file as FIP_UI and UI_HOSTNAME. fix it, just run it

## nkp-vpc V7

> mgmt cluster sits on our enterprise VLAN. I want a workload cluster for team X inside their own VPC. what do I need?

## nkp-vpc V8

> mgmt cluster is on VLAN. workload cluster team-x already runs in VPC "vpc-x". now I want team-y in its own VPC "vpc-y", overlay subnet "vpc-y-nodes", same PE cluster. how do I set up the env files?

## nkp-ndk K1

> ultimate license, dark site. workload cluster prod-01 (workspace prod) runs on AHV, our harbor mirror is seeded with the 2.19.0 bundle. install NDK on it. production, we have a CA and can make a cert for it.

## nkp-ndk K4

> both clusters east-01 and west-01 run NDK now with SELF_SIGNED tls. set up hourly async replication of app "inventory" (ns inv) from east to west, keep 5.

## nkp-ndk K5

> install the NDK prometheus alerts on mgmt cluster mgmt-01, pro license.

## nkp-ndk K6

> how many NDK protected applications and replication targets can one NKP cluster have? and which k8s versions does NDK 2.3 support?
