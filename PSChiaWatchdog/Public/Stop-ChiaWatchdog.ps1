function Stop-ChiaWatchdog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory,ValueFromPipeline,ValueFromPipelineByPropertyName)]
        [ArgumentCompleter({
            Get-ChiaWatchdog | ForEach-Object {
                "`"$($_.Name)`""
            }
        })]
        [string]$Name
    )

    Process{
        $Process = Get-CimInstance -ClassName win32_process -Filter "CommandLine LIKE '%$Name%'"
        if ($null -ne $Process){
            try{
                Stop-Process -Id $Process.ProcessId -ErrorAction Stop
                Write-Host "$Name has been successfully stopped! PID = $($Process.ProcessId)" -ForegroundColor Green
            }
            catch{
                Write-Error "Unable to stop process: $($_.Exception.Message)"
            }
        }
    }
}