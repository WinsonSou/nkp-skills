# READ-ONLY  (base64 is used by nkp-install N4C for the trust bundle; the rest are used by the skill blocks)
for c in base64 tr sort uniq head tee mktemp cut xargs find; do command -v "$c" >/dev/null && echo "found: $c" || echo "MISSING: $c"; done
