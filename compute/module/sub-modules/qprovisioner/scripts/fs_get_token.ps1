param (
    [string]$project,
    [string]$database,
    [string]$collection
)

function Get-FirestoreToken {
    param (
        [string]$project,
        [string]$database,
        [string]$collection
    )

    $delay = 1
    $token = $null

    for ($i = 1; $i -le 5; $i++) {
        try {
            $token = & gcloud auth application-default print-access-token 2>$null
            $token = $token.Trim()
        } catch {
            $token = $null
        }

        if (![string]::IsNullOrEmpty($token)) {
            break
        }

        Start-Sleep -Seconds 2
    }

    if ([string]::IsNullOrEmpty($token)) {
        exit 1
    }

    for ($i = 1; $i -le 3; $i++) {
        try {
            $url = "https://firestore.googleapis.com/v1/projects/$project/databases/$database/documents/$collection"
            $headers = @{ "Authorization" = "Bearer $token" }

            $response = Invoke-WebRequest -Uri $url -Headers $headers -Method GET -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
            $status = $response.StatusCode
        } catch {
            $status = $_.Exception.Response.StatusCode.Value__
        }

        if ($status -eq 200) {
            return $token
        }

        Start-Sleep -Seconds $delay
        $delay = $delay * 2 + (Get-Random -Maximum 2)
    }

    exit 1
}

$token = Get-FirestoreToken -project $project -database $database -collection $collection

if ([string]::IsNullOrEmpty($token)) {
    exit 1
}

# Output only valid JSON
@{ value = $token } | ConvertTo-Json -Compress
