# Skill cut: router + task and domain skills, one owner skill per fact

The target is a small local model with about 32k tokens of context. Each skill description is always in context, and each copied fact drifts at refresh. We use 16 skills: the router `nkp`, one `nkp-install` with one reference file per provider (not one skill per provider), and 14 task and domain skills (airgap, cluster-lifecycle, upgrade, troubleshooting, networking, platform-apps-gitops, identity-security, storage-backup, observability, gpu-ai, flow-cni, vpc, ndk, kubernetes-core). Each fact has one owner skill. Other skills point to it ("For X, use skill nkp-Y").

## Considered options

- 16 component skills as in map §8: upgrade and troubleshooting jump across too many skills.
- About 6 big task skills: bodies too large for a 32k window.
- Copying small facts into each skill: fewer hops, but the copies drift at every NKP release.

## Consequences

- Fixed owners: NDK → nkp-ndk. Bundle, registry, and seeding → nkp-airgap (air-gap steps for one app → that app's skill). Failure fixes → the domain skill (nkp-troubleshooting owns the debug ladder, `nkp diagnose`, and the symptom → skill index). Upgrade gates → nkp-upgrade.
- Size limits: SKILL.md ≤ ~250 lines, each reference file ≤ ~400 lines.
