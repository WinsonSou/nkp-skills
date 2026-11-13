# READ-ONLY
source ~/nkp-site.env 2>/dev/null
h="${REGISTRY_URL#*://}"; h="${h%%/*}"
openssl s_client -connect "$h:443" -servername "$h" </dev/null 2>/dev/null | openssl x509 -noout -subject -ext subjectAltName 2>/dev/null | head -5
