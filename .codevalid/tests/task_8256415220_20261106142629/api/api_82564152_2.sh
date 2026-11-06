#!/usr/bin/env bash
set -euo pipefail
source "${CODEVALID_ROOT:-.}/.codevalid/lib/cv.sh"
BASE_URL="${BASE_URL:-http://app:6713}"
SUFFIX="$(date +%s%N)"
PASSWORD="Pw-${SUFFIX}!"

# Given
cv_step Given "a password and no email address" $LINENO
BODY=$(jq -nc --arg p "$PASSWORD" '{password:$p}')

# When
cv_step When "the customer submits a registration without an email" $LINENO
cv_http POST /auth/register "$BODY"

# Then
cv_step Then "the registration is refused and no account is returned" $LINENO
case "$CV_HTTP_STATUS" in 4??) ;; *) cv_fail "expected 4xx refusal got $CV_HTTP_STATUS" $LINENO ;; esac
[ -z "$(printf '%s' "$CV_HTTP_BODY" | jq -r '.token // empty' 2>/dev/null)" ] || cv_fail "expected no token in refused registration" $LINENO
[ -z "$(printf '%s' "$CV_HTTP_BODY" | jq -r '.user.id // empty' 2>/dev/null)" ] || cv_fail "expected no user created in refused registration" $LINENO

# Cleanup
cv_step Cleanup "nothing was created" $LINENO
echo "nothing to remove"
echo "CODEVALID_TEST_ASSERTION_OK:api_82564152_2"
