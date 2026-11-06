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
cv_step Given "a signed-in user who has added a product with a product code" $LINENO
register
CODE="DUP-$SUFFIX"
cv_http POST /products "$(product_json "Original-$SUFFIX" "Original $SUFFIX" 10 "$CODE")" -H "Authorization: Bearer $TOKEN"
[ "$CV_HTTP_STATUS" = "201" ] || cv_fail "expected first product 201 got $CV_HTTP_STATUS" $LINENO
P1=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.product.id')

# When
cv_step When "the user tries to add a second product with the same product code" $LINENO
cv_http POST /products "$(product_json "Copy-$SUFFIX" "Copy $SUFFIX" 99 "$CODE")" -H "Authorization: Bearer $TOKEN"
SECOND_STATUS=$CV_HTTP_STATUS

# Then
cv_step Then "the second product is refused, one product holds the code and the original is unchanged" $LINENO
case "$SECOND_STATUS" in 2*) cv_fail "expected duplicate product code to be refused got $SECOND_STATUS" $LINENO ;; esac
cv_http GET /products "" 200
COPIES=$(printf '%s' "$CV_HTTP_BODY" | jq -c --arg s "$SUFFIX" '[.products[] | select(.name == ("Copy-" + $s))]')
[ "$COPIES" = "[]" ] || cv_fail "expected no second product got $COPIES" $LINENO
N=$(printf '%s' "$CV_HTTP_BODY" | jq --arg c "$CODE" '[.products[] | select((.code // .productCode // .product_code // .sku) == $c)] | length')
[ "$N" = "1" ] || cv_fail "expected exactly 1 product with code $CODE got $N" $LINENO
cv_http GET "/products/$P1" "" 200
O=$(printf '%s' "$CV_HTTP_BODY" | jq -c '.product')
printf '%s' "$O" | jq -e --arg s "$SUFFIX" '.name == ("Original-" + $s) and .description == ("Original " + $s) and .price == 10' >/dev/null || cv_fail "expected original unchanged got $O" $LINENO

# Cleanup
cv_step Cleanup "no delete route exists; the product lives in memory until restart" $LINENO

echo "CODEVALID_TEST_ASSERTION_OK:api_89160387_3"
