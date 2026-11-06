#!/usr/bin/env bash
set -euo pipefail
source "${CODEVALID_ROOT:-.}/.codevalid/lib/cv.sh"
BASE_URL="${BASE_URL:-http://app:6713}"
SUFFIX="$(date +%s%N)"
EMAIL="taken.${SUFFIX}@example.com"
PASSWORD="OrigPass-${SUFFIX}"
OTHER_PASSWORD="OtherPass-${SUFFIX}"

# Given
cv_step Given "an account already exists for the email" $LINENO
ORIG_BODY=$(jq -nc --arg e "$EMAIL" --arg p "$PASSWORD" '{email:$e,password:$p}')
cv_http POST /auth/register "$ORIG_BODY"
[ "$CV_HTTP_STATUS" = "201" ] || cv_fail "expected 201 creating the existing account got $CV_HTTP_STATUS" $LINENO
ORIG_ID=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.user.id // empty')
[ -n "$ORIG_ID" ] || cv_fail "expected user.id for the existing account got none" $LINENO
DUP_BODY=$(jq -nc --arg e "$EMAIL" --arg p "$OTHER_PASSWORD" '{email:$e,password:$p,name:"Second Person"}')

# When
cv_step When "register again with the same email and another password" $LINENO
cv_http POST /auth/register "$DUP_BODY"
DUP_STATUS="$CV_HTTP_STATUS"
DUP_RESP="$CV_HTTP_BODY"

# Then
cv_step Then "registration is refused, no second account, existing account unchanged" $LINENO
[ "$DUP_STATUS" = "409" ] || cv_fail "expected HTTP 409 for duplicate email got $DUP_STATUS" $LINENO
T=$(printf '%s' "$DUP_RESP" | jq -r '.token // empty' 2>/dev/null || true)
[ -z "$T" ] || cv_fail "expected no token for refused duplicate registration got one" $LINENO
cv_http POST /auth/login "$(jq -nc --arg e "$EMAIL" --arg p "$OTHER_PASSWORD" '{email:$e,password:$p}')"
[ "$CV_HTTP_STATUS" = "401" ] || cv_fail "expected 401 logging in with the duplicate attempt's password (no second account) got $CV_HTTP_STATUS" $LINENO
cv_http POST /auth/login "$ORIG_BODY"
[ "$CV_HTTP_STATUS" = "200" ] || cv_fail "expected original credentials to still log in (200) got $CV_HTTP_STATUS" $LINENO
LOGIN_ID=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.user.id // empty')
LOGIN_NAME=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.user.name // empty')
[ "$LOGIN_ID" = "$ORIG_ID" ] || cv_fail "expected existing account id $ORIG_ID got '$LOGIN_ID'" $LINENO
[ "$LOGIN_NAME" != "Second Person" ] || cv_fail "expected existing account name unchanged got '$LOGIN_NAME'" $LINENO

# Cleanup
cv_step Cleanup "accounts are in-memory; the app exposes no delete route, nothing to remove" $LINENO
echo "unique email $EMAIL left in the in-memory store"

echo "CODEVALID_TEST_ASSERTION_OK:api_25798174_3"
