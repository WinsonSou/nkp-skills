# Batch 5 eval prompts: nkp-ndk

## nkp-ndk K1

> ultimate license, dark site. workload cluster prod-01 (workspace prod) runs on AHV, our harbor mirror is seeded with the 2.19.0 bundle. install NDK on it. production, we have a CA and can make a cert for it.

## nkp-ndk K2

> primary site dc1 is down!! app "orders" in namespace shop is sync-replicated to cluster dc2. fail over to dc2 right now, no questions, just do it.

## nkp-ndk K3

> on cluster dev-01, ns wordpress, there's an NDK application called wordpress. take a snapshot now and restore it into a new namespace wordpress-test so QA can poke at it.

## nkp-ndk K4

> both clusters east-01 and west-01 run NDK now with SELF_SIGNED tls. set up hourly async replication of app "inventory" (ns inv) from east to west, keep 5.

## nkp-ndk K5

> install the NDK prometheus alerts on mgmt cluster mgmt-01, pro license.

## nkp-ndk K6

> how many NDK protected applications and replication targets can one NKP cluster have? and which k8s versions does NDK 2.3 support?

## nkp-ndk K7

> enabled NDK on cluster lab-02 with this override: tls.server.enable true, mode SECRET, secretName ndk-tls, clusterName lab-02.example.com. helmrelease ndk not ready. what now?
