#!/usr/bin/env bash
set -euo pipefail
source "${CODEVALID_ROOT:-.}/.codevalid/lib/cv.sh"
BASE_URL="${BASE_URL:-http://app:6713}"
SUFFIX="$(date +%s%N)"
EMAIL="signin.${SUFFIX}@example.com"
PASSWORD="Str0ngPass-${SUFFIX}"
register_user() {
  cv_prereq "register $1" $LINENO
  cv_http POST /auth/register "$(jq -nc --arg e "$1" --arg p "$2" '{email:$e,password:$p,name:"Sign In Customer"}')"
  [ "$CV_HTTP_STATUS" = "201" ] || cv_fail "expected register 201 got $CV_HTTP_STATUS" $LINENO
}
product_count() {
  cv_http GET /products "" 200
  PRODUCT_COUNT=$(printf "%s" "$CV_HTTP_BODY" | jq -r ".products | length")
}

# Given
cv_step Given "a registered customer" $LINENO
register_user "$EMAIL" "$PASSWORD"
REG_BODY="$CV_HTTP_BODY"

# When
cv_step When "the customer signs in" $LINENO
cv_http POST /auth/login "$(jq -nc --arg e "$EMAIL" --arg p "$PASSWORD" '{email:$e,password:$p}')" 200
LOGIN_BODY="$CV_HTTP_BODY"

# Then
cv_step Then "no password or hash appears in sign-in or account responses" $LINENO
TOKEN=$(printf '%s' "$LOGIN_BODY" | jq -r '.token // empty')
[ -n "$TOKEN" ] || cv_fail "expected token in login response got none" $LINENO
cv_http POST /products "$(jq -nc --arg n "Priv-$SUFFIX" '{name:$n,price:2}')" 201 -H "Authorization: Bearer $TOKEN"
PROD_BODY="$CV_HTTP_BODY"
PID=$(printf '%s' "$PROD_BODY" | jq -r '.product.id')
cv_http GET "/products/$PID" "" 200
GET_BODY="$CV_HTTP_BODY"
PAYLOAD=$(printf '%s' "$TOKEN" | cut -d. -f2 | tr '_-' '/+'); while [ $(( ${#PAYLOAD} % 4 )) -ne 0 ]; do PAYLOAD="${PAYLOAD}="; done
JWT_JSON=$(printf '%s' "$PAYLOAD" | base64 -d 2>/dev/null || true)
for label in register login product product_get jwt; do
  case $label in register) B="$REG_BODY";; login) B="$LOGIN_BODY";; product) B="$PROD_BODY";; product_get) B="$GET_BODY";; jwt) B="$JWT_JSON";; esac
  case "$B" in *"$PASSWORD"*) cv_fail "expected no plaintext password in $label response got it" $LINENO;; esac
  if printf '%s' "$B" | grep -Eq '\$2[aby]\$'; then cv_fail "expected no bcrypt hash in $label response got one" $LINENO; fi
  if printf '%s' "$B" | grep -Eiq '"(password|passwordHash|password_hash|hash)"'; then cv_fail "expected no password field in $label response got one" $LINENO; fi
done
LKEYS=$(printf '%s' "$LOGIN_BODY" | jq -c '.user | keys')
[ "$LKEYS" = '["email","id","name"]' ] || cv_fail "expected login user keys [email,id,name] got $LKEYS" $LINENO

# Cleanup
cv_step Cleanup "in-memory store has no delete routes; nothing to remove" $LINENO
echo "account $EMAIL and product $PID remain in memory"

echo "CODEVALID_TEST_ASSERTION_OK:api_38744878_5"
