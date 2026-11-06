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

# When
cv_step When "sign in once without email and once without password" $LINENO
cv_http POST /auth/login "$(jq -nc --arg p "$PASSWORD" '{password:$p}')"
NO_EMAIL_STATUS="$CV_HTTP_STATUS"; NO_EMAIL_BODY="$CV_HTTP_BODY"
cv_http POST /auth/login "$(jq -nc --arg e "$EMAIL" '{email:$e}')"
NO_PW_STATUS="$CV_HTTP_STATUS"; NO_PW_BODY="$CV_HTTP_BODY"

# Then
cv_step Then "neither attempt is accepted or returns a token" $LINENO
[ "$NO_EMAIL_STATUS" = "400" ] || cv_fail "expected 400 for missing email got $NO_EMAIL_STATUS" $LINENO
[ "$NO_PW_STATUS" = "400" ] || cv_fail "expected 400 for missing password got $NO_PW_STATUS" $LINENO
T1=$(printf '%s' "$NO_EMAIL_BODY" | jq -r '.token // empty')
[ -z "$T1" ] || cv_fail "expected no token for missing email got one" $LINENO
T2=$(printf '%s' "$NO_PW_BODY" | jq -r '.token // empty')
[ -z "$T2" ] || cv_fail "expected no token for missing password got one" $LINENO

# Cleanup
cv_step Cleanup "in-memory store has no delete routes; nothing to remove" $LINENO
echo "account $EMAIL remains in memory"

echo "CODEVALID_TEST_ASSERTION_OK:api_38744878_2"
