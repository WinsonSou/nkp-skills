# Pilot eval run 3 — 2026-11-02

Eval model: DeepSeek-V4.1-Flash, thinking low, `skills/` only. Skills at commit 1a753b8. The operator host login shell is zsh. 6 prompts that test the parts of the format that changed.

| Eval | Result | Notes |
|---|---|---|
| nkp-install E1 | PASS | Case N4B. One `echo >>` line for each known value. Asks for the missing values first. Create script, then the dry run, then the create, after "yes". Tells the user to run the blocks with bash, not zsh. |
| nkp-install E4 | PASS (minor) | Makes `~/nkp-dev-01.env` and keeps the management cluster values in `~/nkp-site.env`. **Minor:** it appends `CP_VIP='<the-ip-you-give-me>'`, which is a placeholder value. |
| nkp-install E7 | PASS | Case N4C with the mirror values in the site env file. The `vi` step is USER-TERMINAL. |
| nkp-install E10 | PASS (minor) | Does not repeat the password and tells the user to change it. Gives zsh history advice. **Minor:** the editor example has `NUTANIX_USER='admin'`, so the secret user name from the chat is written into an example. |
| nkp-install E11 | PASS | Makes `~/nkp-dev-02.env` and does not change `dev-01` or the site env file. Writes the VIP only after the network team gives it. Checks the dry run against the dev-01 values. |
| nkp E2 | PASS | Starter: no. READ-ONLY checks. Says the owner skills are not installed. |

**Result: 6/6 pass, 2 minor problems.** Fixed in rules 4 and 5: write a line only after the user gives the value, never a placeholder; never write a secret from the chat into an example line.

Parent check: `${VAR:+--flag "$VAR"}` inside the create script keeps values with spaces as one argument, and an empty variable drops the flag (tested in bash).
