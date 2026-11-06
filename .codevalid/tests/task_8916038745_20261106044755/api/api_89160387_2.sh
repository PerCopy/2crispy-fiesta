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
cv_step Given "a signed-in user and four product payloads each missing one required field" $LINENO
register
FULL=$(product_json "Gadget-$SUFFIX" "Gadget $SUFFIX" 12 "GAD-$SUFFIX")
declare -A STATUS

# When
cv_step When "the signed-in user tries to add each incomplete product" $LINENO
for field in name description price code; do
  BODY=$(printf '%s' "$FULL" | jq -c --arg f "$field" --arg s "$SUFFIX" '
    .name = ("Gadget-" + $f + "-" + $s) | .code = ("GAD-" + $f + "-" + $s) | .productCode = .code
    | if $f == "code" then del(.code, .productCode) else del(.[$f]) end
    | if $f == "name" then .description = ("Gadget-name-" + $s) else . end')
  cv_http POST /products "$BODY" -H "Authorization: Bearer $TOKEN"
  STATUS[$field]=$CV_HTTP_STATUS
done

# Then
cv_step Then "each attempt is refused and no such product is in the catalog" $LINENO
for field in name description price code; do
  case "${STATUS[$field]}" in 2*) cv_fail "expected product missing $field to be refused got ${STATUS[$field]}" $LINENO ;; esac
done
cv_http GET /products "" 200
LEAK=$(printf '%s' "$CV_HTTP_BODY" | jq -c --arg s "$SUFFIX" '[.products[] | select(((.name // "") + (.description // "")) | contains("Gadget-") and contains($s))]')
[ "$LEAK" = "[]" ] || cv_fail "expected no incomplete product in catalog got $LEAK" $LINENO

# Cleanup
cv_step Cleanup "nothing was meant to be created; no delete route exists" $LINENO

echo "CODEVALID_TEST_ASSERTION_OK:api_89160387_2"
