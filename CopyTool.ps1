# -*- coding: utf-8 -*-
# 資料夾批量複製工具 - PowerShell GUI版（網路斷線自動重試）
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

$script:copying = $false
$script:stopFlag = $false

# === 主視窗 ===
$form = New-Object System.Windows.Forms.Form
$form.Text = "資料夾批量複製工具"
$form.Size = New-Object System.Drawing.Size(720, 560)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedSingle"
$form.MaximizeBox = $false

# === 來源路徑 ===
$lblSrc = New-Object System.Windows.Forms.Label
$lblSrc.Text = "來源路徑 (複製從哪裡):"
$lblSrc.Location = New-Object System.Drawing.Point(15, 15)
$lblSrc.AutoSize = $true
$form.Controls.Add($lblSrc)

$txtSrc = New-Object System.Windows.Forms.TextBox
$txtSrc.Location = New-Object System.Drawing.Point(15, 35)
$txtSrc.Size = New-Object System.Drawing.Size(580, 25)
$form.Controls.Add($txtSrc)

$btnSrc = New-Object System.Windows.Forms.Button
$btnSrc.Text = "瀏覽..."
$btnSrc.Location = New-Object System.Drawing.Point(605, 33)
$btnSrc.Size = New-Object System.Drawing.Size(80, 27)
$form.Controls.Add($btnSrc)

# === 目標路徑 ===
$lblDst = New-Object System.Windows.Forms.Label
$lblDst.Text = "目標路徑 (複製到哪裡):"
$lblDst.Location = New-Object System.Drawing.Point(15, 70)
$lblDst.AutoSize = $true
$form.Controls.Add($lblDst)

$txtDst = New-Object System.Windows.Forms.TextBox
$txtDst.Location = New-Object System.Drawing.Point(15, 90)
$txtDst.Size = New-Object System.Drawing.Size(580, 25)
$form.Controls.Add($txtDst)

$btnDst = New-Object System.Windows.Forms.Button
$btnDst.Text = "瀏覽..."
$btnDst.Location = New-Object System.Drawing.Point(605, 88)
$btnDst.Size = New-Object System.Drawing.Size(80, 27)
$form.Controls.Add($btnDst)

# === 按鈕 ===
$btnStart = New-Object System.Windows.Forms.Button
$btnStart.Text = "開始複製"
$btnStart.Location = New-Object System.Drawing.Point(15, 125)
$btnStart.Size = New-Object System.Drawing.Size(90, 30)
$form.Controls.Add($btnStart)

$btnStop = New-Object System.Windows.Forms.Button
$btnStop.Text = "停止"
$btnStop.Location = New-Object System.Drawing.Point(115, 125)
$btnStop.Size = New-Object System.Drawing.Size(70, 30)
$btnStop.Enabled = $false
$form.Controls.Add($btnStop)

$lblStatus = New-Object System.Windows.Forms.Label
$lblStatus.Text = "就緒"
$lblStatus.Location = New-Object System.Drawing.Point(550, 132)
$lblStatus.Size = New-Object System.Drawing.Size(150, 20)
$lblStatus.TextAlign = "MiddleRight"
$lblStatus.ForeColor = [System.Drawing.Color]::Gray
$form.Controls.Add($lblStatus)

# === 進度條 ===
$progressBar = New-Object System.Windows.Forms.ProgressBar
$progressBar.Location = New-Object System.Drawing.Point(15, 165)
$progressBar.Size = New-Object System.Drawing.Size(670, 25)
$form.Controls.Add($progressBar)

$lblProgress = New-Object System.Windows.Forms.Label
$lblProgress.Text = ""
$lblProgress.Location = New-Object System.Drawing.Point(15, 193)
$lblProgress.Size = New-Object System.Drawing.Size(670, 20)
$form.Controls.Add($lblProgress)

# === 日誌 ===
$lblLog = New-Object System.Windows.Forms.Label
$lblLog.Text = "複製日誌:"
$lblLog.Location = New-Object System.Drawing.Point(15, 218)
$lblLog.AutoSize = $true
$form.Controls.Add($lblLog)

$txtLog = New-Object System.Windows.Forms.TextBox
$txtLog.Location = New-Object System.Drawing.Point(15, 238)
$txtLog.Size = New-Object System.Drawing.Size(670, 270)
$txtLog.Multiline = $true
$txtLog.ScrollBars = "Vertical"
$txtLog.ReadOnly = $true
$txtLog.Font = New-Object System.Drawing.Font("Consolas", 9)
$form.Controls.Add($txtLog)

# === 函數 ===
function Write-Log($msg) {
    $ts = (Get-Date).ToString("HH:mm:ss")
    $txtLog.AppendText("[$ts] $msg`r`n")
    $txtLog.ScrollToCaret()
    [System.Windows.Forms.Application]::DoEvents()
}

function Count-Files($path) {
    $count = 0
    try {
        $count = (Get-ChildItem -LiteralPath $path -Recurse -File -ErrorAction SilentlyContinue).Count
    } catch {}
    return $count
}

function Copy-SingleItem($srcPath, $dstPath, $name) {
    $maxRetries = 5
    $waitTimes = @(10, 30, 60, 120, 120)

    for ($attempt = 0; $attempt -lt $maxRetries; $attempt++) {
        if ($script:stopFlag) { return "STOPPED" }
        try {
            if (Test-Path -LiteralPath $dstPath) {
                Remove-Item -LiteralPath $dstPath -Recurse -Force -ErrorAction Stop
            }
            Copy-Item -LiteralPath $srcPath -Destination $dstPath -Recurse -Force -ErrorAction Stop
            return "OK"
        } catch {
            $errMsg = $_.Exception.Message
            if ($attempt -lt ($maxRetries - 1)) {
                $wait = $waitTimes[$attempt]
                Write-Log "網路錯誤 ($name): $errMsg"
                Write-Log "等待 ${wait} 秒後第 $($attempt+2) 次重試..."
                $lblStatus.Text = "等待重連 (${wait}秒)..."
                $lblStatus.ForeColor = [System.Drawing.Color]::Orange
                for ($w = 0; $w -lt $wait; $w++) {
                    if ($script:stopFlag) { return "STOPPED" }
                    Start-Sleep -Seconds 1
                    [System.Windows.Forms.Application]::DoEvents()
                }
            } else {
                return "FAIL: $errMsg"
            }
        }
    }
    return "FAIL"
}

# === 瀏覽按鈕事件 ===
$btnSrc.Add_Click({
    $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
    $dlg.Description = "選擇來源資料夾"
    if ($dlg.ShowDialog() -eq "OK") { $txtSrc.Text = $dlg.SelectedPath }
})

$btnDst.Add_Click({
    $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
    $dlg.Description = "選擇目標資料夾"
    if ($dlg.ShowDialog() -eq "OK") { $txtDst.Text = $dlg.SelectedPath }
})

# === 停止按鈕 ===
$btnStop.Add_Click({
    $script:stopFlag = $true
    $btnStop.Enabled = $false
    $lblStatus.Text = "正在停止..."
    $lblStatus.ForeColor = [System.Drawing.Color]::Orange
})

# === 開始複製按鈕 ===
$btnStart.Add_Click({
    $src = $txtSrc.Text.Trim().Trim('"')
    $dst = $txtDst.Text.Trim().Trim('"')

    if (-not $src -or -not $dst) {
        [System.Windows.Forms.MessageBox]::Show("請先設定來源和目標路徑", "提示", "OK", "Warning")
        return
    }
    if (-not (Test-Path -LiteralPath $src)) {
        [System.Windows.Forms.MessageBox]::Show("來源路徑不存在:`n$src", "錯誤", "OK", "Error")
        return
    }

    $script:copying = $true
    $script:stopFlag = $false
    $btnStart.Enabled = $false
    $btnStop.Enabled = $true
    $lblStatus.Text = "複製中..."
    $lblStatus.ForeColor = [System.Drawing.Color]::Blue
    $txtLog.Clear()

    # 確保目標存在
    if (-not (Test-Path -LiteralPath $dst)) {
        New-Item -ItemType Directory -Path $dst -Force | Out-Null
    }

    $allItems = Get-ChildItem -LiteralPath $src | Sort-Object Name
    $total = $allItems.Count

    Write-Log "來源: $src"
    Write-Log "目標: $dst"
    Write-Log "總共: $total 個項目，正在檢查子資料夾..."

    $progressBar.Minimum = 0
    $progressBar.Maximum = $total
    $progressBar.Value = 0

    # 檢查哪些需要複製
    $todo = @()
    $skippedCount = 0
    $checkIdx = 0
    foreach ($item in $allItems) {
        $checkIdx++
        $dPath = Join-Path $dst $item.Name
        $needCopy = $false
        $reason = ""

        if (-not (Test-Path -LiteralPath $dPath)) {
            $needCopy = $true
            $reason = "新項目"
        } elseif ($item.PSIsContainer) {
            $srcCount = Count-Files $item.FullName
            $dstCount = Count-Files $dPath
            if ($dstCount -lt $srcCount) {
                $needCopy = $true
                $reason = "不完整 ($dstCount/$srcCount 個檔案)"
            }
        }

        if ($needCopy) {
            $todo += [PSCustomObject]@{ Name=$item.Name; FullName=$item.FullName; Reason=$reason }
        } else {
            $skippedCount++
        }

        if ($checkIdx % 50 -eq 0) {
            $progressBar.Value = $checkIdx
            $lblProgress.Text = "檢查中... $checkIdx/$total"
            [System.Windows.Forms.Application]::DoEvents()
        }
    }

    Write-Log "已完成: $skippedCount | 需要複製: $($todo.Count)"
    $incomplete = ($todo | Where-Object { $_.Reason -ne "新項目" }).Count
    if ($incomplete -gt 0) { Write-Log "其中不完整需重新複製: $incomplete 個" }
    Write-Log ("-" * 50)

    $progressBar.Value = $skippedCount

    if ($todo.Count -eq 0) {
        Write-Log "全部已複製完成（含子資料夾檢查）!"
        $lblStatus.Text = "完成"
        $lblStatus.ForeColor = [System.Drawing.Color]::Green
        $btnStart.Enabled = $true
        $btnStop.Enabled = $false
        $script:copying = $false
        return
    }

    $copied = 0
    $failed = 0
    $failedItems = @()

    foreach ($item in $todo) {
        if ($script:stopFlag) {
            Write-Log "已停止。本次複製: $copied | 失敗: $failed"
            break
        }

        $dPath = Join-Path $dst $item.Name
        $num = $skippedCount + $copied + $failed + 1
        $pct = [math]::Round($num / $total * 100, 1)

        $lblStatus.Text = "($num/$total) $($item.Name)"
        $lblStatus.ForeColor = [System.Drawing.Color]::Blue
        $lblProgress.Text = "$num/$total ($pct%) [$($item.Reason)]"
        [System.Windows.Forms.Application]::DoEvents()

        $result = Copy-SingleItem $item.FullName $dPath $item.Name

        if ($result -eq "OK") {
            $copied++
            $cur = $skippedCount + $copied + $failed
            $progressBar.Value = $cur
            Write-Log "OK ($cur/$total) $($item.Name) [$($item.Reason)]"
        } elseif ($result -eq "STOPPED") {
            break
        } else {
            $failed++
            $failedItems += $item.Name
            $cur = $skippedCount + $copied + $failed
            $progressBar.Value = $cur
            Write-Log "FAIL ($cur/$total) $($item.Name): $result (已重試5次)"
        }
    }

    # 最終重試失敗項目
    if ($failedItems.Count -gt 0 -and -not $script:stopFlag) {
        Write-Log ("-" * 50)
        Write-Log "等待 60 秒後重試 $($failedItems.Count) 個失敗項目..."
        for ($w = 0; $w -lt 60; $w++) {
            if ($script:stopFlag) { break }
            Start-Sleep -Seconds 1
            [System.Windows.Forms.Application]::DoEvents()
        }

        $retryOk = 0
        foreach ($fname in @($failedItems)) {
            if ($script:stopFlag) { break }
            $sPath = Join-Path $src $fname
            $dPath = Join-Path $dst $fname
            Write-Log "重試: $fname ..."
            try {
                if (Test-Path -LiteralPath $dPath) { Remove-Item -LiteralPath $dPath -Recurse -Force }
                Copy-Item -LiteralPath $sPath -Destination $dPath -Recurse -Force -ErrorAction Stop
                $retryOk++
                $failedItems = $failedItems | Where-Object { $_ -ne $fname }
                Write-Log "重試成功: $fname"
            } catch {
                Write-Log "重試仍失敗: $fname : $($_.Exception.Message)"
            }
        }
        if ($retryOk -gt 0) {
            $copied += $retryOk
            $failed -= $retryOk
            Write-Log "重試成功: $retryOk 個"
        }
    }

    if (-not $script:stopFlag) {
        Write-Log "完成! 本次複製: $copied | 跳過: $skippedCount | 失敗: $failed | 總共: $total"
        if ($failedItems.Count -gt 0) {
            Write-Log "仍然失敗的項目:"
            foreach ($fn in $failedItems) { Write-Log "  - $fn" }
        }
    }

    $lblStatus.Text = "完成"
    $lblStatus.ForeColor = [System.Drawing.Color]::Green
    $btnStart.Enabled = $true
    $btnStop.Enabled = $false
    $script:copying = $false
})

# === 啟動 ===
[void]$form.ShowDialog()
