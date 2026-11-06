#!/usr/bin/env bash
set -euo pipefail
source "${CODEVALID_ROOT:-.}/.codevalid/lib/cv.sh"
BASE_URL="${BASE_URL:-http://app:6713}"
SUFFIX="$(date +%s%N)"
EMAIL="cv-reg5-${SUFFIX}@example.com"
PASSWORD="Secret-${SUFFIX}!"
DUP_PASSWORD="Other-${SUFFIX}!"

check_no_password() {
  local body="$1" label="$2"
  printf '%s' "$body" | grep -qF "$PASSWORD" && cv_fail "expected $label response not to contain the submitted password" $LINENO
  printf '%s' "$body" | grep -qF "$DUP_PASSWORD" && cv_fail "expected $label response not to contain the duplicate submitted password" $LINENO
  printf '%s' "$body" | grep -qiE '"(password|passwordHash|password_hash|hash)"' && cv_fail "expected $label response to have no password/hash field" $LINENO
  printf '%s' "$body" | grep -qE '\$2[aby]?\$[0-9]{2}\$' && cv_fail "expected $label response not to contain a bcrypt hash" $LINENO
  return 0
}

# Given
cv_step Given "a customer email and password to register" $LINENO
REG_BODY=$(jq -nc --arg e "$EMAIL" --arg p "$PASSWORD" '{email:$e,password:$p}')

# When
cv_step When "the customer registers and then a duplicate registration is attempted" $LINENO
cv_http POST /auth/register "$REG_BODY"
FIRST_STATUS="$CV_HTTP_STATUS"; FIRST_BODY="$CV_HTTP_BODY"
cv_http POST /auth/register "$(jq -nc --arg e "$EMAIL" --arg p "$DUP_PASSWORD" '{email:$e,password:$p}')"
DUP_STATUS="$CV_HTTP_STATUS"; DUP_BODY="$CV_HTTP_BODY"

# Then
cv_step Then "neither response exposes the password in any form" $LINENO
[ "$FIRST_STATUS" = "201" ] || cv_fail "expected 201 on first registration got $FIRST_STATUS" $LINENO
case "$DUP_STATUS" in 4??) ;; *) cv_fail "expected duplicate registration refused (4xx) got $DUP_STATUS" $LINENO ;; esac
check_no_password "$FIRST_BODY" "registration"
check_no_password "$DUP_BODY" "duplicate registration"
TOKEN=$(printf '%s' "$FIRST_BODY" | jq -r '.token // empty')
if [ -n "$TOKEN" ]; then
  PAYLOAD=$(printf '%s' "$TOKEN" | cut -d. -f2 | tr '_-' '/+')
  while [ $(( ${#PAYLOAD} % 4 )) -ne 0 ]; do PAYLOAD="${PAYLOAD}="; done
  DECODED=$(printf '%s' "$PAYLOAD" | base64 -d 2>/dev/null || true)
  check_no_password "$DECODED" "token payload"
fi

# Cleanup
cv_step Cleanup "accounts are in-memory only; no delete endpoint exists" $LINENO
echo "nothing to remove"
echo "CODEVALID_TEST_ASSERTION_OK:api_82564152_5"
