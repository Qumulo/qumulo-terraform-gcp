param (
    [string]$project = "${project}",
    [string]$database = "${database}",
    [string]$collection = "${collection}",
    [string]$token = "${token}",
    [string]$gce_instance_name = "${gce_instance_name}"
)

    $maxtime = 0

function Get-LastRunStatus {
    param (
        [string]$project,
        [string]$database,
        [string]$collection,
        [string]$token
    )

    $maxRetries = 5
    $delay = 1
    $attempt = 0
    $month = (Get-Date).ToString("MMM", [System.Globalization.CultureInfo]::InvariantCulture)
    $url = "https://firestore.googleapis.com/v1/projects/$project/databases/$database/documents/$collection/last-run-status"
    #Write-Host "Calling Firestore URL: $url"

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


$latest = Get-LastRunStatus -project $project -database $database -collection $collection -token $token

while ($latest -eq "Shutting down provisioning instance" -or $latest -eq "null") {
    Write-Host "Waiting for boot..."
    Start-Sleep -Seconds 10
    $latest = Get-LastRunStatus -project $project -database $database -collection $collection -token $token
}

while ($latest -ne "Shutting down provisioning instance") {
    Start-Sleep -Seconds 10
    $latest = Get-LastRunStatus -project $project -database $database -collection $collection -token $token
    Write-Host $latest
    $maxtime += 10

    if ($maxtime -gt 2700) {
        Write-Host "****************Cluster Provisioning FAILED****************" -ForegroundColor Red
        Write-Host "Look in project=$project at GCE Firestore $database/$collection/last-run-status to see what stage it failed at."
        Write-Host "You may resolve the issue and manually restart it."
        Write-Host "For more detailed analysis, review the GCE provisioning instance log: $gce_instance_name"
        exit 1
    }
}

Write-Host "*****CNQ Cluster Successfully Provisioned*****" -ForegroundColor Green
