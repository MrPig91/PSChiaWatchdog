function Start-ChiaFlexPoolWatchdog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ArgumentCompleter({
            Get-ChiaWatchdog | where Name -like "*FlexPool*" ForEach-Object {
                "`"$($_.Name)`""
            }
        })]
        [string]$Name,
        [Parameter(DontShow)]
        [switch]$NoNewWindow
    )

    try{
        $WatchdogPath = "$ENV:LOCALAPPDATA\PSChiaWatchdog\Watchdogs\$Name.xml"
        $ChiaWatchDog = Import-Clixml -Path $WatchdogPath
        $FlexPoolParameters = @{
            CoinTicker = "XCH"
            Address = $ChiaWatchDog.Address
        }
    }
    catch{
        Write-Error "Unable to find watchdog by the name $Name"
        return
    }

    if (-not$NoNewWindow.IsPresent){
        $parameters = @{
            FilePath = "powershell.exe"
            ArgumentList = "-NoExit -NoProfile -STA -Command Start-ChiaFlexPoolWatchdog -Name $Name -NoNewWindow"
            WindowStyle = "Hidden"
        }
        Start-Process @parameters -PassThru
        return
    }

    $Host.UI.RawUI.WindowTitle = $Name + "-Watchdog"
    $Timer = $ChiaWatchDog.IntervalInMinutes * 60
    $MostRecentBlock = Get-fpMinerBlockReward @FlexPoolParameters | Sort-Object BlockNumber -Descending | Select-Object -First 1
    while ($true){
        $DiscordFacts = New-Object -TypeName System.Collections.Generic.List[Object]
        if ($ChiaWatchDog.StaleSharePercentageEnabled){
            $Stats = Get-fpMinerStats @FlexPoolParameters
            $Percentage = [math]::round($Stats.staleShares / $stats.validShares * 100,2)
            if ($Percentage -ge $ChiaWatchDog.StaleSharePercentage){
                $DiscordFacts.Add((New-DiscordFact -Name 'Stale Shares :warning:' -Value "Stale Shares: $Percentage%" -Inline $false))
            }
        } #if stale shares

        if ($ChiaWatchDog.WorkerOfflineEnabled){
            $WorkersOffline = Get-fpMinerWorker @FlexPoolParameters | where isOnline -eq $false
            if ($null -ne $WorkersOffline){
                $WorkersOffline | ForEach-Object -Begin {$message = "Total Workers Offline: $(($WorkersOffline | Measure).Count)"} -Process {
                    $Message += "`nWorker $($_.Name) is offline"
                }
                $DiscordFacts.Add((New-DiscordFact -Name ':warning:Workers Offline Warning' -Value $message -Inline $false))
            }
        } # if worker offline

        if ($ChiaWatchDog.NewBlockRewardEnabled){
            $NewestBlockReward = Get-fpMinerBlockReward @FlexPoolParameters | Sort-Object BlockNumber -Descending | Select-Object -First 1
            if ($NewestBlockReward.BlockNumber -gt $MostRecentBlock.BlockNumber){
                if ($NewestBlockReward.Confirmed -eq $true){
                    $confirmemoji = ":white_check_mark:"
                }
                else{
                    $confirmemoji = ":x:"
                }
                $Message = ":hash:BlockNumber: $($NewestBlockReward.BlockNumber)`n"
                $Message += "`n:bar_chart:Share: $($NewestBlockReward.Share)`n"
                $Message += "`n:seedling:Reward: $($NewestBlockReward | ConvertFrom-CoinBaseUnit) xch`n"
                $Message += "`n:date:TimeStamp: $($NewestBlockReward.TimeStamp)`n"
                $Message += "`n$($confirmemoji)Confirmed: $($NewestBlockReward.Confirmed)`n"
                $DiscordFacts.Add((New-DiscordFact -Name 'New Block Reward! :gift:' -Value $message -Inline $false))
            }
            $MostRecentBlock = $NewestBlockReward
        } # if block reward

        if ($ChiaWatchDog.SummaryEnabled){
            $TB = [math]::Pow(10,12)
            $Balance = Get-fpMinerBalance @FlexPoolParameters
            $MinerStats = Get-fpMinerStats @FlexPoolParameters
            $CurrentRoundShare = Get-fpMinerRoundShare @FlexPoolParameters
            $Workers = Get-fpMinerWorker @FlexPoolParameters

            $Message = ":seedling: Balance: $($Balance | ConvertFrom-CoinBaseUnit) xhc`n"
            $message += ":dollar: Balance: `$$($Balance.USD)`n"
            $message += "`n:floppy_disk: Avg Hashrate: $($MinerStats.averageEffectiveHashrate / $TB) TB"
            $message += "`n:floppy_disk: Current Hashrate: $($MinerStats.currentEffectiveHashrate / $TB) TB`n"
            $message += "`n:white_check_mark: Valid Shares: $($MinerStats.validShares)"
            $message += "`n:snail: Stale Shares Count: $($MinerStats.staleShares)"
            $message += "`n:snail: Stale Shares: $([math]::Round(($MinerStats.staleShares / $minerStats.ValidShares * 100),2))%"
            $message += "`n:abacus: Current Round Share: $($CurrentRoundShare.RoundShare)`n"
            $message += "`n:hash: Workers Count: $(($Workers | Measure-Object).Count)"
            $message += "`n:white_check_mark: Workers Online: $(($Workers | where isOnline -eq $true | Measure-Object).Count)"
            $message += "`n:no_entry: Workers Offline: $(($Workers | where isOnline -eq $false | Measure-Object).Count)"

            $DiscordFacts.Add((New-DiscordFact -Name ':newspaper: Summary! :newspaper:' -Value $message -Inline $false))
        } #if summary

        if ($DiscordFacts.Count -gt 0){
            $Section = New-DiscordSection -Title ':seedling: FlexPool Alert :seedling:' -Description '' -Facts $DiscordFacts -Color BlueViolet -Author $Author
            Send-DiscordMessage -WebHookUrl $ChiaWatchDog.DiscordUri -Sections $Section -AvatarName 'ChiaFlexPoolWatchdog'
        }
        Start-Sleep -Seconds $Timer
    } #while loop
}