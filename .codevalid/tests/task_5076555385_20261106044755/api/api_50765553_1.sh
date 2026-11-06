#!/usr/bin/env bash
set -euo pipefail
source "${CODEVALID_ROOT:-.}/.codevalid/lib/cv.sh"
BASE_URL="${BASE_URL:-http://app:6713}"
SUFFIX="$(date +%s%N)"
EMAIL="catalog1.${SUFFIX}@example.com"
PASSWORD="Str0ngPass-${SUFFIX}"
create_product() {
  cv_prereq "add product $1" $LINENO
  cv_http POST /products "$(jq -nc --arg n "$1" --arg d "$2" --argjson p "$3" --arg c "$4" '{name:$n,description:$d,price:$p,code:$c,productCode:$c}')" -H "Authorization: Bearer $TOKEN"
  [ "$CV_HTTP_STATUS" = "201" ] || cv_fail "expected product create 201 got $CV_HTTP_STATUS" $LINENO
}

# Given
cv_step Given "a catalog holding two products added by a signed-in user" $LINENO
cv_prereq "register product owner" $LINENO
cv_http POST /auth/register "$(jq -nc --arg e "$EMAIL" --arg p "$PASSWORD" '{email:$e,password:$p,name:"Catalog Owner"}')"
[ "$CV_HTTP_STATUS" = "201" ] || cv_fail "expected register 201 got $CV_HTTP_STATUS" $LINENO
TOKEN=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.token // empty')
[ -n "$TOKEN" ] || cv_fail "expected token from register got none" $LINENO
create_product "Lamp-$SUFFIX" "Desk lamp $SUFFIX" 19.5 "LAMP-$SUFFIX"
P1=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.product.id')
create_product "Mug-$SUFFIX" "Coffee mug $SUFFIX" 7 "MUG-$SUFFIX"
P2=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.product.id')

# When
cv_step When "a visitor without sign-in requests the catalog" $LINENO
cv_http GET /products "" 200

# Then
cv_step Then "the full list is returned with name, description, price and product code for each product" $LINENO
printf '%s' "$CV_HTTP_BODY" | jq -e '.products | type == "array"' >/dev/null || cv_fail "expected products array got $CV_HTTP_BODY" $LINENO
for spec in "$P1|Lamp-$SUFFIX|Desk lamp $SUFFIX|19.5" "$P2|Mug-$SUFFIX|Coffee mug $SUFFIX|7"; do
  IFS='|' read -r id name desc price <<<"$spec"
  ITEM=$(printf '%s' "$CV_HTTP_BODY" | jq -c --arg id "$id" '.products[] | select(.id == $id)')
  [ -n "$ITEM" ] || cv_fail "expected product $id in catalog got none" $LINENO
  [ "$(printf '%s' "$ITEM" | jq -r '.name')" = "$name" ] || cv_fail "expected name $name got $ITEM" $LINENO
  [ "$(printf '%s' "$ITEM" | jq -r '.description')" = "$desc" ] || cv_fail "expected description $desc got $ITEM" $LINENO
  printf '%s' "$ITEM" | jq -e --argjson p "$price" '.price == $p' >/dev/null || cv_fail "expected price $price got $ITEM" $LINENO
done
MISSING=$(printf '%s' "$CV_HTTP_BODY" | jq -r '[.products[] | select(((.code // .productCode // .product_code // .sku) // "") == "")] | length')
[ "$MISSING" = "0" ] || cv_fail "expected every product to have a product code got $MISSING without one: $(printf '%s' "$CV_HTTP_BODY" | jq -c '.products[0]')" $LINENO

# Cleanup
cv_step Cleanup "no delete route exists; products stay in the in-memory store until restart" $LINENO
echo "products $P1 $P2 remain in memory"

echo "CODEVALID_TEST_ASSERTION_OK:api_50765553_1"
