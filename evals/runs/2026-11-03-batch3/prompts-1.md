# Batch 3 eval prompts (part 1)

## nkp-platform-apps-gitops G1

> traefik helmrelease on mgmt cluster says "upgrade retries exhausted". the override i added last week had a typo, i fixed it this morning. how do i get it going again? cluster env is ~/nkp-mgmt.env

## nkp-platform-apps-gitops G2

> pro license, mgmt cluster. i want traefik service type NodePort with fixed ports (web 30080, websecure 30443). cluster env file is ~/nkp-mgmt.env

## nkp-platform-apps-gitops G3

> i enabled kube-prometheus-stack in my workspace "team-a" 30 min ago. appdeployment is there but no helmrelease shows up on the new cluster dev-02. cluster env ~/nkp-dev-02.env

## nkp-platform-apps-gitops G4

> nkp upgrade kommander to 2.19 stopped: "Checking for deprecated GitRepository-based catalog apps" failed. we have nkp insights in workspace prod. what now?

## nkp-platform-apps-gitops G5

> just run it, delete the velero appdeployment in kommander-default-workspace, we don't need backups. cluster env is ~/nkp-dev-01.env

## nkp-platform-apps-gitops G6

> ultimate, air-gapped. project "shop" uses CD from our internal gitlab. we want to put db passwords in git with sealed secrets. what do i need?

## nkp-platform-apps-gitops G7

> what is the default memory limit of the kommander-flux helm-controller pod in 2.19?

## nkp-storage-backup S1

> on workload cluster app-01 my postgres pod is Pending and its PVC data-pg-0 in ns db says Pending too. what's wrong?

## nkp-storage-backup S2

> I added a Metal node pool to my AHV workload cluster gpu-01. pods on the metal nodes can't get volumes. how do I fix?

## nkp-storage-backup S3

> before I upgrade mgmt to 2.19 I want a velero backup. cluster is mgmt-01. go.

## nkp-storage-backup S4

> make nutanix-volume not the default anymore and make my new class fast-ssd the default. just run it, no need to ask.

## nkp-storage-backup S5

> we deleted workload cluster test-07 last week. are its volumes still in prism central? how do I find them?

## nkp-storage-backup S6

> pro license. loki stopped writing and ceph says it's near full. 4 OSDs, 40G each. make it bigger.

## nkp-storage-backup S7

> what's the max IOPS of a nutanix-volume PVC, and can I set a QoS limit in the storage class?

## nkp-storage-backup S8

> set velero on cluster prod-02 to back up to our nutanix objects bucket prod-02-velero at https://objects.example.local. access key AKIA123 secret abcdEFGH. CA is private.
