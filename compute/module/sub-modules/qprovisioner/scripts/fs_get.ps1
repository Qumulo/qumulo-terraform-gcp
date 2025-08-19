param (
    [string]$key,
    [string]$project,
    [string]$database,
    [string]$collection,
    [string]$token,
    [string]$new_cluster
)

function Get-FirestoreValue {
    param (
        [string]$key,
        [string]$project,
        [string]$database,
        [string]$collection,
        [string]$token,
        [string]$new_cluster
    )

    if ($new_cluster -eq "true") {
        return ""
    }

    $maxRetries = 5
    $delay = 1
    $attempt = 0

    while ($attempt -lt $maxRetries) {
        try {
            $url = "https://firestore.googleapis.com/v1/projects/$project/databases/$database/documents/$collection/$key"
            $headers = @{
                "Authorization" = "Bearer $token"
                "Content-Type"  = "application/json"
            }

            $response = Invoke-RestMethod -Uri $url -Headers $headers -Method GET -TimeoutSec 5 -ErrorAction Stop

            if ($response -and $response.fields) {
                $field = $response.fields.PSObject.Properties |
                    Where-Object { $_.Name -eq $key } |
                    ForEach-Object { $_.Value.stringValue }

                if ($field) {
                    return $field
                }
            }

        } catch {
            # Do nothing, retry silently
        }

        Start-Sleep -Seconds $delay
        $delay = $delay * 2 + (Get-Random -Maximum 2)
        $attempt++
    }

    exit 1
}

$value = Get-FirestoreValue -key $key -project $project -database $database -collection $collection -token $token -new_cluster $new_cluster

@{ value = $value } | ConvertTo-Json -Compress
