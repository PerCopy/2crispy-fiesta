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
cv_step Given "a signed-in user and a product code not used before" $LINENO
register
NAME="Lamp-$SUFFIX"; DESC="Desk lamp $SUFFIX"; PRICE=19.5; CODE="LAMP-$SUFFIX"

# When
cv_step When "the signed-in user adds a product with name, description, price and product code" $LINENO
cv_http POST /products "$(product_json "$NAME" "$DESC" "$PRICE" "$CODE")" -H "Authorization: Bearer $TOKEN"

# Then
cv_step Then "the product is created and stored with the submitted values" $LINENO
[ "$CV_HTTP_STATUS" = "201" ] || cv_fail "expected 201 got $CV_HTTP_STATUS: $CV_HTTP_BODY" $LINENO
P=$(printf '%s' "$CV_HTTP_BODY" | jq -c '.product // empty')
[ -n "$P" ] || cv_fail "expected product in response got $CV_HTTP_BODY" $LINENO
PID=$(printf '%s' "$P" | jq -r '.id // empty')
[ -n "$PID" ] || cv_fail "expected product id got $P" $LINENO
check() {
  local item="$1" where="$2"
  [ "$(printf '%s' "$item" | jq -r '.name')" = "$NAME" ] || cv_fail "expected $where name $NAME got $item" $LINENO
  [ "$(printf '%s' "$item" | jq -r '.description')" = "$DESC" ] || cv_fail "expected $where description $DESC got $item" $LINENO
  printf '%s' "$item" | jq -e --argjson p "$PRICE" '.price == $p' >/dev/null || cv_fail "expected $where price $PRICE got $item" $LINENO
  [ "$(printf '%s' "$item" | code_of)" = "$CODE" ] || cv_fail "expected $where product code $CODE got $item" $LINENO
}
check "$P" "created"
cv_http GET "/products/$PID" "" 200
check "$(printf '%s' "$CV_HTTP_BODY" | jq -c '.product')" "stored"

# Cleanup
cv_step Cleanup "no delete route exists; the product lives in memory until restart" $LINENO
echo "product $PID remains in memory"

echo "CODEVALID_TEST_ASSERTION_OK:api_89160387_1"
