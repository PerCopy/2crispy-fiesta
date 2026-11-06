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
cv_http POST /products "$(product_json "Lamp-$SUFFIX" "Desk lamp $SUFFIX" 19.5 "LAMP-$SUFFIX")" -H "Authorization: Bearer $TOKEN"
[ "$CV_HTTP_STATUS" = "201" ] || cv_fail "expected product create 201 got $CV_HTTP_STATUS" $LINENO
P1=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.product.id')
cv_http POST /products "$(product_json "Mug-$SUFFIX" "Coffee mug $SUFFIX" 7 "MUG-$SUFFIX")" -H "Authorization: Bearer $TOKEN"
[ "$CV_HTTP_STATUS" = "201" ] || cv_fail "expected product create 201 got $CV_HTTP_STATUS" $LINENO
P2=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.product.id')

# When
cv_step When "a visitor who is not signed in views the full catalog" $LINENO
cv_http GET /products "" 200

# Then
cv_step Then "every added product is listed with name, description, price and product code" $LINENO
for spec in "$P1|Lamp-$SUFFIX|Desk lamp $SUFFIX|19.5|LAMP-$SUFFIX" "$P2|Mug-$SUFFIX|Coffee mug $SUFFIX|7|MUG-$SUFFIX"; do
  IFS='|' read -r id name desc price code <<<"$spec"
  ITEM=$(printf '%s' "$CV_HTTP_BODY" | jq -c --arg id "$id" '.products[] | select(.id == $id)')
  [ -n "$ITEM" ] || cv_fail "expected product $id in catalog got none" $LINENO
  [ "$(printf '%s' "$ITEM" | jq -r '.name')" = "$name" ] || cv_fail "expected name $name got $ITEM" $LINENO
  [ "$(printf '%s' "$ITEM" | jq -r '.description')" = "$desc" ] || cv_fail "expected description $desc got $ITEM" $LINENO
  printf '%s' "$ITEM" | jq -e --argjson p "$price" '.price == $p' >/dev/null || cv_fail "expected price $price got $ITEM" $LINENO
  [ "$(printf '%s' "$ITEM" | code_of)" = "$code" ] || cv_fail "expected product code $code got $ITEM" $LINENO
done

# Cleanup
cv_step Cleanup "no delete route exists; products live in memory until restart" $LINENO

echo "CODEVALID_TEST_ASSERTION_OK:api_89160387_4"
