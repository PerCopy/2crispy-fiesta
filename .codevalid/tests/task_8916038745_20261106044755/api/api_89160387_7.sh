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
cv_step Given "a product payload and a visitor with no sign-in" $LINENO
NAME="Anon-$SUFFIX"
cv_http GET /products "" 200

# When
cv_step When "the visitor tries to add a product without signing in" $LINENO
cv_http POST /products "$(product_json "$NAME" "Anon product $SUFFIX" 3 "ANON-$SUFFIX")"
ATTEMPT=$CV_HTTP_STATUS

# Then
cv_step Then "the attempt is refused and the product is not in the catalog" $LINENO
case "$ATTEMPT" in 2*) cv_fail "expected anonymous product add to be refused got $ATTEMPT" $LINENO ;; esac
cv_http GET /products "" 200
LEAK=$(printf '%s' "$CV_HTTP_BODY" | jq -c --arg n "$NAME" '[.products[] | select(.name == $n)]')
[ "$LEAK" = "[]" ] || cv_fail "expected no anonymous product in catalog got $LEAK" $LINENO

# Cleanup
cv_step Cleanup "nothing was created" $LINENO

echo "CODEVALID_TEST_ASSERTION_OK:api_89160387_7"
