function Start-ChiaFlexPoolWatchdog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ArgumentCompleter({
            Get-ChiaWatchdog | where Name -like "*FlexPool*" | ForEach-Object {
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

    $Timer = $ChiaWatchDog.IntervalInMinutes * 60
    $MostRecentBlock = Get-fpMinerBlockReward @FlexPoolParameters | Sort-Object BlockNumber -Descending | Select-Object -First 1
    $LastPayment = Get-fpMinerPaymentsStats @FlexPoolParameters | Select-Object -ExpandProperty Lastpayment
    $blocksMined = Get-fpMinerBlock @FlexPoolParameters -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Blocks
    while ($true){
        $DiscordFacts = New-Object -TypeName System.Collections.Generic.List[Object]

        if ($ChiaWatchDog.NewBlockEnabled){
            $newblocksMined = Get-fpMinerBlock @FlexPoolParameters -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Blocks
            if (($blocksMined | Measure-Object).count -lt ($newblocksMined | Measure-Object).Count){
                $block = $newblocksMined | Sort-Object -Property TimeStamp -Descending | Select-Object -first 1
                $message = ":hash: Block Number: $($block.number)`n"
                $message += ":date:TimeStamp: $($block.timestamp)`n"
                $message += ":four_leaf_clover:Luck = $([math]::round($block.luck,2))`n"
                $message += ":card_box:Hash $($block.hash)`n"
                $blocksMined = $newblocksMined
                $DiscordFacts.Add((New-DiscordFact -Name ':pick: You Mined A Block!! :pick:' -Value $message -Inline $false))
            }
        }

        if ($ChiaWatchDog.StaleSharePercentageEnabled){
            $Stats = Get-fpMinerStats @FlexPoolParameters
            $Percentage = [math]::round($Stats.staleShares / $stats.validShares * 100,2)
            if ($Percentage -ge $ChiaWatchDog.StaleSharePercentage){
                $DiscordFacts.Add((New-DiscordFact -Name ':warning: Stale Shares :warning:' -Value "Stale Shares: $Percentage%" -Inline $false))
            }
        } #if stale shares

        if ($ChiaWatchDog.WorkerOfflineEnabled){
            $WorkersOffline = Get-fpMinerWorker @FlexPoolParameters | where isOnline -eq $false
            if ($null -ne $WorkersOffline){
                $WorkersOffline | ForEach-Object -Begin {$message = "Total Workers Offline: $(($WorkersOffline | Measure).Count)"} -Process {
                    $Message += "`nWorker $($_.Name) is offline"
                }
                $DiscordFacts.Add((New-DiscordFact -Name ':warning: Workers Offline Warning :warning:' -Value $message -Inline $false))
            }
        } # if worker offline

        if ($ChiaWatchDog.NewBlockRewardEnabled){
            $NewestBlockReward = Get-fpMinerBlockReward @FlexPoolParameters | where BlockNumber -gt $MostRecentBlock.BlockNumber | Sort-Object BlockNumber -Descending
            foreach ($newblock in $NewestBlockReward){
                if ($newblock.Confirmed -eq $true){
                    $confirmemoji = ":white_check_mark:"
                }
                else{
                    $confirmemoji = ":x:"
                }
                $Message = ":hash:BlockNumber: $($newblock.BlockNumber)`n"
                $Message += ":bar_chart:Share: $($newblock.Share)`n"
                $Message += ":seedling:Reward: $($newblock | ConvertFrom-CoinBaseUnit) xch`n"
                $Message += ":date:TimeStamp: $($newblock.TimeStamp)`n"
                $Message += "$($confirmemoji)Confirmed: $($newblock.Confirmed)`n`n"
                $DiscordFacts.Add((New-DiscordFact -Name ':gift: New Block Reward! :gift:' -Value $message -Inline $false))
            }
            $MostRecentBlock = $NewestBlockReward | Select-Object -First 1
        } # if block reward

        if ($ChiaWatchDog.PaymentsEnabled){
            $payments = Get-fpMinerPayment @FlexPoolParameters -ErrorAction SilentlyContinue
            $overview = $false
            if ($null -ne $payments){
                $paymentStats = Get-fpMinerPaymentsStats @FlexPoolParameters
                if ($null -eq $LastPayment -and $null -ne $paymentStats){
                    $LastPayment = $paymentStats.Lastpayment
                    $LastPayment | ForEach-Object {
                        $message = ":date:TimeStamp: $($LastPayment.TimeStamp)`n"
                        $message += ":seedling:XCH Paid: $($LastPayment | ConvertFrom-CoinBaseUnit -CoinTicker XCH)`n"
                        $message += ":dollar:Fiat Paid: $($LastPayment.fiatvalue.ToString("c"))`n"
                        $message += ":hourglass:Duration: $($LastPayment.duration.ToString("dd' days 'hh' hours '"))`n`n"
                    }
                    $overview = $true
                    $DiscordFacts.Add((New-DiscordFact -Name ":moneybag: New Payment! :moneybag:" -Value $message -Inline $false))
                }
                if ($null -ne $paymentStats -and $null -ne $payments){
                    $payments.payments | where {$_.timestamp -gt $LastPayment.timestamp} | ForEach-Object -Process {
                        $message = ":date:TimeStamp: $($_.TimeStamp)`n"
                        $message += ":seedling:XCH Paid: $($_ | ConvertFrom-CoinBaseUnit -CoinTicker XCH)`n"
                        $message += ":dollar:Fiat Paid: $($_.fiatvalue.ToString("c"))`n"
                        $message += ":hourglass:Duration: $($_.duration.ToString("dd' days 'hh' hours '"))`n`n"
                        $DiscordFacts.Add((New-DiscordFact -Name ":moneybag: New Payment! :moneybag:" -Value $message -Inline $false))
                        $overview = $true
                    }
                }
                if ($null -ne $paymentStats -and $overview -eq $true){
                    $message = ":deciduous_tree:Total XCH Paid: $(ConvertFrom-CoinBaseUnit -CoinTicker XCH -Value $paymentStats.stats.totalPaid)`n"
                    $message += ":moneybag:Total Fiat Paid: $($paymentStats.stats.TotalFiatPaid.ToString("c"))`n"
                    $message += ":wastebasket:Total Fees: $($paymentStats.stats.TotalFees)`n`n"
                    $DiscordFacts.Add((New-DiscordFact -Name ":coin: Payment Stats! :coin:" -Value $message -Inline $false))
                }
                $LastPayment = $paymentStats
            }
        } #if Payments

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