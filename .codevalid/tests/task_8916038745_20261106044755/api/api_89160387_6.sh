#!/usr/bin/env bash
set -euo pipefail
source "${CODEVALID_ROOT:-.}/.codevalid/lib/cv.sh"
BASE_URL="${BASE_URL:-http://app:6713}"
SUFFIX="$(date +%s%N)"
EMAIL="prod.${SUFFIX}@example.com"
PASSWORD="Str0ngPass-${SUFFIX}"
register() {
  cv_prereq "register signed-in user" $LINENO
  cv_http POST /auth/register "$(jq -nc --arg e "$EMAIL" --arg p "$PASSWORD" '{email:$e,password:$p,name:"Catalog User"}')"
  [ "$CV_HTTP_STATUS" = "201" ] || cv_fail "expected register 201 got $CV_HTTP_STATUS" $LINENO
  TOKEN=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.token // empty')
  [ -n "$TOKEN" ] || cv_fail "expected token from register got none" $LINENO
}
product_json() { jq -nc --arg n "$1" --arg d "$2" --argjson p "$3" --arg c "$4" '{name:$n,description:$d,price:$p,code:$c,productCode:$c}'; }
code_of() { jq -r '(.code // .productCode // .product_code // .sku // "")'; }

# Given
cv_step Given "a signed-in user has added a product" $LINENO
register
cv_http POST /products "$(product_json "Keep-$SUFFIX" "Kept $SUFFIX" 5 "KEEP-$SUFFIX")" -H "Authorization: Bearer $TOKEN"
[ "$CV_HTTP_STATUS" = "201" ] || cv_fail "expected product create 201 got $CV_HTTP_STATUS" $LINENO
PID=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.product.id')

# When
cv_step When "later requests read the catalog and the product while the service keeps running" $LINENO
sleep 1
cv_http GET /products "" 200
LIST="$CV_HTTP_BODY"
cv_http GET "/products/$PID" ""
ONE_STATUS=$CV_HTTP_STATUS; ONE="$CV_HTTP_BODY"

# Then
cv_step Then "the product is still returned by both reads" $LINENO
printf '%s' "$LIST" | jq -e --arg id "$PID" '[.products[] | select(.id == $id)] | length == 1' >/dev/null || cv_fail "expected product $PID in catalog got $LIST" $LINENO
[ "$ONE_STATUS" = "200" ] || cv_fail "expected 200 for product $PID got $ONE_STATUS" $LINENO
printf '%s' "$ONE" | jq -e --arg s "$SUFFIX" '.product.name == ("Keep-" + $s) and .product.description == ("Kept " + $s) and .product.price == 5' >/dev/null || cv_fail "expected unchanged product got $ONE" $LINENO
echo "restart half: the test container cannot restart the app; storage is an in-memory Map (src/store.ts)"

# Cleanup
cv_step Cleanup "no delete route exists; the product lives in memory until restart" $LINENO

echo "CODEVALID_TEST_ASSERTION_OK:api_89160387_6"
