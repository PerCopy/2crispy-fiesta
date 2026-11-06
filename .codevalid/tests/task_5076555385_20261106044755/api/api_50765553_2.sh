#!/usr/bin/env bash
set -euo pipefail
source "${CODEVALID_ROOT:-.}/.codevalid/lib/cv.sh"
BASE_URL="${BASE_URL:-http://app:6713}"
SUFFIX="$(date +%s%N)"
EMAIL="catalog2.${SUFFIX}@example.com"
PASSWORD="Str0ngPass-${SUFFIX}"
NAME="Kettle-$SUFFIX"; DESC="Electric kettle $SUFFIX"; PRICE=42.25; CODE="KET-$SUFFIX"

# Given
cv_step Given "an existing product in the catalog" $LINENO
cv_prereq "register product owner" $LINENO
cv_http POST /auth/register "$(jq -nc --arg e "$EMAIL" --arg p "$PASSWORD" '{email:$e,password:$p,name:"Catalog Owner"}')"
[ "$CV_HTTP_STATUS" = "201" ] || cv_fail "expected register 201 got $CV_HTTP_STATUS" $LINENO
TOKEN=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.token // empty')
[ -n "$TOKEN" ] || cv_fail "expected token from register got none" $LINENO
cv_prereq "add product" $LINENO
cv_http POST /products "$(jq -nc --arg n "$NAME" --arg d "$DESC" --argjson p "$PRICE" --arg c "$CODE" '{name:$n,description:$d,price:$p,code:$c,productCode:$c}')" -H "Authorization: Bearer $TOKEN"
[ "$CV_HTTP_STATUS" = "201" ] || cv_fail "expected product create 201 got $CV_HTTP_STATUS" $LINENO
STORED=$(printf '%s' "$CV_HTTP_BODY" | jq -c '.product')
PID=$(printf '%s' "$STORED" | jq -r '.id // empty')
[ -n "$PID" ] || cv_fail "expected product id got none" $LINENO

# When
cv_step When "a visitor without sign-in opens the product by its identifier" $LINENO
cv_http GET "/products/$PID" "" 200

# Then
cv_step Then "the product details match the stored product" $LINENO
GOT=$(printf '%s' "$CV_HTTP_BODY" | jq -c '.product // empty')
[ -n "$GOT" ] || cv_fail "expected product in response got $CV_HTTP_BODY" $LINENO
[ "$(printf '%s' "$GOT" | jq -r '.id')" = "$PID" ] || cv_fail "expected id $PID got $GOT" $LINENO
[ "$(printf '%s' "$GOT" | jq -r '.name')" = "$NAME" ] || cv_fail "expected name $NAME got $GOT" $LINENO
[ "$(printf '%s' "$GOT" | jq -r '.description')" = "$DESC" ] || cv_fail "expected description $DESC got $GOT" $LINENO
printf '%s' "$GOT" | jq -e --argjson p "$PRICE" '.price == $p' >/dev/null || cv_fail "expected price $PRICE got $GOT" $LINENO
[ "$GOT" = "$STORED" ] || cv_fail "expected opened product to equal stored $STORED got $GOT" $LINENO
GOT_CODE=$(printf '%s' "$GOT" | jq -r '(.code // .productCode // .product_code // .sku) // empty')
[ -n "$GOT_CODE" ] || cv_fail "expected product code in product details got none: $GOT" $LINENO
[ "$GOT_CODE" = "$CODE" ] || cv_fail "expected product code $CODE got $GOT_CODE" $LINENO

# Cleanup
cv_step Cleanup "no delete route exists; product stays in the in-memory store until restart" $LINENO
echo "product $PID remains in memory"

echo "CODEVALID_TEST_ASSERTION_OK:api_50765553_2"
