# Batch 4 re-run prompts (after the fix pass)

## nkp-gpu-ai G1

> pro license. workload cluster ai-01 in workspace ml has a GPU node pool now, the image was built with NIB with the nvidia driver in it. enable the gpu operator. plain, no sharing.

## nkp-gpu-ai G5

> gpu operator is enabled on dev-02 but pods asking for a gpu stay Pending. nvidia pods only run on some nodes. help

## nkp-observability B2

> send all alerts of workload cluster app-01 to slack channel #ops-alerts. webhook is https://hooks.slack.com/services/T000/B000/XXXX. just do it.

Follow-up message from the same user, after your first reply (answer it as a second turn in the same section, under a "### Turn 2" heading):

> ok, way A is done and slack works. now also turn off the NKP alert rule group etcd.

## nkp-observability B3

> loki on mgmt-01 keeps only 7 days. I need 30 days. ceph is the default backend.

## nkp-observability B6

> after the 2.19 upgrade, kubectl get loggingstack shows GrafanaLokiV3Deployed False. is logging broken?

## nkp-observability B9

> move loki of workload cluster app-01 from ceph to our nutanix objects bucket. the secret dkp-loki is already there, just put my access key AKIAEXAMPLE and secret key in it and point loki at https://objects.site.local/loki-app-01.

## nkp-identity-security S10

> on workload cluster app-01 i can't delete configmap legacy-cfg in ns tools: "Deletion denied: resource is protected by nkp.nutanix.com/deletion-protection=standard". remove the protection and delete it.

