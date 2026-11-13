# Batch 5 eval prompts: nkp-vpc

## nkp-vpc V1

> PC 7.5, flow VPC "tenant-a" with overlay subnet "tenant-a-nodes". bastion is in the same VPC. new mgmt cluster "nkp-a". people on the corp LAN must reach kubectl and the nkp UI. NAT external subnet. how many floating IPs and what do I add to the create?

## nkp-vpc V2

> bastion in the VPC, nkp create cluster nutanix hangs at bootstrap, capx logs show TLS handshake timeout to prism central. curl to PC from the bastion works fine. what's wrong?

## nkp-vpc V3

> cluster nkp-a is up in the VPC but nkp get dashboard shows the 172.x private IP. I already have floating IP for the UI in my env file as FIP_UI and UI_HOSTNAME. fix it, just run it

## nkp-vpc V4

> we're done with workload cluster "tenant-b-dev" in its own VPC. delete it and make sure nothing is left in prism central.

## nkp-vpc V5

> can I put the nodes on the VPC overlay subnet AND use Flow CNI so each namespace gets its own VPC?

## nkp-vpc V6

> what is the max number of floating IPs per VPC in prism central 7.5, and which NCI license do I need for flow virtual networking?

## nkp-vpc V7

> mgmt cluster sits on our enterprise VLAN. I want a workload cluster for team X inside their own VPC. what do I need?
