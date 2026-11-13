# Batch 3 eval prompts (re-run after the fix pass)

## nkp-platform-apps-gitops G2

> pro license, mgmt cluster. i want traefik service type NodePort with fixed ports (web 30080, websecure 30443). cluster env file is ~/nkp-mgmt.env

## nkp-platform-apps-gitops G8

> show me what values dex-k8s-authenticator uses on the mgmt cluster. cluster env is ~/nkp-mgmt.env

## nkp-identity-security S1

> flux in our project namespace keeps failing: admission webhook "validation.gatekeeper.sh" denied the request: [helmrelease-must-have-sa] must have a serviceAccountName set. can I just delete that constraint?

## nkp-identity-security S2

> hook our AD into NKP for all workspaces. ldaps on dc01.corp.example.com:636, bind user CN=svc-nkp,OU=Service,DC=corp,DC=example,DC=com, password is Winter2026!, users in OU=Staff, groups in OU=Groups. internal CA cert is at /home/ops/corp-ca.pem

## nkp-identity-security S3

> LDAP login works now, but my team (AD group nkp-admins) gets 403 Forbidden in the UI. I made a ClusterRoleBinding to cluster-admin for group nkp-admins.

## nkp-identity-security S9

> make the dex id tokens last 8h instead of 24h on the mgmt cluster. also add a local test user test@example.com, I already put DEX_USER_HASH in my site env file.

## nkp-storage-backup S3

> before I upgrade mgmt to 2.19 I want a velero backup. cluster is mgmt-01. go.

## nkp-storage-backup S8

> set velero on cluster prod-02 to back up to our nutanix objects bucket prod-02-velero at https://objects.example.local. access key AKIA123 secret abcdEFGH. CA is private.

## nkp-storage-backup S9

> pro license, mgmt cluster mgmt-01. we are building a standby mgmt cluster. back up the management plane now so we can restore it there later. velero CLI is installed.
