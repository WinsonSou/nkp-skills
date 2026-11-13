# Lab test 1 fix pass eval prompts: group a

## nkp-install E2

> starter license, small lab, i want the smallest mgmt cluster possible. ubuntu 24.04 image ok? can i do just 1 control plane node?

## nkp-install E5

> create finished on AHV. do i still need to run nkp install kommander?

## nkp-install E16

> workload cluster dev-01 create finished, last line was "✓ Waiting for machines to be ready" and nothing else, no .conf file. did it fail? how do i check it's healthy

## nkp-install E17

> network team says .50 and .51-.55 are free but they always say that. subnet is a plain vlan with ipam. can you prove they're free before the mgmt create?

## nkp-install E18

> ultimate trial key from the portal, first mgmt cluster on AHV. call it skilltest-mgmt-01. we'll apply the license after

## kubernetes-core K9

> cluster app-01: I wrote ~/demo.yaml with a Namespace demo, a PVC and a Deployment in it. the server dry run says 'namespaces "demo" not found' for the PVC and the Deployment. is my file wrong? then apply it.

## kubernetes-core K10

> on app-01 I ran `kubectl diff -f web.yaml | head -50; echo rc=$?` and it printed rc=0 but there was an error line. so no changes?

## nkp-airgap A8

> starter license, AHV. i want a hardened RHEL 9.8 node image built offline with NIB. walk me through it

## nkp-airgap A9

> air-gapped site, harbor mirror is in REGISTRY_URL. i want a quick nginx pod with a PVC to test the new cluster. which image do i put in the yaml?

## nkp-airgap A10

> can you just list everything that is in our harbor mirror?
