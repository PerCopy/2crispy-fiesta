#!/usr/bin/env bash
set -euo pipefail
source "${CODEVALID_ROOT:-.}/.codevalid/lib/cv.sh"
BASE_URL="${BASE_URL:-http://app:6713}"
SUFFIX="$(date +%s%N)"
EMAIL="private.${SUFFIX}@example.com"
PASSWORD="SecretPw-${SUFFIX}"

# Given
cv_step Given "a customer with a new email and a distinctive password" $LINENO
BODY=$(jq -nc --arg e "$EMAIL" --arg p "$PASSWORD" '{email:$e,password:$p}')

# When
cv_step When "register the account" $LINENO
cv_http POST /auth/register "$BODY"
REG_STATUS="$CV_HTTP_STATUS"
REG_BODY="$CV_HTTP_BODY"

# Then
cv_step Then "the returned account data does not include the password or its hash" $LINENO
[ "$REG_STATUS" = "201" ] || cv_fail "expected HTTP 201 got $REG_STATUS" $LINENO
case "$REG_BODY" in *"$PASSWORD"*) cv_fail "registration response exposes the submitted password" $LINENO ;; esac
LEAK_KEYS=$(printf '%s' "$REG_BODY" | jq -r '[paths | map(tostring) | last | select(test("pass|hash|secret";"i"))] | unique | join(",")')
[ -z "$LEAK_KEYS" ] || cv_fail "registration response contains password-related fields: $LEAK_KEYS" $LINENO
if printf '%s' "$REG_BODY" | grep -Eq '\$2[aby]\$[0-9]{2}\$'; then
  cv_fail "registration response contains a bcrypt password hash" $LINENO
fi

# Cleanup
cv_step Cleanup "accounts are in-memory; the app exposes no delete route, nothing to remove" $LINENO
echo "unique email $EMAIL left in the in-memory store"

echo "CODEVALID_TEST_ASSERTION_OK:api_25798174_4"
