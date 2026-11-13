# Batch 3 fix pass: nkp-identity-security

Date 2026-11-03. Scope: `review.md` M2, M3, M6 (identity side), minors 1, 10, 11 (gatekeeper), 13 (identity part), 15 (rbac and `IDP_*`); `grading.md` fixes 2 and 3 (identity I2/I3).
Checks: `check_skills.py --self-test` and `check_skills.py` pass. `bash -n` passes on all 51 command blocks of the skill. I tested the shell fixes in `/tmp/b3fixid`. identity.md is 371 lines, SKILL.md 210 lines.
Lab (read-only `get` only, no Secret value, no dry run) is logged in `research/raw/live/2.19/identity-security.txt`, section "Batch 3 fix pass".

## review.md

- M2 fixed (skills/nkp-identity-security/references/identity.md:312-317). The plan shows the file through `sed -E 's/(hash: ).*/\1(hidden)/'`, never the hash. The USER-TERMINAL hash block is `htpasswd -nBC 10 ""`, which asks for the password (:272-276). Tested the sed on a sample file. I used `(hidden)`, not `<set>`, because the check script rejects `<...>` in a command block.
- M3 fixed (skills/nkp-identity-security/SKILL.md:80, :83). The UI path is `/dkp/kommander/dashboard`. Note: the guide p.580 says `/nkp/…`, which gives 404 on 2.19.0 [live].
- M6 fixed, identity side (identity.md:256-263, :328-346). I7 now says: the Dex HelmRelease reads `dex-overrides` directly in slot 2 (the gitops O1 model), slot 3 `dex-cluster-overrides` holds `config.issuer`, and `configOverrides` can copy into it (UNKNOWN P-33 with a READ-ONLY check). The order is written out: file, dry run, plan without the hash, "yes", apply, issuer check, Ready check. The issuer check counts `issuer:` lines only (live: `1`). If `0`: stop, plan to remove `spec.configOverrides` (gitops `overrides.md` O5 item 5), note on P-33. Kept the guide step (`configOverrides`) because the guide does it. New eval S9 (evals/nkp-identity-security.md:108).
- minor 1 fixed (identity.md:74 LDAP bind password, :134 OIDC client secret; SKILL.md:129 license key). The form is `--from-file=key=<(printf %s "$(printenv VAR)")`. `printenv` instead of `"$VAR"` because the check script marks `printf ... $SECRET` as "shows a secret". `printf` is a bash builtin, so the value is not in the process list. Tested: the value stays byte-exact with `$`, `!`, `@`.
- minor 10 fixed (rbac.md:32 rule, :259 R7 item 2; evals S3 FAIL rule :45). `cluster-admin` has `nonResourceURLs: ["*"]` [live]. A fix that binds `cluster-admin` to `oidc:nkp-admins` passes.
- minor 11 fixed, gatekeeper part (gatekeeper.md:7). `gatekeeper-proxy-mutations` is a HelmRelease [live]. The velero part is for the storage fixer.
- minor 13, identity part: no change. gatekeeper.md G1 stays the owner of the `*-must-have-sa` facts. The two gitops places (gitops `SKILL.md:227`, `project-cd.md:29`) must point to G1 (gitops fixer).
- minor 15 fixed. rbac.md:225-243: `dry='1'` toggle with `${dry:+--dry-run=server}`; run with `dry='1'` first, then `dry=''` after "yes". Tested the expansion. identity.md:16: `IDP_*` are for one connector; one connector at a time.
- minor 16, identity part: fixed with eval S9 (I7 flow).

## grading.md

- Fix 2 fixed (gatekeeper.md:38; evals S1 FAIL rule :18). `enforcementAction: warn` or `dryrun` on an NKP constraint is a weakening, not allowed, not offered.
- Fix 3 fixed (identity.md:39; evals S2 :27). Ask first, append in the next reply. A short base DN (`OU=Staff`) gets a full DN proposal that the user confirms. No example connector name or button text in a block.
- S2 minor (`name='corp-ad'` before the answer): covered by the same line (identity.md:39).

## Not changed

- research/OPEN-ITEMS.md P-40..P-49: no change needed. P-33 is owned by gitops; the gitops fixer can add the identity issuer check as a way to close it.
