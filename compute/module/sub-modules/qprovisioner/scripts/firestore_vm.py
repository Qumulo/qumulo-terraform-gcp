#!/usr/bin/env python3
"""
CNQ Firestore Client for Remote VM Execution

This module provides Firestore operations for CNQ deployment VMs.
Uses only Python standard library - no external dependencies.

Functions provided:
- gettoken() → get_token()
- fsget() → get_document()
- fsput() → put_document()
- fsstat() → put_status_with_timestamp()
"""

import json
import subprocess
import sys
import urllib.request
import urllib.parse
import urllib.error
from datetime import datetime
import time

class FirestoreVMClient:
    """
    Firestore client using only Python standard library.
    Designed for VM environments with controlled dependencies.
    """

    def __init__(self):
        self.base_url = "https://firestore.googleapis.com/v1"

    def _get_access_token(self):
        """Get access token using gcloud CLI (available on GCP VMs)"""
        try:
            # Use gcloud to get access token
            cmd = [
                'gcloud', 'auth', 'print-access-token',
                '--quiet'
            ]
            result = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                timeout=30
            )

            if result.returncode != 0:
                print(f"Error getting access token: {result.stderr}", file=sys.stderr)
                return None

            return result.stdout.strip()

        except subprocess.TimeoutExpired:
            print("Timeout getting access token", file=sys.stderr)
            return None

        except Exception as e:
            print(f"Exception getting access token: {e}", file=sys.stderr)
            return None

    def _make_request(self, url, method='GET', data=None, headers=None):
        """Make HTTP request using urllib"""
        try:
            if headers is None:
                headers = {}

            # Add access token
            token = self._get_access_token()
            if not token:
                return None

            headers['Authorization'] = f'Bearer {token}'
            headers['Content-Type'] = 'application/json'

            # Prepare request
            if data:
                data = json.dumps(data).encode('utf-8')

            req = urllib.request.Request(url, data=data, headers=headers, method=method)

            # Make request
            with urllib.request.urlopen(req, timeout=30) as response:
                if response.status in [200, 201]:
                    return json.loads(response.read().decode('utf-8'))
                else:
                    print(f"HTTP {response.status}: {response.read().decode('utf-8')}", file=sys.stderr)
                    return None

        except urllib.error.HTTPError as e:
            if e.code == 404:
                # Document not found is normal for some operations
                return None
            else:
                print(f"HTTP Error {e.code}: {e.read().decode('utf-8')}", file=sys.stderr)
                return None

        except Exception as e:
            print(f"Request error: {e}", file=sys.stderr)
            return None

    def get_token(self, project, database, collection):
        """
        Get authentication token for Firestore operations.
        Returns a simple token based on project/database/collection.
        """
        if not all([project, database, collection]):
            print("Error: project, database, and collection are required", file=sys.stderr)
            return None

        # For this implementation, we'll create a simple token
        # that encodes the project/database/collection info
        token_data = f"{project}:{database}:{collection}"
        return token_data

    def get_document(self, key, project, database, collection, token):
        """
        Get a document from Firestore.
        Returns document value or 'null' if not found.
        """
        if not all([key, project, database, collection, token]):
            print("Error: all parameters are required", file=sys.stderr)
            return "null"

        try:
            # Build document path
            doc_path = f"projects/{project}/databases/{database}/documents/{collection}/{key}"
            url = f"{self.base_url}/{doc_path}"

            response = self._make_request(url)

            if response is None:
                return "null"

            # Extract value from Firestore document format
            if 'fields' in response and key in response['fields']:
                field_value = response['fields'][key]
                if 'stringValue' in field_value:
                    return field_value['stringValue']
                elif 'integerValue' in field_value:
                    return field_value['integerValue']
                elif 'doubleValue' in field_value:
                    return field_value['doubleValue']

            return "null"

        except Exception as e:
            print(f"Error getting document: {e}", file=sys.stderr)
            return "null"

    def put_document(self, key, project, database, collection, token, value):
        """
        Put a document to Firestore.
        Returns True if successful, False otherwise.
        """
        if not all([key, project, database, collection, token, value is not None]):
            print("Error: all parameters are required", file=sys.stderr)
            return False

        try:
            # Build document path
            doc_path = f"projects/{project}/databases/{database}/documents/{collection}/{key}"
            url = f"{self.base_url}/{doc_path}"

            # Prepare document data with field name matching document key
            doc_data = {
                "fields": {
                    key: {"stringValue": str(value)}
                }
            }

            response = self._make_request(url, method='PATCH', data=doc_data)
            return response is not None

        except Exception as e:
            print(f"Error putting document: {e}", file=sys.stderr)
            return False

    def put_status_with_timestamp(self, project, database, collection, token, status):
        """
        Put a timestamped status field to the last-run-status document in Firestore.
        Uses month-prefixed timestamp as the field key (e.g., "Jul_17_123456").
        """
        if not all([project, database, collection, token, status]):
            print("Error: all parameters are required", file=sys.stderr)
            return False

        try:
            # Create month-prefixed timestamp key that matches what status.sh expects
            now = datetime.now()
            month = now.strftime("%b")  # e.g., "Jul"
            timestamp = now.strftime("%d_%H%M%S")  # e.g., "17_123456"
            field_key = f"{month}_{timestamp}"

            # Build document path for last-run-status
            doc_path = f"projects/{project}/databases/{database}/documents/{collection}/last-run-status"
            url = f"{self.base_url}/{doc_path}"

            # Get existing document to preserve other fields
            existing_doc = self._make_request(url)
            if existing_doc is None:
                # Document doesn't exist, create with minimal structure
                fields = {"last-run-status": {"stringValue": "null"}}
            else:
                # Preserve existing fields
                fields = existing_doc.get("fields", {})

            # Add the new timestamped status field
            fields[field_key] = {"stringValue": str(status)}

            # Prepare document data
            doc_data = {"fields": fields}

            response = self._make_request(url, method='PATCH', data=doc_data)
            return response is not None

        except Exception as e:
            print(f"Error putting status: {e}", file=sys.stderr)
            return False

def main():
    """Command line interface"""
    if len(sys.argv) < 2:
        print("Usage:")
        print("  python3 firestore_vm.py get-token PROJECT DATABASE COLLECTION")
        print("  python3 firestore_vm.py get KEY PROJECT DATABASE COLLECTION TOKEN")
        print("  python3 firestore_vm.py put KEY PROJECT DATABASE COLLECTION TOKEN VALUE")
        print("  python3 firestore_vm.py put-status PROJECT DATABASE COLLECTION TOKEN STATUS")
        sys.exit(1)

    client = FirestoreVMClient()
    command = sys.argv[1]

    try:
        if command == "get-token":
            if len(sys.argv) != 5:
                print("Usage: get-token PROJECT DATABASE COLLECTION", file=sys.stderr)
                sys.exit(1)
            result = client.get_token(sys.argv[2], sys.argv[3], sys.argv[4])

        elif command == "get":
            if len(sys.argv) != 7:
                print("Usage: get KEY PROJECT DATABASE COLLECTION TOKEN", file=sys.stderr)
                sys.exit(1)
            result = client.get_document(sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5], sys.argv[6])

        elif command == "put":
            if len(sys.argv) != 8:
                print("Usage: put KEY PROJECT DATABASE COLLECTION TOKEN VALUE", file=sys.stderr)
                sys.exit(1)
            success = client.put_document(sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5], sys.argv[6], sys.argv[7])
            result = "OK" if success else "ERROR"

        elif command == "put-status":
            if len(sys.argv) != 7:
                print("Usage: put-status PROJECT DATABASE COLLECTION TOKEN STATUS", file=sys.stderr)
                sys.exit(1)
            success = client.put_status_with_timestamp(sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5], sys.argv[6])
            result = "OK" if success else "ERROR"

        else:
            print(f"Unknown command: {command}", file=sys.stderr)
            sys.exit(1)

        if result:
            print(result)

    except KeyboardInterrupt:
        print("\nInterrupted", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    main()