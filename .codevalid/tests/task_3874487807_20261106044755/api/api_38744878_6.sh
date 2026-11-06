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
cv_step Given "a registered customer signs in" $LINENO
register_user "$EMAIL" "$PASSWORD"
cv_http POST /auth/login "$(jq -nc --arg e "$EMAIL" --arg p "$PASSWORD" '{email:$e,password:$p}')" 200
TOKEN=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.token // empty')
[ -n "$TOKEN" ] || cv_fail "expected token from login got none" $LINENO
NAME="Catalog-Item-$SUFFIX"

# When
cv_step When "the signed-in customer adds a product to the catalog" $LINENO
cv_http POST /products "$(jq -nc --arg n "$NAME" '{name:$n,description:"added by signed-in customer",price:19.99}')" -H "Authorization: Bearer $TOKEN"

# Then
cv_step Then "the change is accepted and visible in later catalog reads" $LINENO
[ "$CV_HTTP_STATUS" = "201" ] || cv_fail "expected 201 for signed-in catalog change got $CV_HTTP_STATUS" $LINENO
PID=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.product.id // empty')
[ -n "$PID" ] || cv_fail "expected product.id in response got none" $LINENO
cv_http GET /products "" 200
printf '%s' "$CV_HTTP_BODY" | jq -e --arg id "$PID" --arg n "$NAME" '[.products[]|select(.id==$id and .name==$n and .price==19.99)]|length==1' >/dev/null || cv_fail "expected product $PID ($NAME) in catalog list got none" $LINENO
cv_http GET "/products/$PID" "" 200
GN=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.product.name // empty')
[ "$GN" = "$NAME" ] || cv_fail "expected product name $NAME got '$GN'" $LINENO

# Cleanup
cv_step Cleanup "in-memory store has no delete routes; nothing to remove" $LINENO
echo "account $EMAIL and product $PID remain in memory"

echo "CODEVALID_TEST_ASSERTION_OK:api_38744878_6"
