#!/bin/bash -e
maxtime=0

status() {
  local project=$1 database=$2 collection=$3 token=$4
  local output
  local month

  month=$(date +"%b")

  output=$(curl -s -X GET \
  -H "Authorization: Bearer $token" \
  -H "Content-Type: application/json" \
  "https://firestore.googleapis.com/v1/projects/$project/databases/$database/documents/$collection/last-run-status" \
  | tr -d '\n' | grep -oE '"'$month'_[^"]+":\s*\{\s*"stringValue":\s*"[^"]*"' | sort | tail -n 1 | cut -d':' -f3-6 | tr -d '"')
  echo $output
}

latest=$(status "${project}" "${database}" "${collection}" "${token}")

while [ "$latest" = "Shutting down provisioning instance" ] || [ "$latest" = "null" ]; do
  echo "Waiting for boot..."
  sleep 10        
  latest=$(status "${project}" "${database}" "${collection}" "${token}")
done

while [ "$latest" != "Shutting down provisioning instance" ]; do
  sleep 10

  latest=$(status "${project}" "${database}" "${collection}" "${token}")
  echo $latest

  maxtime=$(( $maxtime + 10 ))
  if [ $maxtime -gt 2700 ]; then
    echo "****************Cluster Provisioning FAILED****************"
    echo "Look in project=${project} at GCE Firestore  ${database}/${collection}/last-run-status to see what stage it failed at.  You may resolve the issue and manually restart it."
    echo "For more detailed analysis review the GCE provisioning instance ${gce_instance_name} log to troubleshoot"
  fi
done

echo "*****CNQ Cluster Successfully Provisioned*****"
