# The rules block is copied into every SKILL.md

A small model often loads one skill without the router, so a pointer to shared rules is not reliable. The shared rules (the CHANGES approval gate, UNKNOWN lines, placeholders, source tags) are therefore copied into the top of every SKILL.md. This is a deliberate duplication. The master copy is `skills/_shared/RULES.md`, and a check script fails when a copy does not match it. Edit only the master copy, then sync.
