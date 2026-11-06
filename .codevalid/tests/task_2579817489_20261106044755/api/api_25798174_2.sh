#!/usr/bin/env bash
set -euo pipefail
source "${CODEVALID_ROOT:-.}/.codevalid/lib/cv.sh"
BASE_URL="${BASE_URL:-http://app:6713}"
SUFFIX="$(date +%s%N)"
EMAIL="no.password.${SUFFIX}@example.com"
PASSWORD="Str0ngPass-${SUFFIX}"

# Given
cv_step Given "registration payloads missing the email, and missing the password" $LINENO
NO_EMAIL_BODY=$(jq -nc --arg p "$PASSWORD" '{password:$p}')
NO_PASSWORD_BODY=$(jq -nc --arg e "$EMAIL" '{email:$e}')

# When
cv_step When "register without an email, then without a password" $LINENO
cv_http POST /auth/register "$NO_EMAIL_BODY"
NO_EMAIL_STATUS="$CV_HTTP_STATUS"
NO_EMAIL_RESP="$CV_HTTP_BODY"
cv_http POST /auth/register "$NO_PASSWORD_BODY"
NO_PASSWORD_STATUS="$CV_HTTP_STATUS"
NO_PASSWORD_RESP="$CV_HTTP_BODY"

# Then
cv_step Then "both registrations are refused and no account was created" $LINENO
[ "$NO_EMAIL_STATUS" = "400" ] || cv_fail "expected HTTP 400 for missing email got $NO_EMAIL_STATUS" $LINENO
[ "$NO_PASSWORD_STATUS" = "400" ] || cv_fail "expected HTTP 400 for missing password got $NO_PASSWORD_STATUS" $LINENO
for R in "$NO_EMAIL_RESP" "$NO_PASSWORD_RESP"; do
  T=$(printf '%s' "$R" | jq -r '.token // empty' 2>/dev/null || true)
  [ -z "$T" ] || cv_fail "expected no token for a refused registration got one" $LINENO
done
# no account exists for the email: registering it properly now must succeed (not 409)
FULL_BODY=$(jq -nc --arg e "$EMAIL" --arg p "$PASSWORD" '{email:$e,password:$p}')
cv_http POST /auth/register "$FULL_BODY"
[ "$CV_HTTP_STATUS" = "201" ] || cv_fail "expected 201 registering $EMAIL after the refused attempt (no account should exist) got $CV_HTTP_STATUS" $LINENO

# Cleanup
cv_step Cleanup "accounts are in-memory; the app exposes no delete route, nothing to remove" $LINENO
echo "unique email $EMAIL left in the in-memory store"

echo "CODEVALID_TEST_ASSERTION_OK:api_25798174_2"
