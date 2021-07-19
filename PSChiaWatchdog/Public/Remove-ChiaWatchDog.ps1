function Remove-ChiaWatchdog {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline,ValueFromPipelineByPropertyName)]
        [ArgumentCompleter({
            Get-ChiaWatchdog | ForEach-Object {
                "`"$($_.Name)`""
            }
        })]
        [string]$Name
    )

    $WatchdogPath = "$ENV:LOCALAPPDATA\PSChiaWatchdog\Watchdogs"
    $Watchdog = Get-Item -Path "$WatchdogPath\$Name.xml" -ErrorAction Stop
    $Watchdog | Remove-Item -ErrorAction Stop
}