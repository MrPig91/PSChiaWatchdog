param(
    [ValidateScript({Test-Path $_})]
    [string]$HarvesterPath = "$ENV:LOCALAPPDATA\PSChiaWatchdog\HarvesterSummaryLog.csv",
    [string]$FarmerPath = "$ENV:LOCALAPPDATA\PSChiaWatchdog\FarmerSummaryLog.csv",
    [int]$Interval = 60, #In Minutes
    [switch]$ToastNotification,
    [switch]$DiscordNotification
)
$DiscordUri = "Place Discord Uri Here"

$IntervalInSeconds = $Interval * 60

while ($true){
    $HarvesterEvents = Import-Csv -path $HarvesterPath | foreach {
        $_.Time = [datetime]$_.Time
        $_
    }
    $FarmerEvents = Import-Csv -path $FarmerPath | foreach {
        $_.Time = [datetime]$_.Time
        $_
    }

    $HarvesterEvents = $HarvesterEvents | where Time -GT (Get-Date).AddMinutes(-$Interval)
    $FarmerEvents = $FarmerEvents | where Time -GT (Get-Date).AddMinutes(-$Interval)
    if ($HarvesterEvents){
        $LookUpStats = $HarvesterEvents | Measure-Object -property LookUpTime -Minimum -Maximum -Average
        $ProofsFound = ($HarvesterEvents | Measure-Object -property ProofsFound -Sum).Sum
        $PassFilter = ($HarvesterEvents | Measure-Object -property FilterRatio -average).Average

        $Message = "Attempted Proofs: $($HarvesterEvents.Count)"
        $Message += "`nLookUpTime Stats"
        $Message += "`nMin: $([math]::Round($LookUpStats.Minimum,3)) | Max: $([math]::Round($LookUpStats.Maximum,3)) | Avg: $([math]::Round($LookUpStats.Average,3))"
        $Message += "`nFilterRatio $([math]::Round($PassFilter,4)) | Proofs: $ProofsFound | Farmed: $(($FarmerEvents | Measure-Object).Count)"
        if ($ToastNotification){
            New-BurntToastNotification -Text $Message -AppLogo $PSScriptRoot\chialeaf.png
        }
        if ($DiscordNotification){
            $PayLoad = [PSCustomObject]@{content = $Message} | ConvertTo-Json
            Invoke-RestMethod -Method Post -ContentType 'application/json' -Body $PayLoad -uri $DiscordUri
        }
    }
    Start-Sleep -seconds $IntervalInSeconds
}
