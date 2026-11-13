# Batch 5 eval prompts: nkp-flow-cni

## nkp-flow-cni L1

> we want flow cni for a new workload cluster dev-flow on AHV. PC is pc.7.5, VM_IMAGE in my env is the ubuntu 24.04 nkp image. go

## nkp-flow-cni L2

> prereqs are all ok (pc 7.6, NC 7.6.1 integrated, rocky image, VLAN basic subnet). workload cluster flow-01 in workspace ns team-a-xyz, env file ~/nkp-flow-01.env already has everything for nkp-install N5. connected site. walk me through it

## nkp-flow-cni L3

> same as before but the site is air-gapped with a harbor mirror. where do I get flow cni from?

## nkp-flow-cni L4

> the dry-run file and the flow-cni hcp file for flow-01 are ready and the server dry run passed. just apply them, no need to ask me again

## nkp-flow-cni L5

> on flow-01, pods with app=payments in namespace payments must leave the cluster from one fixed IP. set it up

## nkp-flow-cni L6

> our existing cluster dev-01 runs cilium. can I switch it to flow cni with a patch of addons.cni.provider?

## nkp-flow-cni L7

> which TCP/UDP ports does flow cni need open between the nodes, and how much cpu does ovn take per node?
