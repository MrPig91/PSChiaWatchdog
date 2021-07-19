function New-ChiaFlexPoolWatchdog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name,
        [Parameter(Mandatory)]
        [ValidateRange(1,1440)]
        [int]$IntervalInMinutes,
        [Parameter(Mandatory)]
        [Alias("LauncherId","PayoutAddress")]
        [string]$Address,
        [Parameter(Mandatory)]
        [string]$DiscordUri,

        [switch]$StaleSharePercentageEnabled,
        [int]$StaleSharePercentage = 5,

        [switch]$WorkerOfflineEnabled,

        [switch]$NewBlockRewardEnabled,

        [switch]$SummaryEnabled
    )

    try{
        $PSChiaWatchdogPath = "$ENV:LOCALAPPDATA\PSChiaWatchdog"
        $WatchdogsPath = "$ENV:LOCALAPPDATA\PSChiaWatchdog\Watchdogs"
        if (-not(Test-Path $PSChiaWatchdogPath)){
            [void](New-Item -Path $PSChiaWatchdogPath -ItemType Directory)
        }
        if (-not(Test-Path $WatchdogsPath)){
            [void](New-Item -Path $WatchdogsPath -ItemType Directory)
        }
        $Name += "-FlexPool"
        $ChiaWatchdog = [ChiaFlexPoolWatchdog]::new($Name,$IntervalInMinutes,$Address,$DiscordUri,"FlexPool")
        $ChiaWatchdog.StaleSharePercentageEnabled = $StaleSharePercentageEnabled.IsPresent
        $ChiaWatchdog.StaleSharePercentage = $StaleSharePercentage
        $ChiaWatchdog.WorkerOfflineEnabled = $WorkerOfflineEnabled.IsPresent
        $ChiaWatchdog.NewBlockRewardEnabled = $NewBlockRewardEnabled.IsPresent
        $ChiaWatchdog.SummaryEnabled = $SummaryEnabled.IsPresent
        Export-Clixml -InputObject $ChiaWatchdog -Path "$WatchdogsPath\$Name.xml" -Force -Depth 5
        return $ChiaWatchdog
    }
    catch{
        $PSCmdlet.WriteError($_)
    }
}