function Get-ChiaWatchdog {
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
    $Watchdogs = Get-ChildItem -Path $WatchdogPath -Filter "$Name*.xml"
    foreach ($watchdog in $Watchdogs){
        try{
            Import-Clixml $watchdog.FullName
        }
        catch{
            Write-Error "Unable to import watchdog [$($watchdog.Name))]"
        }
    }
}