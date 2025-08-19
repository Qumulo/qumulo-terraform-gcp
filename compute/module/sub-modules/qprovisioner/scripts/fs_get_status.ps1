param (
    [string]$key,
    [string]$project,
    [string]$database,
    [string]$collection,
    [string]$token,
    [string]$new_cluster
)

function Get-FirestoreMonthValue {
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
    $month = (Get-Date).ToString("MMM", [System.Globalization.CultureInfo]::InvariantCulture)
    $url = "https://firestore.googleapis.com/v1/projects/$project/databases/$database/documents/$collection/$key"

    while ($attempt -lt $maxRetries) {
        try {
            $headers = @{
                "Authorization" = "Bearer $token"
                "Content-Type"  = "application/json"
            }

            $response = Invoke-RestMethod -Uri $url -Headers $headers -Method GET -TimeoutSec 5 -ErrorAction Stop

            if ($response -and $response.fields) {
                $matchingField = $response.fields.PSObject.Properties |
                    Where-Object { $_.Name -like "$month*" -and $_.Value.stringValue } |
                    Sort-Object Name |
                    Select-Object -Last 1

                if ($matchingField) {
                    return $matchingField.Value.stringValue
                }
            }
        } catch {
            # Ignore and retry
        }

        Start-Sleep -Seconds $delay
        $delay = $delay * 2 + (Get-Random -Maximum 2)
        $attempt++
    }

    exit 1
}

$output = Get-FirestoreMonthValue -key $key -project $project -database $database -collection $collection -token $token -new_cluster $new_cluster

@{ value = $output } | ConvertTo-Json -Compress
