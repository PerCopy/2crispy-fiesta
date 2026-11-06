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
cv_step Given "an email address that was never registered" $LINENO
NEVER="never.registered.${SUFFIX}@example.com"
cv_prereq "registered account exists for comparison of error message" $LINENO
register_user "$EMAIL" "$PASSWORD"
cv_http POST /auth/login "$(jq -nc --arg e "$EMAIL" '{email:$e,password:"Wrong-Password-1"}')"
WRONG_PW_ERR=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.error // empty')

# When
cv_step When "sign in with the unregistered email and some password" $LINENO
cv_http POST /auth/login "$(jq -nc --arg e "$NEVER" '{email:$e,password:"AnyPassword-123"}')"

# Then
cv_step Then "the attempt is refused with no token and a generic error" $LINENO
[ "$CV_HTTP_STATUS" = "401" ] || cv_fail "expected 401 for unregistered email got $CV_HTTP_STATUS" $LINENO
TOKEN=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.token // empty')
[ -z "$TOKEN" ] || cv_fail "expected no token for unregistered email got one" $LINENO
ERR=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.error // empty')
[ "$ERR" = "$WRONG_PW_ERR" ] || cv_fail "expected same generic error as wrong password ('$WRONG_PW_ERR') got '$ERR'" $LINENO

# Cleanup
cv_step Cleanup "in-memory store has no delete routes; nothing to remove" $LINENO
echo "account $EMAIL remains in memory"

echo "CODEVALID_TEST_ASSERTION_OK:api_38744878_4"
