#!/usr/bin/env bash
set -euo pipefail
source "${CODEVALID_ROOT:-.}/.codevalid/lib/cv.sh"
BASE_URL="${BASE_URL:-http://app:6713}"
SUFFIX="$(date +%s%N)"
EMAIL="cv-reg4-${SUFFIX}@example.com"
PASSWORD1="First-${SUFFIX}!"
PASSWORD2="Second-${SUFFIX}!"

# Given
cv_step Given "an account already exists for the email" $LINENO
cv_http POST /auth/register "$(jq -nc --arg e "$EMAIL" --arg p "$PASSWORD1" '{email:$e,password:$p}')"
[ "$CV_HTTP_STATUS" = "201" ] || cv_fail "expected 201 creating original account got $CV_HTTP_STATUS" $LINENO
ORIG_ID=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.user.id // empty')
[ -n "$ORIG_ID" ] || cv_fail "expected user id in registration response" $LINENO

# When
cv_step When "a second registration uses the same email with a different password" $LINENO
cv_http POST /auth/register "$(jq -nc --arg e "$EMAIL" --arg p "$PASSWORD2" '{email:$e,password:$p}')"
DUP_STATUS="$CV_HTTP_STATUS"

# Then
cv_step Then "the second registration is refused and the original account is unchanged" $LINENO
case "$DUP_STATUS" in 4??) ;; *) cv_fail "expected 4xx refusal for duplicate email got $DUP_STATUS" $LINENO ;; esac
cv_http POST /auth/login "$(jq -nc --arg e "$EMAIL" --arg p "$PASSWORD1" '{email:$e,password:$p}')"
[ "$CV_HTTP_STATUS" = "200" ] || cv_fail "expected original password to still work (200) got $CV_HTTP_STATUS" $LINENO
[ "$(printf '%s' "$CV_HTTP_BODY" | jq -r '.user.id // empty')" = "$ORIG_ID" ] || cv_fail "expected same original user id $ORIG_ID" $LINENO
cv_http POST /auth/login "$(jq -nc --arg e "$EMAIL" --arg p "$PASSWORD2" '{email:$e,password:$p}')"
[ "$CV_HTTP_STATUS" = "401" ] || cv_fail "expected second password to be rejected (401) got $CV_HTTP_STATUS" $LINENO

# Cleanup
cv_step Cleanup "accounts are in-memory only; no delete endpoint exists" $LINENO
echo "nothing to remove"
echo "CODEVALID_TEST_ASSERTION_OK:api_82564152_4"
