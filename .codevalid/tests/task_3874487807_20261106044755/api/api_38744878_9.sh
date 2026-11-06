#!/usr/bin/env bash
set -euo pipefail
source "${CODEVALID_ROOT:-.}/.codevalid/lib/cv.sh"
BASE_URL="${BASE_URL:-http://app:6713}"
SUFFIX="$(date +%s%N)"
EMAIL="signin.${SUFFIX}@example.com"
PASSWORD="Str0ngPass-${SUFFIX}"
register_user() {
  cv_prereq "register $1" $LINENO
  cv_http POST /auth/register "$(jq -nc --arg e "$1" --arg p "$2" '{email:$e,password:$p,name:"Sign In Customer"}')"
  [ "$CV_HTTP_STATUS" = "201" ] || cv_fail "expected register 201 got $CV_HTTP_STATUS" $LINENO
}
product_count() {
  cv_http GET /products "" 200
  PRODUCT_COUNT=$(printf "%s" "$CV_HTTP_BODY" | jq -r ".products | length")
}

b64url() { printf '%s' "$1" | base64 | tr -d '=\n' | tr '/+' '_-'; }
# Given
cv_step Given "a genuine user id plus forged tokens built without signing in" $LINENO
register_user "$EMAIL" "$PASSWORD"
REAL=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.token')
UIDV=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.user.id')
HDR_NONE=$(b64url '{"alg":"none","typ":"JWT"}')
HDR_HS=$(b64url '{"alg":"HS256","typ":"JWT"}')
PAY=$(b64url "$(jq -nc --arg s "$UIDV" --arg e "$EMAIL" '{sub:$s,email:$e,iat:1700000000,exp:4102444800}')")
FORGED_NONE="$HDR_NONE.$PAY."
FORGED_SIG="$HDR_HS.$PAY.$(b64url 'made-up-signature-bytes')"
REAL_SIG=$(printf '%s' "$REAL" | cut -d. -f3)
ALTERED="$HDR_HS.$PAY.$REAL_SIG"
MADEUP="not-a-real-token-$SUFFIX"
NAME="Forged-Item-$SUFFIX"
BODY=$(jq -nc --arg n "$NAME" '{name:$n,price:9}')

# When
cv_step When "the client attempts catalog changes with forged or altered tokens" $LINENO
STATUSES=""
for T in "$FORGED_NONE" "$FORGED_SIG" "$ALTERED" "$MADEUP"; do
  cv_http POST /products "$BODY" -H "Authorization: Bearer $T"
  STATUSES="$STATUSES $CV_HTTP_STATUS"
done

# Then
cv_step Then "every attempt is refused and the catalog has no forged product" $LINENO
for S in $STATUSES; do
  [ "$S" = "401" ] || [ "$S" = "403" ] || cv_fail "expected forged token refused (401/403) got $S (all: $STATUSES)" $LINENO
done
cv_http GET /products "" 200
printf '%s' "$CV_HTTP_BODY" | jq -e --arg n "$NAME" '[.products[]|select(.name==$n)]|length==0' >/dev/null || cv_fail "expected no product $NAME in catalog but forged token created it" $LINENO

# Cleanup
cv_step Cleanup "in-memory store has no delete routes; nothing to remove" $LINENO
echo "account $EMAIL remains in memory"

echo "CODEVALID_TEST_ASSERTION_OK:api_38744878_9"
