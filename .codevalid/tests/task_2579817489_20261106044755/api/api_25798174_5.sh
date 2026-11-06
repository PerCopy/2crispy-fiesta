#!/usr/bin/env bash
set -euo pipefail
source "${CODEVALID_ROOT:-.}/.codevalid/lib/cv.sh"
BASE_URL="${BASE_URL:-http://app:6713}"
SUFFIX="$(date +%s%N)"
EMAIL="victim.${SUFFIX}@example.com"
OWNER_PASSWORD="OwnerPw-${SUFFIX}"
OWNER_NAME="Owner ${SUFFIX}"
ATTACKER_PASSWORD="AttackPw-${SUFFIX}"

# Given
cv_step Given "an owner account exists and an attacker knows its email" $LINENO
OWNER_BODY=$(jq -nc --arg e "$EMAIL" --arg p "$OWNER_PASSWORD" --arg n "$OWNER_NAME" '{email:$e,password:$p,name:$n}')
cv_http POST /auth/register "$OWNER_BODY"
[ "$CV_HTTP_STATUS" = "201" ] || cv_fail "expected 201 creating the owner account got $CV_HTTP_STATUS" $LINENO
OWNER_ID=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.user.id // empty')
[ -n "$OWNER_ID" ] || cv_fail "expected owner user.id got none" $LINENO
ATTACK_BODY=$(jq -nc --arg e "$EMAIL" --arg p "$ATTACKER_PASSWORD" '{email:$e,password:$p}')

# When
cv_step When "the attacker registers with the owner's email" $LINENO
cv_http POST /auth/register "$ATTACK_BODY"
ATT_STATUS="$CV_HTTP_STATUS"
ATT_RESP="$CV_HTTP_BODY"

# Then
cv_step Then "the refusal reveals no password, hash or other owner account data" $LINENO
[ "$ATT_STATUS" != "201" ] && [ "$ATT_STATUS" != "200" ] || cv_fail "expected the duplicate registration to be refused got $ATT_STATUS" $LINENO
case "$ATT_RESP" in *"$OWNER_PASSWORD"*) cv_fail "refusal exposes the owner's password" $LINENO ;; esac
case "$ATT_RESP" in *"$OWNER_ID"*) cv_fail "refusal exposes the owner's account id" $LINENO ;; esac
case "$ATT_RESP" in *"$OWNER_NAME"*) cv_fail "refusal exposes the owner's name" $LINENO ;; esac
if printf '%s' "$ATT_RESP" | grep -Eq '\$2[aby]\$[0-9]{2}\$'; then
  cv_fail "refusal contains a bcrypt password hash" $LINENO
fi
EXTRA=$(printf '%s' "$ATT_RESP" | jq -r 'if type=="object" then [keys[] | select(. != "error")] | join(",") else "" end' 2>/dev/null || true)
[ -z "$EXTRA" ] || cv_fail "refusal carries account data fields beyond the error: $EXTRA" $LINENO
cv_http POST /auth/login "$(jq -nc --arg e "$EMAIL" --arg p "$OWNER_PASSWORD" '{email:$e,password:$p}')"
[ "$CV_HTTP_STATUS" = "200" ] || cv_fail "expected owner to still log in with their password got $CV_HTTP_STATUS" $LINENO

# Cleanup
cv_step Cleanup "accounts are in-memory; the app exposes no delete route, nothing to remove" $LINENO
echo "unique email $EMAIL left in the in-memory store"

echo "CODEVALID_TEST_ASSERTION_OK:api_25798174_5"
