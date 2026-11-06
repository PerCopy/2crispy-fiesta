#!/usr/bin/env bash
set -euo pipefail
source "${CODEVALID_ROOT:-.}/.codevalid/lib/cv.sh"
BASE_URL="${BASE_URL:-http://app:6713}"
SUFFIX="$(date +%s%N)"
EMAIL="cv-reg3-${SUFFIX}@example.com"
PROBE_PASSWORD="Probe-${SUFFIX}!"

# Given
cv_step Given "an email address not yet registered and no password" $LINENO
cv_http POST /auth/login "$(jq -nc --arg e "$EMAIL" --arg p "$PROBE_PASSWORD" '{email:$e,password:$p}')"
[ "$CV_HTTP_STATUS" = "401" ] || cv_fail "expected email to be unregistered (401) got $CV_HTTP_STATUS" $LINENO

# When
cv_step When "the customer submits a registration without a password" $LINENO
cv_http POST /auth/register "$(jq -nc --arg e "$EMAIL" '{email:$e}')"
REG_STATUS="$CV_HTTP_STATUS"
REG_BODY="$CV_HTTP_BODY"

# Then
cv_step Then "the registration is refused and no account exists for that email" $LINENO
case "$REG_STATUS" in 4??) ;; *) cv_fail "expected 4xx refusal got $REG_STATUS" $LINENO ;; esac
[ -z "$(printf '%s' "$REG_BODY" | jq -r '.token // empty' 2>/dev/null)" ] || cv_fail "expected no token in refused registration" $LINENO
# If an account had been created, registering the same email with a password would be refused (409)
cv_http POST /auth/register "$(jq -nc --arg e "$EMAIL" --arg p "$PROBE_PASSWORD" '{email:$e,password:$p}')"
[ "$CV_HTTP_STATUS" = "201" ] || cv_fail "expected email to still be free (201) after refused registration got $CV_HTTP_STATUS" $LINENO

# Cleanup
cv_step Cleanup "accounts are in-memory only; no delete endpoint exists" $LINENO
echo "nothing to remove"
echo "CODEVALID_TEST_ASSERTION_OK:api_82564152_3"
