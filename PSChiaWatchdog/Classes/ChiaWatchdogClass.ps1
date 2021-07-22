class ChiaFlexPoolWatchdog {
    [string]$Name
    [int]$IntervalInMinutes
    [string]$Address
    [string]$DiscordUri
    [string]$Type
    
    [bool]$StaleSharePercentageEnabled = $false
    [int]$StaleSharePercentage = 5

    [bool]$WorkerOfflineEnabled = $false

    [bool]$NewBlockRewardEnabled = $false

    [bool]$SummaryEnabled = $false

    [bool]$PaymentsEnabled = $false

    [bool]$NewBlockEnabled = $false

    ChiaFlexPoolWatchdog(
        [string]$Name,
        [int]$IntervalInMinutes,
        [string]$Address,
        [string]$DiscordUri,
        [string]$Type
    ){
        $this.Name = $Name
        $this.IntervalInMinutes = $IntervalInMinutes
        $this.Address = $Address
        $this.DiscordUri = $DiscordUri
        $this.Type = $Type
    }
}