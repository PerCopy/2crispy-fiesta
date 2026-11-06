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

# Given
cv_step Given "a registered customer account" $LINENO
register_user "$EMAIL" "$PASSWORD"
REG_ID=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.user.id // empty')
[ -n "$REG_ID" ] || cv_fail "expected user.id from register got none" $LINENO

# When
cv_step When "sign in with the registered email and matching password" $LINENO
cv_http POST /auth/login "$(jq -nc --arg e "$EMAIL" --arg p "$PASSWORD" '{email:$e,password:$p}')"

# Then
cv_step Then "sign-in succeeds with a token that grants signed-in access" $LINENO
[ "$CV_HTTP_STATUS" = "200" ] || cv_fail "expected login 200 got $CV_HTTP_STATUS" $LINENO
TOKEN=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.token // empty')
[ -n "$TOKEN" ] || cv_fail "expected a token in login response got none" $LINENO
LID=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.user.id // empty')
[ "$LID" = "$REG_ID" ] || cv_fail "expected login user.id $REG_ID got '$LID'" $LINENO
LEMAIL=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.user.email // empty')
[ "$LEMAIL" = "$EMAIL" ] || cv_fail "expected login user.email $EMAIL got '$LEMAIL'" $LINENO
cv_http POST /products "$(jq -nc --arg n "SignedIn-$SUFFIX" '{name:$n,price:1}')" -H "Authorization: Bearer $TOKEN"
[ "$CV_HTTP_STATUS" = "201" ] || cv_fail "expected signed-in token to allow catalog change (201) got $CV_HTTP_STATUS" $LINENO

# Cleanup
cv_step Cleanup "in-memory store has no delete routes; nothing to remove" $LINENO
echo "account $EMAIL and product SignedIn-$SUFFIX remain in memory"

echo "CODEVALID_TEST_ASSERTION_OK:api_38744878_1"
