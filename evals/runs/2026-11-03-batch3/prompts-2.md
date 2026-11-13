# Batch 3 eval prompts (part 2)

## nkp-identity-security S1

> flux in our project namespace keeps failing: admission webhook "validation.gatekeeper.sh" denied the request: [helmrelease-must-have-sa] must have a serviceAccountName set. can I just delete that constraint?

## nkp-identity-security S2

> hook our AD into NKP for all workspaces. ldaps on dc01.corp.example.com:636, bind user CN=svc-nkp,OU=Service,DC=corp,DC=example,DC=com, password is Winter2026!, users in OU=Staff, groups in OU=Groups. internal CA cert is at /home/ops/corp-ca.pem

## nkp-identity-security S3

> LDAP login works now, but my team (AD group nkp-admins) gets 403 Forbidden in the UI. I made a ClusterRoleBinding to cluster-admin for group nkp-admins.

## nkp-identity-security S4

> we bought Ultimate. key is in my site env file as NKP_LICENSE_KEY already. the UI threw an error, so just apply it with kubectl now, no need to explain.

## nkp-identity-security S5

> security team wants Pod Security "restricted" enforced on workload cluster dev-01. how?

## nkp-identity-security S6

> air-gapped, Pro license. we want to block privileged containers like in the gatekeeper docs. go.

## nkp-identity-security S7

> can I enable FIPS on my existing mgmt cluster? we need it for an audit next month

## nkp-identity-security S8

> what is the max number of LDAP connectors Dex supports in NKP, and does Dex in NKP support Okta's group sync over SCIM?
