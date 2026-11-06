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
cv_step Given "a registered customer and the current catalog size" $LINENO
register_user "$EMAIL" "$PASSWORD"
product_count; BEFORE="$PRODUCT_COUNT"

# When
cv_step When "attacker signs in with the registered email and a guessed password" $LINENO
cv_http POST /auth/login "$(jq -nc --arg e "$EMAIL" '{email:$e,password:"Guessed-Wrong-Pass1"}')"
LOGIN_STATUS="$CV_HTTP_STATUS"; LOGIN_BODY="$CV_HTTP_BODY"

# Then
cv_step Then "no token is granted and a catalog change stays blocked" $LINENO
[ "$LOGIN_STATUS" != "200" ] && [ "$LOGIN_STATUS" != "201" ] || cv_fail "expected wrong password to be refused got $LOGIN_STATUS" $LINENO
[ "$LOGIN_STATUS" = "401" ] || cv_fail "expected 401 for wrong password got $LOGIN_STATUS" $LINENO
TOKEN=$(printf '%s' "$LOGIN_BODY" | jq -r '.token // empty')
[ -z "$TOKEN" ] || cv_fail "expected no token for wrong password got one" $LINENO
UID_LEAK=$(printf '%s' "$LOGIN_BODY" | jq -r '.user.id // empty')
[ -z "$UID_LEAK" ] || cv_fail "expected no user data for wrong password got user.id" $LINENO
cv_http POST /products "$(jq -nc --arg n "Attacker-$SUFFIX" '{name:$n,price:1}')" -H "Authorization: Bearer ${TOKEN:-none}"
[ "$CV_HTTP_STATUS" != "201" ] || cv_fail "expected catalog change refused got 201" $LINENO
product_count
printf '%s' "$CV_HTTP_BODY" | jq -e --arg n "Attacker-$SUFFIX" '[.products[]|select(.name==$n)]|length==0' >/dev/null || cv_fail "expected no product Attacker-$SUFFIX in catalog but it was created" $LINENO

# Cleanup
cv_step Cleanup "in-memory store has no delete routes; nothing to remove" $LINENO
echo "account $EMAIL remains in memory"

echo "CODEVALID_TEST_ASSERTION_OK:api_38744878_3"
