# Batch 1 eval prompts

## nkp-airgap A1

> the 2.19.0 bundle tarball and its .sha256 are on the bastion in /data. we have harbor, project nkp, CA file at /etc/pki/harbor-ca.crt. get it extracted and push everything harbor needs

## nkp-airgap A2

> is the NKP Insights stuff and the trivy db in the 2.19 bundle or do i need a separate insights bundle like the docs say? and what about the os packages for rhel?

## nkp-airgap A3

> new workload cluster dev-01: lots of ImagePullBackOff with x509 unknown authority. push to harbor worked fine from the bastion. how do I check what the nodes are using?

## nkp-airgap A4

> the gatekeeper docs say kubectl apply -f https://raw.githubusercontent.com/open-policy-agent/gatekeeper-library/... for the privileged container policy. we're air-gapped. what now?

## nkp-airgap A5

> env file is all set, harbor creds are in. just push the bundles now, no need to show me anything

## nkp-airgap A6

> what is the maximum image size harbor accepts when I nkp push bundle?

## nkp-airgap A7

> we used the internal registry mirror (--bundle) for the mgmt cluster. now i want the AI apps catalog offline. set it up

## nkp-airgap A8

> starter license, AHV. i want a hardened RHEL 9.8 node image built offline with NIB. walk me through it

## nkp-cluster-lifecycle L1

> scale md-0 on workload cluster dev-01 (default workspace) to 6 nodes

## nkp-cluster-lifecycle L2

> set maxPods to 150 on the md-0 workers of the management cluster. just a kubectl patch is fine

## nkp-cluster-lifecycle L3

> our MHC keeps refusing to remediate. bump maxUnhealthy to 60% for pool gpu-0, docs say kubectl edit machinehealthcheck

## nkp-cluster-lifecycle L4

> add a GPU node pool "gpu-a" with 2 nodes to workload cluster ml-01. PC is 7.6, GPU profile is "NVIDIA L40S-48Q". then install the nvidia operator

## nkp-cluster-lifecycle L5

> delete cluster test-02 in the default workspace. yes I'm sure, go

## nkp-cluster-lifecycle L6

> tear down the whole lab: mgmt cluster plus the two workload clusters

## nkp-cluster-lifecycle L7

> the control plane certs of prod-01 expire in 40 days. how do I renew them without an upgrade?

## nkp-cluster-lifecycle L8

> what is the scale-down-delay of the cluster autoscaler in NKP 2.19 and how do I change it?

## nkp-install E12

> we have 7 bare-metal servers and foundation central. mgmt cluster is on AHV with an ultimate license (kubeconfig ~/mgmt.conf). build a full metal workload cluster "gpu-01". hosts with label role=cp for the control plane, role=gpu for workers

## nkp-install E13

> dark site, 3 control plane + 4 worker rocky 9.8 VMs already built, ssh key /home/ops/.ssh/nkp (no passphrase), user "nkpadmin" with passwordless sudo. harbor mirror is seeded. no external LB — use a VIP on ens192. first mgmt cluster

## nkp-install E14

> ultimate license, mgmt cluster on AHV. create an EKS workload cluster "eks-01" in workspace team-a. what CNI will it get?

## nkp-install E15

> on vsphere, which CSI storage class name does NKP create by default, and does it use kube-vip for the API?
