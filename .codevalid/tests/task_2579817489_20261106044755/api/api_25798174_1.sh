#!/usr/bin/env bash
set -euo pipefail
source "${CODEVALID_ROOT:-.}/.codevalid/lib/cv.sh"
BASE_URL="${BASE_URL:-http://app:6713}"
SUFFIX="$(date +%s%N)"
EMAIL="new.customer.${SUFFIX}@example.com"
PASSWORD="Str0ngPass-${SUFFIX}"

# Given
cv_step Given "a new email address not used by any account and a password" $LINENO
cv_prereq "email $EMAIL is unique per run" $LINENO
BODY=$(jq -nc --arg e "$EMAIL" --arg p "$PASSWORD" '{email:$e,password:$p}')

# When
cv_step When "register with the new email and password" $LINENO
cv_http POST /auth/register "$BODY"
REG_STATUS="$CV_HTTP_STATUS"
REG_BODY="$CV_HTTP_BODY"

# Then
cv_step Then "registration is confirmed and the account exists for that email" $LINENO
[ "$REG_STATUS" = "201" ] || cv_fail "expected HTTP 201 got $REG_STATUS" $LINENO
TOKEN=$(printf '%s' "$REG_BODY" | jq -r '.token // empty')
[ -n "$TOKEN" ] || cv_fail "expected a token in the registration response got none" $LINENO
USER_EMAIL=$(printf '%s' "$REG_BODY" | jq -r '.user.email // empty')
[ "$USER_EMAIL" = "$EMAIL" ] || cv_fail "expected user.email $EMAIL got '$USER_EMAIL'" $LINENO
USER_ID=$(printf '%s' "$REG_BODY" | jq -r '.user.id // empty')
[ -n "$USER_ID" ] || cv_fail "expected user.id in the registration response got none" $LINENO
cv_http POST /auth/login "$BODY"
[ "$CV_HTTP_STATUS" = "200" ] || cv_fail "expected login with the new account to return 200 got $CV_HTTP_STATUS" $LINENO
LOGIN_ID=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.user.id // empty')
[ "$LOGIN_ID" = "$USER_ID" ] || cv_fail "expected login user.id $USER_ID got '$LOGIN_ID'" $LINENO

# Cleanup
cv_step Cleanup "accounts are in-memory; the app exposes no delete route, nothing to remove" $LINENO
echo "unique email $EMAIL left in the in-memory store"

echo "CODEVALID_TEST_ASSERTION_OK:api_25798174_1"
