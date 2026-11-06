#!/usr/bin/env bash
set -euo pipefail
source "${CODEVALID_ROOT:-.}/.codevalid/lib/cv.sh"
BASE_URL="${BASE_URL:-http://app:6713}"
SUFFIX="$(date +%s%N)"
EMAIL="cust9_${SUFFIX}@example.com"
PASSWORD="Sup3rSecret_${SUFFIX}"
WRONG_PASSWORD="WrongGuess_${SUFFIX}"
PRODUCT_NAME="Intruder product ${SUFFIX}"

# Given
cv_step Given "a registered customer exists and the catalog state is recorded" $LINENO
cv_prereq "register customer $EMAIL" $LINENO
cv_http POST /auth/register "$(jq -nc --arg e "$EMAIL" --arg p "$PASSWORD" '{email:$e,password:$p}')"
[ "$CV_HTTP_STATUS" = "201" ] || cv_fail "expected 201 from register got $CV_HTTP_STATUS" $LINENO
cv_prereq "catalog is browsable before the attempt" $LINENO
cv_http GET /products
[ "$CV_HTTP_STATUS" = "200" ] || cv_fail "expected 200 from catalog listing got $CV_HTTP_STATUS" $LINENO

# When
cv_step When "someone signs in with the right email but a wrong password, then tries to add a product" $LINENO
cv_http POST /auth/login "$(jq -nc --arg e "$EMAIL" --arg p "$WRONG_PASSWORD" '{email:$e,password:$p}')"
LOGIN_STATUS="$CV_HTTP_STATUS"
LOGIN_TOKEN=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.token // empty' 2>/dev/null || true)
cv_http POST /products "$(jq -nc --arg n "$PRODUCT_NAME" '{name:$n,price:9.99}')" -H "Authorization: Bearer ${LOGIN_TOKEN}"
CREATE_STATUS="$CV_HTTP_STATUS"

# Then
cv_step Then "sign-in is refused, no token is issued, the update is refused and the catalog is unchanged" $LINENO
case "$LOGIN_STATUS" in 2??) cv_fail "expected wrong-password sign-in refused got $LOGIN_STATUS" $LINENO ;; esac
[ -z "$LOGIN_TOKEN" ] || cv_fail "expected no token from failed sign-in got one" $LINENO
case "$CREATE_STATUS" in 2??) cv_fail "expected catalog update refused got $CREATE_STATUS" $LINENO ;; esac
cv_http GET /products
[ "$CV_HTTP_STATUS" = "200" ] || cv_fail "expected 200 from catalog listing got $CV_HTTP_STATUS" $LINENO
FOUND=$(printf '%s' "$CV_HTTP_BODY" | jq --arg n "$PRODUCT_NAME" '[.products[] | select(.name == $n)] | length')
[ "$FOUND" = "0" ] || cv_fail "expected product '$PRODUCT_NAME' absent from catalog got $FOUND entries" $LINENO

# Cleanup
cv_step Cleanup "nothing to remove: the store is in-memory and has no delete endpoint" $LINENO
echo "nothing to remove"
echo "CODEVALID_TEST_ASSERTION_OK:api_78497391_9"
