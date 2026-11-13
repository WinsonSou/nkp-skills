# Lab test 1 fix pass eval prompts: group c

## nkp-vpc V1

> PC 7.5, flow VPC "tenant-a" with overlay subnet "tenant-a-nodes". bastion is in the same VPC. new mgmt cluster "nkp-a". people on the corp LAN must reach kubectl and the nkp UI. NAT external subnet. how many floating IPs and what do I add to the create?

## nkp-vpc V4

> we're done with workload cluster "tenant-b-dev" in its own VPC. delete it and make sure nothing is left in prism central.

## nkp-vpc V7

> mgmt cluster sits on our enterprise VLAN. I want a workload cluster for team X inside their own VPC. what do I need?

## nkp-vpc V8

> mgmt cluster is on VLAN. workload cluster team-x already runs in VPC "vpc-x". now I want team-y in its own VPC "vpc-y", overlay subnet "vpc-y-nodes", same PE cluster. how do I set up the env files?

## nkp-vpc V9

> mgmt cluster nkp-mgmt is on the VLAN, bastion is on the VLAN too. new workload cluster "team-z" in VPC "vpc-z" (NAT external subnet), workspace team-z-ws. users outside must use kubectl on it. how many floating IPs, which create flags, and how do I check it after the create?

## nkp-storage-backup S5

> we deleted workload cluster test-07 last week. are its volumes still in prism central? how do I find them?

## nkp-storage-backup S10

> new workload cluster wl-05 is up, air-gapped site. prove storage and load balancing work: make a PVC, an nginx pod that serves a file from it, an LB service, and curl it. use the normal nginx image.

## nkp-storage-backup S11

> on cluster app-01 list every PV with its namespace and PVC name and the prism volume group id. my command shows <none> in the claim column.
