#!/usr/bin/env bash
set -euo pipefail
source "${CODEVALID_ROOT:-.}/.codevalid/lib/cv.sh"
BASE_URL="${BASE_URL:-http://app:6713}"
SUFFIX="$(date +%s%N)"
EMAIL="kept.${SUFFIX}@example.com"
PASSWORD="KeptPass-${SUFFIX}"

# Given
cv_step Given "a customer registered an account and the service keeps running" $LINENO
BODY=$(jq -nc --arg e "$EMAIL" --arg p "$PASSWORD" '{email:$e,password:$p}')
cv_http POST /auth/register "$BODY"
[ "$CV_HTTP_STATUS" = "201" ] || cv_fail "expected 201 registering the account got $CV_HTTP_STATUS" $LINENO
ORIG_ID=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.user.id // empty')
[ -n "$ORIG_ID" ] || cv_fail "expected user.id got none" $LINENO
sleep 2

# When
cv_step When "a later registration with the same email" $LINENO
cv_http POST /auth/register "$(jq -nc --arg e "$EMAIL" --arg p "Later-${SUFFIX}" '{email:$e,password:$p}')"
LATER_STATUS="$CV_HTTP_STATUS"

# Then
cv_step Then "the later registration is refused and the account is still held" $LINENO
[ "$LATER_STATUS" = "409" ] || cv_fail "expected HTTP 409 for the later registration got $LATER_STATUS" $LINENO
cv_http POST /auth/login "$BODY"
[ "$CV_HTTP_STATUS" = "200" ] || cv_fail "expected the held account to log in (200) got $CV_HTTP_STATUS" $LINENO
LOGIN_ID=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.user.id // empty')
[ "$LOGIN_ID" = "$ORIG_ID" ] || cv_fail "expected held account id $ORIG_ID got '$LOGIN_ID'" $LINENO

# Cleanup
cv_step Cleanup "accounts are in-memory; the app exposes no delete route, nothing to remove" $LINENO
echo "unique email $EMAIL left in the in-memory store"

echo "CODEVALID_TEST_ASSERTION_OK:api_25798174_7"
