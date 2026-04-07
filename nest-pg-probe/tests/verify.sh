#!/bin/bash
# Verifies the /checkdb endpoint returns expected JSON response

BASE_URL="${1:-http://localhost:8080}"

response=$(curl -s "$BASE_URL/checkdb")
status=$(echo "$response" | grep -o '"connected":true' || true)
result=$(echo "$response" | grep -o '"status":1' || true)

if [ -n "$status" ] && [ -n "$result" ]; then
    echo "TEST PASSED"
else
    echo "TEST FAILED"
    echo "Response: $response"
fi