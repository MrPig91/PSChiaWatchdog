param(
    [ValidateScript({Test-Path $_})]
    [string]$DebugLogFilePath = "$ENV:USERPROFILE\.chia\mainnet\log\debug.log",
    [ValidateScript({[System.IO.Directory]::Exists((Split-Path -parent $_))})]
    [string]$SummaryLogDirectory = "$ENV:LOCALAPPDATA\PSChiaWatchdog"
)

#Regex strings
$chiaharvesterlog = "([0-9:.\-T]*) harvester chia.harvester.harvester: INFO\s*([0-9]*) plots were eligible for farming ([a-z0-9.]*) Found ([0-9]*) proofs. Time: ([0-9.]*) s. Total ([0-9]*) plots" 
$chiafarmerlog = "([0-9:.\-T]*) full_node chia.full_node.full_node: INFO\s*Farmed unfinished_block ([a-z0-9]*), SP: ([0-9]*)"

if (-not(Test-Path $SummaryLogDirectory)){
    New-Item $SummaryLogDirectory -ItemType Directory | out-null
}

Get-Content -Path $DebugLogFilePath -Wait | foreach-object {
    switch -Regex ($_){
        $chiaharvesterlog {
            $harvesterActivity = [pscustomobject]@{
                Time = [datetime]::parse($Matches[1])
                EligiblePlots = $Matches[2]
                LookUpTime = $Matches[5]
                ProofsFound = $Matches[4]
                TotalPlots = $Matches[6]
                FilterRatio = $Matches[2] / $Matches[6]
            }
            $harvesterActivity | export-csv -Path "$SummaryLogDirectory\HarvesterSummaryLog.csv" -NoTypeInformation -Append
        }
        $chiafarmerlog {
            $farmerActivity = [PSCustomObject]@{
                Time = [datetime]::parse($Matches[1])
                Activity = "Farmed unfinished_block"
                SP = $Matches[3]
            }
            $farmerActivity | Export-Csv -Path "$SummaryLogDirectory\FarmerSummaryLog.csv" -NoTypeInformation -Append
        }  
    }
}
