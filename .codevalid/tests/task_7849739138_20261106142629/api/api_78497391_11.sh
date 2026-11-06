#!/usr/bin/env bash
set -euo pipefail
source "${CODEVALID_ROOT:-.}/.codevalid/lib/cv.sh"
BASE_URL="${BASE_URL:-http://app:6713}"
SUFFIX="$(date +%s%N)"
EMAIL="cust11_${SUFFIX}@example.com"
PASSWORD="Sup3rSecret_${SUFFIX}"

# Given
cv_step Given "a customer registers and time passes with the service still running" $LINENO
cv_http POST /auth/register "$(jq -nc --arg e "$EMAIL" --arg p "$PASSWORD" --arg n "Customer $SUFFIX" '{email:$e,password:$p,name:$n}')"
[ "$CV_HTTP_STATUS" = "201" ] || cv_fail "expected 201 from register got $CV_HTTP_STATUS" $LINENO
USER_ID=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.user.id // empty')
[ -n "$USER_ID" ] || cv_fail "expected user id in register response got none" $LINENO
sleep 3
cv_prereq "service is still running" $LINENO
cv_http GET /health 200

# When
cv_step When "the customer signs in again with the same email and password" $LINENO
cv_http POST /auth/login "$(jq -nc --arg e "$EMAIL" --arg p "$PASSWORD" '{email:$e,password:$p}')"
LOGIN_STATUS="$CV_HTTP_STATUS"
LOGIN_BODY="$CV_HTTP_BODY"

# Then
cv_step Then "sign-in succeeds for the same account and the token works" $LINENO
[ "$LOGIN_STATUS" = "200" ] || cv_fail "expected 200 from sign-in got $LOGIN_STATUS" $LINENO
TOKEN=$(printf '%s' "$LOGIN_BODY" | jq -r '.token // empty')
[ -n "$TOKEN" ] || cv_fail "expected a token in sign-in response got none" $LINENO
GOT_ID=$(printf '%s' "$LOGIN_BODY" | jq -r '.user.id // empty')
[ "$GOT_ID" = "$USER_ID" ] || cv_fail "expected user.id $USER_ID got $GOT_ID" $LINENO
GOT_EMAIL=$(printf '%s' "$LOGIN_BODY" | jq -r '.user.email // empty')
[ "$GOT_EMAIL" = "$EMAIL" ] || cv_fail "expected user.email $EMAIL got $GOT_EMAIL" $LINENO
cv_http POST /products "$(jq -nc --arg n "Persist check $SUFFIX" '{name:$n,price:1}')" -H "Authorization: Bearer $TOKEN"
[ "$CV_HTTP_STATUS" = "201" ] || cv_fail "expected 201 for signed-in product create got $CV_HTTP_STATUS" $LINENO

# Cleanup
cv_step Cleanup "nothing to remove: the store is in-memory and has no delete endpoint" $LINENO
echo "nothing to remove"
echo "CODEVALID_TEST_ASSERTION_OK:api_78497391_11"
