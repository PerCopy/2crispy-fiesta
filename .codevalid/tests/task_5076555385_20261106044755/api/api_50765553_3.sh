#!/usr/bin/env bash
set -euo pipefail
source "${CODEVALID_ROOT:-.}/.codevalid/lib/cv.sh"
BASE_URL="${BASE_URL:-http://app:6713}"
UNKNOWN_ID="00000000-0000-4000-8000-$(date +%s%N | tail -c 13)"

# Given
cv_step Given "an identifier that matches no product in the catalog" $LINENO
cv_http GET /products "" 200
printf '%s' "$CV_HTTP_BODY" | jq -e --arg id "$UNKNOWN_ID" '[.products[] | select(.id == $id)] | length == 0' >/dev/null \
  || cv_fail "expected no product with id $UNKNOWN_ID got one" $LINENO

# When
cv_step When "a visitor opens the product by the unknown identifier" $LINENO
cv_http GET "/products/$UNKNOWN_ID"

# Then
cv_step Then "the response is not found and carries no product details" $LINENO
[ "$CV_HTTP_STATUS" = "404" ] || cv_fail "expected 404 got $CV_HTTP_STATUS" $LINENO
if printf '%s' "$CV_HTTP_BODY" | jq -e 'type == "object" and has("product")' >/dev/null 2>&1; then
  cv_fail "expected no product in response got $CV_HTTP_BODY" $LINENO
fi
printf '%s' "$CV_HTTP_BODY" | grep -qi 'not found' || cv_fail "expected not-found message got $CV_HTTP_BODY" $LINENO

# Cleanup
cv_step Cleanup "nothing was created" $LINENO
echo "no data to remove"

echo "CODEVALID_TEST_ASSERTION_OK:api_50765553_3"
