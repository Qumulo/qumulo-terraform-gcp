#!/bin/bash -e

key=$1
project=$2
database=$3
collection=$4
token=$5
new_cluster=$5

fsget () {
  local key=$1 project=$2 database=$3 collection=$4 token=$5 new_cluster=$6
  local output
  local max_retries=5
  local delay=1
  local attempt=0
  local raw_response
  local month=$(date +"%b")

  while (( attempt < max_retries )); do

    if [ "$new_cluster" == "true" ]; then
      echo ""
      return 0
    else
      raw_response=$(curl -sS --fail --connect-timeout 5 \
        -X GET \
        -H "Authorization: Bearer $token" \
        -H "Content-Type: application/json" \
        "https://firestore.googleapis.com/v1/projects/$project/databases/$database/documents/$collection/$key")

      if [[ $? -eq 0 && -n "$raw_response" ]]; then
        output=$(echo "$raw_response" | tr -d '\n' | grep -oE '"'$month'_[^"]+":\s*\{\s*"stringValue":\s*"[^"]*"' | sort | tail -n 1 | cut -d':' -f3-6 | tr -d '"' | xargs)
        echo $output
        return 0
      fi
    fi

    sleep $delay
    delay=$((delay * 2 + RANDOM % 2))  # Exponential backoff with jitter
    ((attempt++))
  done

  echo "Error: Failed to fetch Firestore value after $max_retries attempts." >&2
  return 1
}

output=$(fsget "$key" "$project" "$database" "$collection" "$token" "$new_cluster" 2>/dev/null)

echo "{\"value\": \"$output\"}"
