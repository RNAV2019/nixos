#!/usr/bin/env bash
set -euo pipefail

: "${OPENROUTER_API_KEY:?OPENROUTER_API_KEY is required}"
: "${API_RESPONSE_QUEUE:?API_RESPONSE_QUEUE is required}"
: "${API_CALLS_FILE:?API_CALLS_FILE is required}"
: "${API_REQUEST_DIR:?API_REQUEST_DIR is required}"

request_file=${1:?request file is required}
count=0
if [[ -s "$API_CALLS_FILE" ]]; then
  IFS= read -r count < "$API_CALLS_FILE"
fi
count=$((count + 1))
printf '%s\n' "$count" > "$API_CALLS_FILE"
cp "$request_file" "$API_REQUEST_DIR/request-$count.json"

mapfile -t responses < "$API_RESPONSE_QUEUE"
response=${responses[0]:-__EMPTY__}
: > "$API_RESPONSE_QUEUE"
for ((index = 1; index < ${#responses[@]}; index++)); do
  printf '%s\n' "${responses[$index]}" >> "$API_RESPONSE_QUEUE"
done

case "$response" in
  __HTTP_500__)
    printf '%s\n' '{"error":{"message":"test server failure"}}'
    printf '500\n'
    ;;
  __MALFORMED__)
    printf '%s\n' 'not json'
    printf '200\n'
    ;;
  __EMPTY__)
    jq -cn '{choices:[{finish_reason:"stop",message:{content:""}}]}'
    printf '200\n'
    ;;
  *)
    jq -cn --arg content "$response" \
      '{choices:[{finish_reason:"stop",message:{content:$content}}]}'
    printf '200\n'
    ;;
esac
