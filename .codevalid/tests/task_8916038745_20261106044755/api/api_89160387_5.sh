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
cv_step Given "a signed-in user has added two products" $LINENO
register
cv_http POST /products "$(product_json "Chair-$SUFFIX" "Office chair $SUFFIX" 120 "CHR-$SUFFIX")" -H "Authorization: Bearer $TOKEN"
[ "$CV_HTTP_STATUS" = "201" ] || cv_fail "expected product create 201 got $CV_HTTP_STATUS" $LINENO
P1=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.product.id')
cv_http POST /products "$(product_json "Desk-$SUFFIX" "Standing desk $SUFFIX" 300 "DSK-$SUFFIX")" -H "Authorization: Bearer $TOKEN"
[ "$CV_HTTP_STATUS" = "201" ] || cv_fail "expected product create 201 got $CV_HTTP_STATUS" $LINENO
P2=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.product.id')

# When
cv_step When "a visitor who is not signed in opens the first product by its identifier" $LINENO
cv_http GET "/products/$P1" "" 200

# Then
cv_step Then "only that product is returned with name, description, price and product code" $LINENO
ITEM=$(printf '%s' "$CV_HTTP_BODY" | jq -c '.product // empty')
[ -n "$ITEM" ] || cv_fail "expected single product got $CV_HTTP_BODY" $LINENO
[ "$(printf '%s' "$ITEM" | jq -r '.id')" = "$P1" ] || cv_fail "expected product $P1 got $ITEM" $LINENO
[ "$(printf '%s' "$ITEM" | jq -r '.name')" = "Chair-$SUFFIX" ] || cv_fail "expected name Chair-$SUFFIX got $ITEM" $LINENO
[ "$(printf '%s' "$ITEM" | jq -r '.description')" = "Office chair $SUFFIX" ] || cv_fail "expected description got $ITEM" $LINENO
printf '%s' "$ITEM" | jq -e '.price == 120' >/dev/null || cv_fail "expected price 120 got $ITEM" $LINENO
[ "$(printf '%s' "$ITEM" | code_of)" = "CHR-$SUFFIX" ] || cv_fail "expected product code CHR-$SUFFIX got $ITEM" $LINENO
printf '%s' "$CV_HTTP_BODY" | grep -q -e "$P2" -e "Desk-$SUFFIX" && cv_fail "expected no other product in response got $CV_HTTP_BODY" $LINENO
printf '%s' "$CV_HTTP_BODY" | jq -e 'has("products") | not' >/dev/null || cv_fail "expected a single product not a list got $CV_HTTP_BODY" $LINENO

# Cleanup
cv_step Cleanup "no delete route exists; products live in memory until restart" $LINENO

echo "CODEVALID_TEST_ASSERTION_OK:api_89160387_5"
