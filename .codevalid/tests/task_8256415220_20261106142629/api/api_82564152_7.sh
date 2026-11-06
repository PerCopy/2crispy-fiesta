#!/usr/bin/env bash
set -euo pipefail
source "${CODEVALID_ROOT:-.}/.codevalid/lib/cv.sh"
BASE_URL="${BASE_URL:-http://app:6713}"
SUFFIX="$(date +%s%N)"
EMAIL="cv-reg7-${SUFFIX}@example.com"
PASSWORD="Keep-${SUFFIX}!"
PASSWORD2="Again-${SUFFIX}!"

# Given
cv_step Given "a customer has registered an account" $LINENO
cv_http POST /auth/register "$(jq -nc --arg e "$EMAIL" --arg p "$PASSWORD" '{email:$e,password:$p}')"
[ "$CV_HTTP_STATUS" = "201" ] || cv_fail "expected 201 on registration got $CV_HTTP_STATUS" $LINENO
ORIG_ID=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.user.id // empty')
[ -n "$ORIG_ID" ] || cv_fail "expected user id in registration response" $LINENO
sleep 2

# When
cv_step When "the same email is submitted again later without a restart" $LINENO
cv_http POST /auth/register "$(jq -nc --arg e "$EMAIL" --arg p "$PASSWORD2" '{email:$e,password:$p}')"
DUP_STATUS="$CV_HTTP_STATUS"

# Then
cv_step Then "the repeat is refused and the original account is still kept" $LINENO
case "$DUP_STATUS" in 4??) ;; *) cv_fail "expected repeat registration refused (4xx) got $DUP_STATUS" $LINENO ;; esac
cv_http POST /auth/login "$(jq -nc --arg e "$EMAIL" --arg p "$PASSWORD" '{email:$e,password:$p}')"
[ "$CV_HTTP_STATUS" = "200" ] || cv_fail "expected account still kept (login 200) got $CV_HTTP_STATUS" $LINENO
[ "$(printf '%s' "$CV_HTTP_BODY" | jq -r '.user.id // empty')" = "$ORIG_ID" ] || cv_fail "expected original user id $ORIG_ID" $LINENO

# Cleanup
cv_step Cleanup "accounts are in-memory only; no delete endpoint exists" $LINENO
echo "nothing to remove"
echo "CODEVALID_TEST_ASSERTION_OK:api_82564152_7"
