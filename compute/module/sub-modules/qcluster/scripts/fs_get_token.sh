#!/bin/bash -e

project=$1
database=$2
collection=$3

gettoken() {
  local project=$1 database=$2 collection=$3
  local token 
  local status 
  local delay=1

  # Try to get a usable token
  for ((i = 1; i <= 5; i++)); do
    echo "Attempt $i to get Firestore token..." >&2
    token=$(gcloud auth application-default print-access-token 2>/dev/null | tr -d '\n')

    if [[ -n "$token" ]]; then
      break
    fi

    echo "Failed to get valid token. Retrying..." >&2
    token=""
    sleep 2
  done

  if [[ -z "$token" ]]; then
    echo "Error: Could not obtain valid token after retries." >&2
    return 1
  fi

  # Validate token with Firestore
  for ((i = 1; i <= 3; i++)); do
    echo "Validating Firestore token (attempt $i)..." >&2
    status=$(curl -s -o /dev/null -w "%{http_code}" \
      -H "Authorization: Bearer $token" \
      "https://firestore.googleapis.com/v1/projects/$project/databases/$database/documents/$collection")

    if [[ "$status" == "200" ]]; then
      echo "Token is valid." >&2
      echo $token
      return 0
    fi

    echo "Token validation failed (HTTP $status). Retrying in $delay seconds..." >&2
    sleep $delay
    delay=$((delay * 2 + RANDOM % 2))
  done

  echo "Error: Token was acquired but could not be validated." >&2
  return 1
}

token=$(gettoken "$project" "$database" "$collection" 2>/dev/null)

if [[ -z "$token" ]]; then
  echo "Failed to get Firestore token" >&2
  exit 1
fi

echo "{\"value\": \"$token\"}"
