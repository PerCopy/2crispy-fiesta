#!/usr/bin/env bash
set -euo pipefail
source "${CODEVALID_ROOT:-.}/.codevalid/lib/cv.sh"
BASE_URL="${BASE_URL:-http://app:6713}"
SUFFIX="$(date +%s%N)"
EMAIL="cv-reg1-${SUFFIX}@example.com"
PASSWORD="Pw-${SUFFIX}!"

# Given
cv_step Given "a fresh email address not yet registered" $LINENO
cv_http POST /auth/login "$(jq -nc --arg e "$EMAIL" --arg p "$PASSWORD" '{email:$e,password:$p}')"
[ "$CV_HTTP_STATUS" = "401" ] || cv_fail "expected email to be unregistered (401 on login) got $CV_HTTP_STATUS" $LINENO

# When
cv_step When "the customer registers with email and password" $LINENO
cv_http POST /auth/register "$(jq -nc --arg e "$EMAIL" --arg p "$PASSWORD" '{email:$e,password:$p}')"
[ "$CV_HTTP_STATUS" = "201" ] || cv_fail "expected 201 on register got $CV_HTTP_STATUS" $LINENO
GOT_EMAIL=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.user.email // empty')
[ "$GOT_EMAIL" = "$EMAIL" ] || cv_fail "expected confirmation for $EMAIL got '$GOT_EMAIL'" $LINENO

# Then
cv_step Then "the account exists and accepts the registered credentials" $LINENO
cv_http POST /auth/login "$(jq -nc --arg e "$EMAIL" --arg p "$PASSWORD" '{email:$e,password:$p}')"
[ "$CV_HTTP_STATUS" = "200" ] || cv_fail "expected 200 on login with registered credentials got $CV_HTTP_STATUS" $LINENO
[ "$(printf '%s' "$CV_HTTP_BODY" | jq -r '.user.email // empty')" = "$EMAIL" ] || cv_fail "expected login to return user $EMAIL" $LINENO

# Cleanup
cv_step Cleanup "accounts are in-memory only; no delete endpoint exists" $LINENO
echo "nothing to remove"
echo "CODEVALID_TEST_ASSERTION_OK:api_82564152_1"
