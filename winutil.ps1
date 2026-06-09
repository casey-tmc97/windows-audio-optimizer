# ============================================================
#  Audio PC Optimizer
#
#  Usage (run in an elevated PowerShell terminal):
#    irm https://raw.githubusercontent.com/casey-tmc97/windows-audio-optimizer/main/winutil.ps1 | iex
#
#  Or download and run locally:
#    powershell -ExecutionPolicy Bypass -File winutil.ps1
# ============================================================

#region ── Bootstrap: auto-elevate if not admin ───────────────────────────────

if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)) {

    Write-Host ""
    Write-Host "  Audio PC Optimizer" -ForegroundColor Cyan
    Write-Host "  Administrator rights required. Requesting elevation..." -ForegroundColor Yellow
    Write-Host ""

    $url = "https://raw.githubusercontent.com/casey-tmc97/windows-audio-optimizer/main/winutil.ps1"
    $cmd = "irm '$url' | iex"

    # Re-launch elevated
    Start-Process powershell.exe `
        -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command `"$cmd`"" `
        -Verb RunAs
    exit
}

#endregion

#region ── Assemblies ─────────────────────────────────────────────────────────

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Windows.Forms

#endregion

#region ── Data ───────────────────────────────────────────────────────────────

$Categories = @(
    @{
        Id    = "power"
        Label = "Power & CPU"
        Color = "#f59e0b"
        Items = @(
            @{ Id = "highperf";    Warn = $false; Label = "Set High Performance power plan";                    Detail = "Disables dynamic CPU scaling — locks clock speed at 100%. Falls back to creating a custom plan on Modern Standby systems.";
               Cmd = 'Write-Host "--- Setting Power Plan ---" -ForegroundColor Magenta
$hpGuid = "8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c"
$plans = powercfg -list 2>&1
if ($plans -match $hpGuid) {
    powercfg -setactive $hpGuid
    Write-Host "✓ High Performance power plan activated." -ForegroundColor Green
} else {
    $ng = (powercfg -duplicatescheme 381b4222-f694-41f0-9685-ff5bb260df2e) -replace ".*GUID: (\S+).*","$1"
    if ($ng) { powercfg -changename $ng "AudioPerformance" "Real-time audio optimized"; powercfg -setactive $ng }
    Write-Host "✓ AudioPerformance plan created and activated." -ForegroundColor Green
}' },
            @{ Id = "procstate";   Warn = $false; Label = "Lock CPU min/max processor state to 100%";          Detail = "Prevents CPU throttling under load — critical for sub-ms latency.";
               Cmd = 'Write-Host "--- Locking CPU State ---" -ForegroundColor Magenta
powercfg -setacvalueindex SCHEME_CURRENT SUB_PROCESSOR PROCTHROTTLEMIN 100
powercfg -setacvalueindex SCHEME_CURRENT SUB_PROCESSOR PROCTHROTTLEMAX 100
powercfg -setactive SCHEME_CURRENT
Write-Host "✓ CPU min/max locked to 100%." -ForegroundColor Green' },
            @{ Id = "cstates";     Warn = $false; Label = "Disable CPU idle / C-states (OS-level)";            Detail = "Stops Windows requesting CPU sleep states. Partial fix — full disable requires BIOS.";
               Cmd = 'Write-Host "--- Disabling C-States (OS level) ---" -ForegroundColor Magenta
powercfg -setacvalueindex SCHEME_CURRENT SUB_PROCESSOR IDLEDISABLE 1
powercfg -setacvalueindex SCHEME_CURRENT SUB_PROCESSOR IDLEPROMOTE 0
powercfg -setacvalueindex SCHEME_CURRENT SUB_PROCESSOR IDLEDEMOTE 0
powercfg -setacvalueindex SCHEME_CURRENT SUB_PROCESSOR IDLESCALING 0
powercfg -setactive SCHEME_CURRENT
Write-Host "✓ CPU idle states disabled." -ForegroundColor Green' },
            @{ Id = "coreparking"; Warn = $false; Label = "Disable CPU core parking";                          Detail = "Windows parks idle cores to save power — causes scheduling latency when audio demands them. Known to drop DPC latency from 80,000µs to 127µs.";
               Cmd = 'Write-Host "--- Disabling Core Parking ---" -ForegroundColor Magenta
$cp = "HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerSettings\54533251-82be-4824-96c1-47b60b740d00\0cc5b647-c1df-4637-891a-dec35c318583"
if (Test-Path $cp) { Set-ItemProperty -Path $cp -Name "Attributes" -Value 0 }
powercfg -setacvalueindex SCHEME_CURRENT 54533251-82be-4824-96c1-47b60b740d00 0cc5b647-c1df-4637-891a-dec35c318583 100
powercfg -setactive SCHEME_CURRENT
Write-Host "✓ Core parking disabled." -ForegroundColor Green' },
            @{ Id = "pcie_aspm";   Warn = $false; Label = "Disable PCIe Link State Power Management";          Detail = "ASPM puts PCIe slots into low-power states — causes wake latency on your audio/Dante PCIe card.";
               Cmd = 'Write-Host "--- Disabling PCIe ASPM ---" -ForegroundColor Magenta
powercfg -setacvalueindex SCHEME_CURRENT 381b4222-f694-41f0-9685-ff5bb260df2e 96f38cbd-1fe0-4bab-ab23-32d9a0b1f9ea 0
powercfg -setactive SCHEME_CURRENT
Write-Host "✓ PCIe ASPM disabled." -ForegroundColor Green' },
            @{ Id = "sleep";       Warn = $false; Label = "Disable sleep / hibernate";                         Detail = "Prevents OS from suspending during a show.";
               Cmd = 'Write-Host "--- Disabling Sleep/Hibernate ---" -ForegroundColor Magenta
powercfg -change -standby-timeout-ac 0
powercfg -change -hibernate-timeout-ac 0
powercfg -h off
Write-Host "✓ Sleep and hibernate disabled." -ForegroundColor Green' },
            @{ Id = "usbsuspend";  Warn = $false; Label = "Disable USB selective suspend";                     Detail = "Stops Windows powering down USB devices mid-session.";
               Cmd = 'Write-Host "--- Disabling USB Selective Suspend ---" -ForegroundColor Magenta
powercfg -setacvalueindex SCHEME_CURRENT 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0
powercfg -setactive SCHEME_CURRENT
Write-Host "✓ USB selective suspend disabled." -ForegroundColor Green' },
            @{ Id = "usb_roothub"; Warn = $false; Label = "Disable USB Root Hub per-device power management"; Detail = "Disables the per-hub Device Manager power setting for all USB Root Hubs.";
               Cmd = 'Write-Host "--- Disabling USB Root Hub Power Management ---" -ForegroundColor Magenta
$cls = "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{36FC9E60-C465-11CF-8056-444553540000}"
Get-ChildItem $cls -ErrorAction SilentlyContinue | ForEach-Object {
    $d = (Get-ItemProperty $_.PSPath -Name "DriverDesc" -ErrorAction SilentlyContinue).DriverDesc
    if ($d -like "*USB Root Hub*" -or $d -like "*USB 3.0 Root*") {
        Set-ItemProperty -Path $_.PSPath -Name "EnhancedPowerManagementEnabled" -Value 0 -ErrorAction SilentlyContinue
        Write-Host "  ✓ $d" -ForegroundColor Green
    }
}' }
        )
    },
    @{
        Id    = "boot"
        Label = "Boot Config (bcdedit)"
        Color = "#06b6d4"
        Items = @(
            @{ Id = "dynamictick";   Warn = $false; Label = "Disable Dynamic Tick";                           Detail = "Forces constant 1ms timer tick — prevents OS timer from coasting and missing audio callbacks. Requires reboot.";
               Cmd = 'Write-Host "--- Disabling Dynamic Tick ---" -ForegroundColor Magenta
bcdedit /set disabledynamictick yes | Out-Null
Write-Host "✓ Dynamic tick disabled." -ForegroundColor Green' },
            @{ Id = "platformclock"; Warn = $false; Label = "Force platform hardware clock (HPET)";           Detail = "⚠ Only for older hardware — on modern Intel/AMD the invariant TSC is faster than HPET. Verify with LatencyMon before and after.";
               Cmd = 'Write-Host "--- Setting Platform Clock ---" -ForegroundColor Magenta
bcdedit /set useplatformclock true | Out-Null
Write-Host "✓ Platform clock (HPET) enabled — verify with LatencyMon." -ForegroundColor Yellow' },
            @{ Id = "tscsync";       Warn = $false; Label = "Set TSC sync policy to Enhanced";                Detail = "Keeps per-core TSC counters aligned on multi-core systems — prevents scheduling jitter.";
               Cmd = 'Write-Host "--- Setting TSC Sync Policy ---" -ForegroundColor Magenta
bcdedit /set tscsyncpolicy Enhanced | Out-Null
Write-Host "✓ TSC sync policy set to Enhanced." -ForegroundColor Green' }
        )
    },
    @{
        Id    = "network"
        Label = "Network & Drivers"
        Color = "#3b82f6"
        Items = @(
            @{ Id = "eee";              Warn = $false; Label = "Disable Energy Efficient Ethernet (EEE)";               Detail = "EEE puts the NIC into low-power idle states — wake transitions generate ndis.sys DPC interrupts.";
               Cmd = 'Write-Host "--- Disabling EEE ---" -ForegroundColor Magenta
$nc = "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4D36E972-E325-11CE-BFC1-08002bE10318}"
Get-ChildItem $nc -ErrorAction SilentlyContinue | ForEach-Object {
    $d = (Get-ItemProperty $_.PSPath -Name "DriverDesc" -ErrorAction SilentlyContinue).DriverDesc
    if ($d) {
        $changed = $false
        foreach ($k in @("*EEE","EEE","EnableEEE","EEELinkAdvertisement")) {
            if (Get-ItemProperty $_.PSPath -Name $k -ErrorAction SilentlyContinue) {
                Set-ItemProperty -Path $_.PSPath -Name $k -Value 0 -ErrorAction SilentlyContinue; $changed = $true
            }
        }
        if ($changed) { Write-Host "  ✓ EEE disabled: $d" -ForegroundColor Green }
    }
}' },
            @{ Id = "nic_power";        Warn = $false; Label = "Disable 'Allow computer to turn off this device' — NIC"; Detail = "Sets PnPCapabilities = 24 on all NICs — equivalent to unchecking the Device Manager power option.";
               Cmd = 'Write-Host "--- Disabling NIC Device Power Management ---" -ForegroundColor Magenta
$nc = "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4D36E972-E325-11CE-BFC1-08002bE10318}"
Get-ChildItem $nc -ErrorAction SilentlyContinue | ForEach-Object {
    $d = (Get-ItemProperty $_.PSPath -Name "DriverDesc" -ErrorAction SilentlyContinue).DriverDesc
    if ($d) {
        Set-ItemProperty -Path $_.PSPath -Name "PnPCapabilities" -Value 24 -ErrorAction SilentlyContinue
        Write-Host "  ✓ $d" -ForegroundColor Green
    }
}' },
            @{ Id = "nic_interrupt_mod"; Warn = $false; Label = "Disable NIC Interrupt Moderation";                      Detail = "Batched interrupts add latency per packet. Disabling fires each interrupt immediately — slightly more CPU but tighter timing.";
               Cmd = 'Write-Host "--- Disabling NIC Interrupt Moderation ---" -ForegroundColor Magenta
$nc = "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4D36E972-E325-11CE-BFC1-08002bE10318}"
Get-ChildItem $nc -ErrorAction SilentlyContinue | ForEach-Object {
    $d = (Get-ItemProperty $_.PSPath -Name "DriverDesc" -ErrorAction SilentlyContinue).DriverDesc
    if ($d) {
        $changed = $false
        foreach ($k in @("*InterruptModeration","InterruptModeration","ITR","bInterruptMitigate","InterruptModerationRate","InterruptThrottleRate")) {
            if (Get-ItemProperty $_.PSPath -Name $k -ErrorAction SilentlyContinue) {
                Set-ItemProperty -Path $_.PSPath -Name $k -Value 0 -ErrorAction SilentlyContinue; $changed = $true
            }
        }
        if ($changed) { Write-Host "  ✓ Interrupt Moderation disabled: $d" -ForegroundColor Green }
    }
}' },
            @{ Id = "nic_flow_control";  Warn = $false; Label = "Disable NIC Flow Control";                              Detail = "PAUSE frames from Flow Control can halt NIC TX for up to ~33ms — long enough for an audible Dante dropout.";
               Cmd = 'Write-Host "--- Disabling NIC Flow Control ---" -ForegroundColor Magenta
$nc = "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4D36E972-E325-11CE-BFC1-08002bE10318}"
Get-ChildItem $nc -ErrorAction SilentlyContinue | ForEach-Object {
    $d = (Get-ItemProperty $_.PSPath -Name "DriverDesc" -ErrorAction SilentlyContinue).DriverDesc
    if ($d) {
        $changed = $false
        foreach ($k in @("*FlowControl","FlowControl")) {
            if (Get-ItemProperty $_.PSPath -Name $k -ErrorAction SilentlyContinue) {
                Set-ItemProperty -Path $_.PSPath -Name $k -Value 0 -ErrorAction SilentlyContinue; $changed = $true
            }
        }
        if ($changed) { Write-Host "  ✓ Flow Control disabled: $d" -ForegroundColor Green }
    }
}' },
            @{ Id = "nic_roaming";       Warn = $false; Label = "Set Wi-Fi roaming aggressiveness to Lowest";            Detail = "Stops Wi-Fi adapter scanning for better APs — generates ndis.sys DPC bursts.";
               Cmd = 'Write-Host "--- Setting Wi-Fi Roaming Aggressiveness ---" -ForegroundColor Magenta
$nc = "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4D36E972-E325-11CE-BFC1-08002bE10318}"
Get-ChildItem $nc -ErrorAction SilentlyContinue | ForEach-Object {
    $d = (Get-ItemProperty $_.PSPath -Name "DriverDesc" -ErrorAction SilentlyContinue).DriverDesc
    if ($d -like "*Wireless*" -or $d -like "*WiFi*" -or $d -like "*Wi-Fi*" -or $d -like "*WLAN*") {
        Set-ItemProperty -Path $_.PSPath -Name "RoamAggressiveness" -Value 1 -ErrorAction SilentlyContinue
        Write-Host "  ✓ Roaming set to Lowest: $d" -ForegroundColor Green
    }
}' },
            @{ Id = "ipv6";              Warn = $true;  Label = "Disable IPv6 on all adapters";                          Detail = "IPv6 neighbor discovery generates background ndis.sys interrupt activity even on non-IPv6 networks.";
               Cmd = 'Write-Host "--- Disabling IPv6 ---" -ForegroundColor Magenta
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters" -Name "DisabledComponents" -Value 0xFE -ErrorAction SilentlyContinue
Write-Host "✓ IPv6 disabled (all interfaces except loopback)." -ForegroundColor Green
$win81 = ([System.Environment]::OSVersion.Version.Major -gt 6) -or ([System.Environment]::OSVersion.Version.Major -eq 6 -and [System.Environment]::OSVersion.Version.Minor -ge 3)
if ($win81 -and (Get-Command Disable-NetAdapterBinding -ErrorAction SilentlyContinue)) {
    Get-NetAdapter -ErrorAction SilentlyContinue | ForEach-Object {
        Disable-NetAdapterBinding -Name $_.Name -ComponentID ms_tcpip6 -ErrorAction SilentlyContinue
    }
    Write-Host "✓ IPv6 adapter bindings disabled." -ForegroundColor Green
}' },
            @{ Id = "msi_interrupts";    Warn = $false; Label = "Disable MSI mode on network adapters";                  Detail = "Message Signaled Interrupts on NICs can cause ntoskrnl.exe spikes — forces legacy INTx mode.";
               Cmd = 'Write-Host "--- Disabling NIC MSI Mode ---" -ForegroundColor Magenta
$nics = Get-WmiObject Win32_NetworkAdapter -ErrorAction SilentlyContinue | Where-Object { $_.NetEnabled -eq $true }
foreach ($nic in $nics) {
    $p = "HKLM:\SYSTEM\CurrentControlSet\Enum\$($nic.PNPDeviceID)\Device Parameters\Interrupt Management\MessageSignaledInterruptProperties"
    if (Test-Path $p) {
        Set-ItemProperty -Path $p -Name "MSISupported" -Value 0 -ErrorAction SilentlyContinue
        Write-Host "  ✓ MSI disabled: $($nic.Name)" -ForegroundColor Green
    }
}' },
            @{ Id = "nvidia_hd_audio";   Warn = $false; Label = "Disable NVIDIA HD Audio device";                        Detail = "NVIDIA HD Audio driver sits in the DPC interrupt chain — disabling removes it without affecting display output.";
               Cmd = 'Write-Host "--- Disabling NVIDIA HD Audio ---" -ForegroundColor Magenta
$devs = Get-WmiObject Win32_PnPEntity -ErrorAction SilentlyContinue | Where-Object { $_.Name -like "*NVIDIA*High Definition Audio*" -or $_.Name -like "*NVIDIA*HD Audio*" }
if ($devs) {
    $win81 = ([System.Environment]::OSVersion.Version.Major -gt 6)
    foreach ($dev in $devs) {
        if ($win81 -and (Get-Command Disable-PnpDevice -ErrorAction SilentlyContinue)) {
            Disable-PnpDevice -InstanceId $dev.DeviceID -Confirm:$false -ErrorAction SilentlyContinue
        } else {
            $rp = "HKLM:\SYSTEM\CurrentControlSet\Enum\$($dev.DeviceID)"
            if (Test-Path $rp) { Set-ItemProperty -Path $rp -Name "ConfigFlags" -Value 0x4 -ErrorAction SilentlyContinue }
        }
        Write-Host "  ✓ Disabled: $($dev.Name)" -ForegroundColor Green
    }
} else { Write-Host "  — NVIDIA HD Audio not found, skipping." -ForegroundColor Yellow }' },
            @{ Id = "rst";               Warn = $false; Label = "Disable Intel RST Link Power Management";               Detail = "Intel RST fires a timer DPC causing storport.sys spikes every 10–15 min. Full uninstall is the definitive fix.";
               Cmd = 'Write-Host "--- Disabling Intel RST Link Power Management ---" -ForegroundColor Magenta
$rp = "HKLM:\SOFTWARE\Intel\Intel Rapid Storage Technology"
if (Test-Path $rp) {
    Set-ItemProperty -Path $rp -Name "LinkPowerManagement" -Value 0 -ErrorAction SilentlyContinue
    Write-Host "✓ Intel RST Link Power Management disabled." -ForegroundColor Green
} else { Write-Host "  — Intel RST not found, skipping." -ForegroundColor Yellow }' }
        )
    },
    @{
        Id    = "services"
        Label = "Services"
        Color = "#6366f1"
        Items = @(
            @{ Id = "winsearch";  Warn = $false; Label = "Disable Windows Search indexer";             Detail = "One of the most common causes of DPC latency spikes.";
               Cmd = 'Write-Host "--- Disabling Windows Search ---" -ForegroundColor Magenta
Stop-Service -Name WSearch -Force -ErrorAction SilentlyContinue
Set-Service -Name WSearch -StartupType Disabled -ErrorAction SilentlyContinue
Write-Host "✓ Windows Search disabled." -ForegroundColor Green' },
            @{ Id = "superfetch"; Warn = $false; Label = "Disable SysMain (Superfetch)";              Detail = "Stops background memory pre-loading that competes with audio threads.";
               Cmd = 'Write-Host "--- Disabling SysMain ---" -ForegroundColor Magenta
Stop-Service -Name SysMain -Force -ErrorAction SilentlyContinue
Set-Service -Name SysMain -StartupType Disabled -ErrorAction SilentlyContinue
Write-Host "✓ SysMain disabled." -ForegroundColor Green' },
            @{ Id = "wupdate";    Warn = $false; Label = "Disable Windows Update auto-start";         Detail = "Prevents update downloads from spiking disk and CPU mid-show.";
               Cmd = 'Write-Host "--- Disabling Windows Update ---" -ForegroundColor Magenta
Stop-Service -Name wuauserv -Force -ErrorAction SilentlyContinue
Set-Service -Name wuauserv -StartupType Disabled -ErrorAction SilentlyContinue
Write-Host "✓ Windows Update disabled." -ForegroundColor Green' },
            @{ Id = "bits";       Warn = $false; Label = "Disable BITS";                              Detail = "Background Intelligent Transfer — Windows Update's download engine, fires on a timer even when wuauserv is stopped.";
               Cmd = 'Write-Host "--- Disabling BITS ---" -ForegroundColor Magenta
Stop-Service -Name BITS -Force -ErrorAction SilentlyContinue
Set-Service -Name BITS -StartupType Disabled -ErrorAction SilentlyContinue
Write-Host "✓ BITS disabled." -ForegroundColor Green' },
            @{ Id = "bgapps";     Warn = $false; Label = "Disable background UWP apps";               Detail = "UWP apps run background tasks generating kernel callbacks even when not in focus. Win 10+ only.";
               Cmd = 'Write-Host "--- Disabling Background UWP Apps ---" -ForegroundColor Magenta
$win10 = ([System.Environment]::OSVersion.Version.Major -ge 10)
if ($win10) {
    $p = "HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications"
    if (!(Test-Path $p)) { New-Item -Path $p -Force | Out-Null }
    Set-ItemProperty -Path $p -Name "GlobalUserDisabled" -Value 1
    Set-ItemProperty -Path $p -Name "Disabled" -Value 1
    Write-Host "✓ Background apps disabled." -ForegroundColor Green
} else { Write-Host "  — Skipping (Win 10+ only)." -ForegroundColor Yellow }' },
            @{ Id = "telemetry";  Warn = $false; Label = "Disable telemetry / DiagTrack";             Detail = "Removes Microsoft diagnostic reporting. Win 10+ only.";
               Cmd = 'Write-Host "--- Disabling Telemetry ---" -ForegroundColor Magenta
$win10 = ([System.Environment]::OSVersion.Version.Major -ge 10)
if ($win10) {
    Stop-Service -Name DiagTrack -Force -ErrorAction SilentlyContinue
    Set-Service -Name DiagTrack -StartupType Disabled -ErrorAction SilentlyContinue
    Stop-Service -Name dmwappushservice -Force -ErrorAction SilentlyContinue
    Set-Service -Name dmwappushservice -StartupType Disabled -ErrorAction SilentlyContinue
    Write-Host "✓ Telemetry services disabled." -ForegroundColor Green
} else { Write-Host "  — Skipping (Win 10+ only)." -ForegroundColor Yellow }' },
            @{ Id = "defender";   Warn = $true;  Label = "Disable Windows Defender real-time scanning"; Detail = "⚠ AGGRESSIVE — dedicated offline audio PCs only. Major DPC latency source.";
               Cmd = 'Write-Host "--- Disabling Windows Defender Real-Time Scanning ---" -ForegroundColor Magenta
if (Get-Command Set-MpPreference -ErrorAction SilentlyContinue) {
    Set-MpPreference -DisableRealtimeMonitoring $true
    Write-Host "✓ Defender real-time monitoring disabled." -ForegroundColor Green
} else { Write-Host "  — Set-MpPreference not available on this OS." -ForegroundColor Yellow }' }
        )
    },
    @{
        Id    = "tasks"
        Label = "Scheduled Tasks"
        Color = "#e879f9"
        Items = @(
            @{ Id = "task_defender";    Warn = $false; Label = "Disable Defender scheduled scans";         Detail = "Fires on a ~15 min idle timer — the #1 cause of the 'fine then dropout' pattern in LatencyMon.";
               Cmd = 'Write-Host "--- Disabling Defender Scan Tasks ---" -ForegroundColor Magenta
$win10 = ([System.Environment]::OSVersion.Version.Major -ge 10)
if ($win10) {
    @("\Microsoft\Windows\Windows Defender\Windows Defender Cache Maintenance",
      "\Microsoft\Windows\Windows Defender\Windows Defender Cleanup",
      "\Microsoft\Windows\Windows Defender\Windows Defender Scheduled Scan",
      "\Microsoft\Windows\Windows Defender\Windows Defender Verification") | ForEach-Object {
        Disable-ScheduledTask -TaskPath (Split-Path $_) -TaskName (Split-Path $_ -Leaf) -ErrorAction SilentlyContinue
        Write-Host "  ✓ Disabled: $_" -ForegroundColor Green
    }
} else { Write-Host "  — Skipping (Win 10+ only)." -ForegroundColor Yellow }' },
            @{ Id = "task_orchestrator"; Warn = $false; Label = "Disable Update Orchestrator tasks";       Detail = "Fires scan/install tasks on timers causing ntoskrnl.exe spikes even with wuauserv disabled.";
               Cmd = 'Write-Host "--- Disabling Update Orchestrator Tasks ---" -ForegroundColor Magenta
$win10 = ([System.Environment]::OSVersion.Version.Major -ge 10)
if ($win10) {
    @("\Microsoft\Windows\UpdateOrchestrator\Schedule Scan",
      "\Microsoft\Windows\UpdateOrchestrator\Schedule Scan Static Task",
      "\Microsoft\Windows\UpdateOrchestrator\USO_UxBroker",
      "\Microsoft\Windows\UpdateOrchestrator\Report policies",
      "\Microsoft\Windows\UpdateOrchestrator\StartInstall",
      "\Microsoft\Windows\WindowsUpdate\Scheduled Start") | ForEach-Object {
        Disable-ScheduledTask -TaskPath (Split-Path $_) -TaskName (Split-Path $_ -Leaf) -ErrorAction SilentlyContinue
        Write-Host "  ✓ Disabled: $_" -ForegroundColor Green
    }
} else { Write-Host "  — Skipping (Win 10+ only)." -ForegroundColor Yellow }' },
            @{ Id = "task_w32time";      Warn = $false; Label = "Fix NTP sync interval (W32Time)";         Detail = "W32Time can sync every 15 min — causes a brief kernel interrupt burst. Sets to once per day.";
               Cmd = 'Write-Host "--- Fixing W32Time Interval ---" -ForegroundColor Magenta
cmd /c "w32tm /config /update /syncfromflags:manual /manualpeerlist:time.windows.com" | Out-Null
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\W32Time\TimeProviders\NtpClient" -Name "SpecialPollInterval" -Value 86400 -ErrorAction SilentlyContinue
Write-Host "✓ W32Time sync interval set to 24 hours." -ForegroundColor Green' },
            @{ Id = "task_defrag";       Warn = $false; Label = "Disable scheduled disk defrag";           Detail = "Wakes storport.sys on a timer — causes periodic storage spikes even on SSDs.";
               Cmd = 'Write-Host "--- Disabling Scheduled Defrag ---" -ForegroundColor Magenta
Disable-ScheduledTask -TaskPath "\Microsoft\Windows\Defrag" -TaskName "ScheduledDefrag" -ErrorAction SilentlyContinue
Write-Host "✓ Scheduled defrag disabled." -ForegroundColor Green' },
            @{ Id = "task_maintenance";  Warn = $false; Label = "Disable Automatic Maintenance tasks";    Detail = "Windows Automatic Maintenance runs diagnostics and app updates on a background timer.";
               Cmd = 'Write-Host "--- Disabling Automatic Maintenance ---" -ForegroundColor Magenta
@("\Microsoft\Windows\TaskScheduler\Regular Maintenance",
  "\Microsoft\Windows\TaskScheduler\Maintenance Configurator",
  "\Microsoft\Windows\Diagnosis\Scheduled") | ForEach-Object {
    Disable-ScheduledTask -TaskPath (Split-Path $_) -TaskName (Split-Path $_ -Leaf) -ErrorAction SilentlyContinue
    Write-Host "  ✓ Disabled: $_" -ForegroundColor Green
}
$mp = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\Maintenance"
if (!(Test-Path $mp)) { New-Item -Path $mp -Force | Out-Null }
Set-ItemProperty -Path $mp -Name "MaintenanceDisabled" -Value 1
Write-Host "✓ Automatic Maintenance disabled." -ForegroundColor Green' },
            @{ Id = "task_telemetry";    Warn = $false; Label = "Disable telemetry scheduled tasks";      Detail = "CEIP, compatibility appraiser, and disk diagnostic tasks run on timers.";
               Cmd = 'Write-Host "--- Disabling Telemetry Tasks ---" -ForegroundColor Magenta
$win10 = ([System.Environment]::OSVersion.Version.Major -ge 10)
if ($win10) {
    @("\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser",
      "\Microsoft\Windows\Application Experience\ProgramDataUpdater",
      "\Microsoft\Windows\Autochk\Proxy",
      "\Microsoft\Windows\Customer Experience Improvement Program\Consolidator",
      "\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip",
      "\Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector") | ForEach-Object {
        Disable-ScheduledTask -TaskPath (Split-Path $_) -TaskName (Split-Path $_ -Leaf) -ErrorAction SilentlyContinue
        Write-Host "  ✓ Disabled: $_" -ForegroundColor Green
    }
} else { Write-Host "  — Skipping (Win 10+ only)." -ForegroundColor Yellow }' },
            @{ Id = "task_nvidia";       Warn = $false; Label = "Disable NVIDIA scheduled tasks";         Detail = "GeForce Experience crash reporters and update checker correlate with nvlddmkm.sys periodic spikes.";
               Cmd = 'Write-Host "--- Disabling NVIDIA Tasks ---" -ForegroundColor Magenta
@("\NvTmRep_CrashReport1_{B2FE1952-0186-46C3-BAEC-A80AA35AC5B8}",
  "\NvTmRep_CrashReport2_{B2FE1952-0186-46C3-BAEC-A80AA35AC5B8}",
  "\NvTmRep_CrashReport3_{B2FE1952-0186-46C3-BAEC-A80AA35AC5B8}",
  "\NvTmRep_CrashReport4_{B2FE1952-0186-46C3-BAEC-A80AA35AC5B8}",
  "\NvidiaTask\NvDriverUpdateCheckDaily_{B2FE1952-0186-46C3-BAEC-A80AA35AC5B8}",
  "\NvidiaTask\NvNodeLauncher_{B2FE1952-0186-46C3-BAEC-A80AA35AC5B8}") | ForEach-Object {
    Disable-ScheduledTask -TaskPath (Split-Path $_) -TaskName (Split-Path $_ -Leaf) -ErrorAction SilentlyContinue
}
Write-Host "✓ NVIDIA tasks disabled (if present)." -ForegroundColor Green' }
        )
    },
    @{
        Id    = "scheduler"
        Label = "Scheduler & Threading"
        Color = "#10b981"
        Items = @(
            @{ Id = "mmcss";         Warn = $false; Label = "Tune MMCSS for Pro Audio priority"; Detail = "Gives audio threads real-time priority above normal system processes via MultiMedia Class Scheduler.";
               Cmd = 'Write-Host "--- Tuning MMCSS ---" -ForegroundColor Magenta
$p = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Pro Audio"
if (!(Test-Path $p)) { New-Item -Path $p -Force | Out-Null }
Set-ItemProperty -Path $p -Name "Affinity" -Value 0
Set-ItemProperty -Path $p -Name "Background Only" -Value "False"
Set-ItemProperty -Path $p -Name "Clock Rate" -Value 10000
Set-ItemProperty -Path $p -Name "GPU Priority" -Value 8
Set-ItemProperty -Path $p -Name "Priority" -Value 1
Set-ItemProperty -Path $p -Name "Scheduling Category" -Value "High"
Set-ItemProperty -Path $p -Name "SFIO Priority" -Value "High"
Write-Host "✓ MMCSS Pro Audio profile configured." -ForegroundColor Green' },
            @{ Id = "systemprofile"; Warn = $false; Label = "Set system profile to low latency";  Detail = "Sets SystemResponsiveness to 0 and disables network throttling for tighter audio thread timing.";
               Cmd = 'Write-Host "--- Setting System Profile ---" -ForegroundColor Magenta
$p = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
Set-ItemProperty -Path $p -Name "SystemResponsiveness" -Value 0
Set-ItemProperty -Path $p -Name "NetworkThrottlingIndex" -Value 0xffffffff
Write-Host "✓ System profile set to low latency." -ForegroundColor Green' },
            @{ Id = "timerres";      Warn = $false; Label = "Enable high-resolution system timer"; Detail = "Forces Windows timer resolution toward 0.5ms instead of default 15.6ms.";
               Cmd = 'Write-Host "--- Enabling High-Resolution Timer ---" -ForegroundColor Magenta
$p = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\kernel"
Set-ItemProperty -Path $p -Name "GlobalTimerResolutionRequests" -Value 1
Write-Host "✓ High-resolution timer enabled." -ForegroundColor Green' }
        )
    },
    @{
        Id    = "visual"
        Label = "Visual & UI"
        Color = "#ec4899"
        Items = @(
            @{ Id = "visualfx";   Warn = $false; Label = "Disable all visual effects";  Detail = "Stops Windows wasting GPU/CPU on animations, transparency, and shadows.";
               Cmd = 'Write-Host "--- Disabling Visual Effects ---" -ForegroundColor Magenta
$p = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects"
if (!(Test-Path $p)) { New-Item -Path $p -Force | Out-Null }
Set-ItemProperty -Path $p -Name "VisualFXSetting" -Value 2
Write-Host "✓ Visual effects disabled." -ForegroundColor Green' },
            @{ Id = "syssounds";  Warn = $false; Label = "Disable system sounds";        Detail = "Prevents Windows notification sounds routing through your audio driver.";
               Cmd = 'Write-Host "--- Disabling System Sounds ---" -ForegroundColor Magenta
Set-ItemProperty -Path "HKCU:\AppEvents\Schemes" -Name "(Default)" -Value ".None"
Write-Host "✓ System sounds disabled." -ForegroundColor Green' }
        )
    },
    @{
        Id    = "storage"
        Label = "Storage & I/O"
        Color = "#f97316"
        Items = @(
            @{ Id = "hddoff";    Warn = $false; Label = "Disable hard disk sleep";           Detail = "Prevents disk spin-down stalling audio mid-session.";
               Cmd = 'Write-Host "--- Disabling Hard Disk Sleep ---" -ForegroundColor Magenta
powercfg -setacvalueindex SCHEME_CURRENT 0012ee47-9041-4b5d-9b77-535fba8b1442 6738e2c4-e8a5-4a42-b16a-e040e769756e 0
powercfg -setactive SCHEME_CURRENT
Write-Host "✓ Hard disk sleep disabled." -ForegroundColor Green' },
            @{ Id = "prefetch";  Warn = $false; Label = "Disable disk prefetch / Superfetch"; Detail = "Stops Windows pre-loading files in background during operation.";
               Cmd = 'Write-Host "--- Disabling Prefetch ---" -ForegroundColor Magenta
$p = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters"
Set-ItemProperty -Path $p -Name "EnablePrefetcher" -Value 0
Set-ItemProperty -Path $p -Name "EnableSuperfetch" -Value 0
Write-Host "✓ Prefetch disabled." -ForegroundColor Green' },
            @{ Id = "bitlocker"; Warn = $true;  Label = "Disable BitLocker on C: drive";     Detail = "⚠ AGGRESSIVE — encryption overhead on every disk I/O. Only for dedicated offline audio machines.";
               Cmd = 'Write-Host "--- Disabling BitLocker ---" -ForegroundColor Magenta
manage-bde -off C: 2>&1 | ForEach-Object { Write-Host "  $_" }
Write-Host "✓ BitLocker disable initiated on C:." -ForegroundColor Green' }
        )
    }
)

#endregion

#region ── XAML ───────────────────────────────────────────────────────────────

[xml]$XAML = @"
<Window
    xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    Title="TMC Audio PC Optimizer"
    Width="980" Height="800"
    MinWidth="760" MinHeight="600"
    WindowStartupLocation="CenterScreen"
    Background="#0a0a0f"
    Foreground="#e2e8f0"
    FontFamily="Consolas, Courier New"
    FontSize="12">

  <Window.Resources>

    <Style TargetType="ScrollViewer">
      <Setter Property="Background" Value="Transparent"/>
      <Setter Property="VerticalScrollBarVisibility" Value="Auto"/>
    </Style>

    <Style TargetType="CheckBox" x:Key="ItemCheck">
      <Setter Property="Foreground" Value="#94a3b8"/>
      <Setter Property="Background" Value="Transparent"/>
      <Setter Property="Margin" Value="0,0,0,1"/>
      <Setter Property="Padding" Value="8,6"/>
      <Setter Property="FontFamily" Value="Consolas, Courier New"/>
      <Setter Property="FontSize" Value="11"/>
      <Setter Property="Cursor" Value="Hand"/>
    </Style>

    <Style TargetType="Button" x:Key="RunBtn">
      <Setter Property="Background" Value="#16a34a"/>
      <Setter Property="Foreground" Value="#ffffff"/>
      <Setter Property="FontFamily" Value="Consolas, Courier New"/>
      <Setter Property="FontSize" Value="13"/>
      <Setter Property="FontWeight" Value="Bold"/>
      <Setter Property="BorderThickness" Value="0"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Padding" Value="30,12"/>
    </Style>

    <Style TargetType="Button" x:Key="SmallBtn">
      <Setter Property="Background" Value="#1e1e35"/>
      <Setter Property="Foreground" Value="#94a3b8"/>
      <Setter Property="FontFamily" Value="Consolas, Courier New"/>
      <Setter Property="FontSize" Value="10"/>
      <Setter Property="BorderThickness" Value="1"/>
      <Setter Property="BorderBrush" Value="#2d2d50"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Padding" Value="8,3"/>
    </Style>

    <Style TargetType="TabItem">
      <Setter Property="Background" Value="Transparent"/>
      <Setter Property="Foreground" Value="#475569"/>
      <Setter Property="FontFamily" Value="Consolas, Courier New"/>
      <Setter Property="FontSize" Value="11"/>
      <Setter Property="Padding" Value="14,8"/>
      <Setter Property="BorderThickness" Value="0"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="TabItem">
            <Border Name="TabBorder" Background="Transparent" BorderThickness="0,0,0,2" BorderBrush="Transparent" Padding="14,8">
              <ContentPresenter ContentSource="Header" TextBlock.Foreground="{TemplateBinding Foreground}"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsSelected" Value="True">
                <Setter TargetName="TabBorder" Property="BorderBrush" Value="#f59e0b"/>
                <Setter Property="Foreground" Value="#f1f5f9"/>
              </Trigger>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter Property="Foreground" Value="#cbd5e1"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <Style TargetType="TabControl">
      <Setter Property="Background" Value="Transparent"/>
      <Setter Property="BorderThickness" Value="0"/>
      <Setter Property="TabStripPlacement" Value="Top"/>
    </Style>

  </Window.Resources>

  <Grid>
    <Grid.RowDefinitions>
      <RowDefinition Height="Auto"/>  <!-- Header -->
      <RowDefinition Height="Auto"/>  <!-- Script Options -->
      <RowDefinition Height="*"/>     <!-- Tab content -->
      <RowDefinition Height="Auto"/>  <!-- Bottom bar -->
    </Grid.RowDefinitions>

    <!-- ── Header ──────────────────────────────────────────── -->
    <Border Grid.Row="0" Background="#0f0f1a" BorderThickness="0,0,0,1" BorderBrush="#1e1e35" Padding="24,16,24,0">
      <Grid>
        <Grid.RowDefinitions>
          <RowDefinition Height="Auto"/>
          <RowDefinition Height="Auto"/>
          <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>

        <StackPanel Grid.Row="0" Orientation="Horizontal" Margin="0,0,0,10">
          <Border Width="6" Height="28" Background="#f59e0b" CornerRadius="2" Margin="0,0,12,0"/>
          <StackPanel>
            <TextBlock Text="WINDOWS REAL-TIME AUDIO" FontSize="9" Foreground="#64748b"/>
            <TextBlock Text="PC Optimizer" FontSize="20" FontWeight="Bold" Foreground="#f1f5f9"/>
          </StackPanel>
          <StackPanel Margin="30,0,0,0" VerticalAlignment="Center">
            <TextBlock Name="SelectionCount" Text="0/0 selected" FontSize="10" Foreground="#475569"/>
          </StackPanel>
        </StackPanel>

        <!-- Progress bar -->
        <Border Grid.Row="1" Height="3" Background="#1e1e35" Margin="0,0,0,0">
          <Border Name="ProgressBar" HorizontalAlignment="Left" Width="0" Background="#f59e0b" Height="3"/>
        </Border>

        <!-- Tab strip -->
        <TabControl Grid.Row="2" Name="MainTabs" Background="Transparent" BorderThickness="0" Padding="0">
          <TabItem Header="Optimize"/>
          <TabItem Header="BIOS Checklist"/>
          <TabItem Header="Manual Steps"/>
        </TabControl>
      </Grid>
    </Border>

    <!-- ── Script Options ──────────────────────────────────── -->
    <Border Grid.Row="1" Background="#0a0f0a" BorderThickness="0,0,0,1" BorderBrush="#1a3020" Padding="24,12">
      <StackPanel Name="ScriptOptionsPanel">
        <StackPanel Orientation="Horizontal">
          <TextBlock Text="SCRIPT OPTIONS" FontSize="9" Foreground="#475569" VerticalAlignment="Center" Margin="0,0,24,0"/>
          <CheckBox Name="ChkRestorePoint" IsChecked="True" Style="{StaticResource ItemCheck}" Foreground="#86efac" Content="Create System Restore Point  " Margin="0,0,16,0" VerticalAlignment="Center"/>
          <CheckBox Name="ChkAutoReboot" IsChecked="False" Style="{StaticResource ItemCheck}" Foreground="#22d3ee" Content="Auto-Reboot after completion  " VerticalAlignment="Center"/>
          <StackPanel Name="RebootDelayPanel" Orientation="Horizontal" Visibility="Collapsed" VerticalAlignment="Center" Margin="8,0,0,0">
            <TextBlock Text="Delay:" FontSize="10" Foreground="#475569" VerticalAlignment="Center" Margin="0,0,8,0"/>
            <RadioButton Name="Delay15"  Content="15s" GroupName="RebootDelay" IsChecked="False" Foreground="#64748b" FontFamily="Consolas" FontSize="10" VerticalAlignment="Center" Margin="0,0,8,0" Cursor="Hand"/>
            <RadioButton Name="Delay30"  Content="30s" GroupName="RebootDelay" IsChecked="True"  Foreground="#64748b" FontFamily="Consolas" FontSize="10" VerticalAlignment="Center" Margin="0,0,8,0" Cursor="Hand"/>
            <RadioButton Name="Delay60"  Content="60s" GroupName="RebootDelay" IsChecked="False" Foreground="#64748b" FontFamily="Consolas" FontSize="10" VerticalAlignment="Center" Margin="0,0,8,0" Cursor="Hand"/>
            <RadioButton Name="Delay120" Content="2m"  GroupName="RebootDelay" IsChecked="False" Foreground="#64748b" FontFamily="Consolas" FontSize="10" VerticalAlignment="Center" Cursor="Hand"/>
          </StackPanel>
        </StackPanel>
      </StackPanel>
    </Border>

    <!-- ── Tab Content ─────────────────────────────────────── -->
    <Grid Grid.Row="2">

      <!-- Optimize panel (shown when Optimize tab selected) -->
      <ScrollViewer Name="PanelOptimize" VerticalScrollBarVisibility="Auto" Padding="24,16,24,16">
        <StackPanel Name="CategoriesPanel"/>
      </ScrollViewer>

      <!-- BIOS panel -->
      <ScrollViewer Name="PanelBios" Visibility="Collapsed" VerticalScrollBarVisibility="Auto" Padding="24,16,24,16">
        <StackPanel Name="BiosPanel"/>
      </ScrollViewer>

      <!-- Manual Steps panel -->
      <ScrollViewer Name="PanelManual" Visibility="Collapsed" VerticalScrollBarVisibility="Auto" Padding="24,16,24,16">
        <StackPanel Name="ManualPanel"/>
      </ScrollViewer>

    </Grid>

    <!-- ── Bottom Bar ──────────────────────────────────────── -->
    <Border Grid.Row="3" Background="#0f0f1a" BorderThickness="0,1,0,0" BorderBrush="#1e1e35" Padding="24,14">
      <Grid>
        <Grid.ColumnDefinitions>
          <ColumnDefinition Width="*"/>
          <ColumnDefinition Width="Auto"/>
        </Grid.ColumnDefinitions>
        <StackPanel Grid.Column="0" Orientation="Horizontal" VerticalAlignment="Center">
          <TextBlock Name="StatusText" Text="Select optimizations above, then click Run." FontSize="10" Foreground="#475569" VerticalAlignment="Center"/>
        </StackPanel>
        <StackPanel Grid.Column="1" Orientation="Horizontal">
          <Button Name="BtnSelectAll"   Content="SELECT ALL"   Style="{StaticResource SmallBtn}" Margin="0,0,8,0"/>
          <Button Name="BtnSelectNone"  Content="CLEAR ALL"    Style="{StaticResource SmallBtn}" Margin="0,0,16,0"/>
          <Button Name="BtnRun"         Content="▶  RUN OPTIMIZER" Style="{StaticResource RunBtn}"/>
        </StackPanel>
      </Grid>
    </Border>

  </Grid>
</Window>
"@

#endregion

#region ── Load XAML + Get Controls ──────────────────────────────────────────

$Reader = [System.Xml.XmlNodeReader]::new($XAML)
$Window = [Windows.Markup.XamlReader]::Load($Reader)

# Controls
$MainTabs        = $Window.FindName("MainTabs")
$PanelOptimize   = $Window.FindName("PanelOptimize")
$PanelBios       = $Window.FindName("PanelBios")
$PanelManual     = $Window.FindName("PanelManual")
$CategoriesPanel = $Window.FindName("CategoriesPanel")
$BiosPanel       = $Window.FindName("BiosPanel")
$ManualPanel     = $Window.FindName("ManualPanel")
$SelectionCount  = $Window.FindName("SelectionCount")
$ProgressBar     = $Window.FindName("ProgressBar")
$StatusText      = $Window.FindName("StatusText")
$BtnRun          = $Window.FindName("BtnRun")
$BtnSelectAll    = $Window.FindName("BtnSelectAll")
$BtnSelectNone   = $Window.FindName("BtnSelectNone")
$ChkRestorePoint = $Window.FindName("ChkRestorePoint")
$ChkAutoReboot   = $Window.FindName("ChkAutoReboot")
$RebootDelayPanel= $Window.FindName("RebootDelayPanel")
$Delay15         = $Window.FindName("Delay15")
$Delay30         = $Window.FindName("Delay30")
$Delay60         = $Window.FindName("Delay60")
$Delay120        = $Window.FindName("Delay120")

# Store checkbox references keyed by item ID
$Script:CheckBoxes = @{}
$Script:ShouldRun  = $false

# Total item count for progress bar
$TotalItems = ($Categories | ForEach-Object { $_.Items.Count } | Measure-Object -Sum).Sum

#endregion

#region ── Helpers ────────────────────────────────────────────────────────────

function Update-SelectionDisplay {
    $selected = ($Script:CheckBoxes.Values | Where-Object { $_.IsChecked }).Count
    $SelectionCount.Text = "$selected/$TotalItems selected"
    if ($TotalItems -gt 0) {
        $pct = [double]$selected / [double]$TotalItems
        $maxWidth = $Window.ActualWidth - 48
        if ($maxWidth -lt 0) { $maxWidth = 900 }
        $ProgressBar.Width = $pct * $maxWidth
    }
    if ($selected -gt 0) {
        $StatusText.Text = "$selected optimization$(if ($selected -ne 1) { 's' }) selected — ready to run."
    } else {
        $StatusText.Text = "Select optimizations above, then click Run."
    }
}

function New-SectionHeader {
    param([string]$Label, [string]$Color, [string]$CatId)

    $border = [System.Windows.Controls.Border]::new()
    $border.Background = [System.Windows.Media.SolidColorBrush]([System.Windows.Media.ColorConverter]::ConvertFromString("#0e0e1a"))
    $border.BorderThickness = [System.Windows.Thickness]::new(0, 0, 0, 1)
    $border.BorderBrush = [System.Windows.Media.SolidColorBrush]([System.Windows.Media.ColorConverter]::ConvertFromString("#1e1e35"))
    $border.Margin = [System.Windows.Thickness]::new(0, 0, 0, 2)
    $border.Padding = [System.Windows.Thickness]::new(12, 8, 12, 8)

    $grid = [System.Windows.Controls.Grid]::new()
    $col1 = [System.Windows.Controls.ColumnDefinition]::new(); $col1.Width = [System.Windows.GridLength]::new(1, [System.Windows.GridUnitType]::Star)
    $col2 = [System.Windows.Controls.ColumnDefinition]::new(); $col2.Width = [System.Windows.GridLength]::Auto
    $grid.ColumnDefinitions.Add($col1)
    $grid.ColumnDefinitions.Add($col2)

    # Accent bar + label
    $sp = [System.Windows.Controls.StackPanel]::new()
    $sp.Orientation = [System.Windows.Controls.Orientation]::Horizontal

    $accent = [System.Windows.Controls.Border]::new()
    $accent.Width = 4; $accent.Height = 18
    $accent.Background = [System.Windows.Media.SolidColorBrush]([System.Windows.Media.ColorConverter]::ConvertFromString($Color))
    $accent.CornerRadius = [System.Windows.CornerRadius]::new(2)
    $accent.Margin = [System.Windows.Thickness]::new(0, 0, 10, 0)

    $lbl = [System.Windows.Controls.TextBlock]::new()
    $lbl.Text = $Label
    $lbl.FontSize = 12; $lbl.FontWeight = "SemiBold"
    $lbl.Foreground = [System.Windows.Media.SolidColorBrush]([System.Windows.Media.ColorConverter]::ConvertFromString("#e2e8f0"))
    $lbl.VerticalAlignment = "Center"

    $sp.Children.Add($accent) | Out-Null
    $sp.Children.Add($lbl)    | Out-Null
    [System.Windows.Controls.Grid]::SetColumn($sp, 0)
    $grid.Children.Add($sp)   | Out-Null

    # All / None buttons
    $btnSp = [System.Windows.Controls.StackPanel]::new()
    $btnSp.Orientation = [System.Windows.Controls.Orientation]::Horizontal

    foreach ($lbl2 in @("ALL", "NONE")) {
        $btn = [System.Windows.Controls.Button]::new()
        $btn.Content = $lbl2
        $btn.FontFamily = [System.Windows.Media.FontFamily]::new("Consolas, Courier New")
        $btn.FontSize = 9
        $btn.Background = [System.Windows.Media.SolidColorBrush]([System.Windows.Media.ColorConverter]::ConvertFromString("#1e1e35"))
        $btn.Foreground = [System.Windows.Media.SolidColorBrush]([System.Windows.Media.ColorConverter]::ConvertFromString("#64748b"))
        $btn.BorderBrush = [System.Windows.Media.SolidColorBrush]([System.Windows.Media.ColorConverter]::ConvertFromString("#2d2d50"))
        $btn.BorderThickness = [System.Windows.Thickness]::new(1)
        $btn.Padding = [System.Windows.Thickness]::new(8, 2, 8, 2)
        $btn.Margin = [System.Windows.Thickness]::new(4, 0, 0, 0)
        $btn.Cursor = [System.Windows.Input.Cursors]::Hand

        $catIdCapture = $CatId
        $selectAll = ($lbl2 -eq "ALL")

        $btn.Add_Click({
            $cat = $Categories | Where-Object { $_.Id -eq $catIdCapture }
            foreach ($item in $cat.Items) {
                if ($Script:CheckBoxes.ContainsKey($item.Id)) {
                    $Script:CheckBoxes[$item.Id].IsChecked = $selectAll
                }
            }
            Update-SelectionDisplay
        }.GetNewClosure())

        $btnSp.Children.Add($btn) | Out-Null
    }

    [System.Windows.Controls.Grid]::SetColumn($btnSp, 1)
    $grid.Children.Add($btnSp) | Out-Null

    $border.Child = $grid
    return $border
}

function New-ItemCheckBox {
    param($Item)

    $outer = [System.Windows.Controls.Border]::new()
    $outer.Padding = [System.Windows.Thickness]::new(12, 6, 12, 6)
    $outer.Margin = [System.Windows.Thickness]::new(0, 0, 0, 1)
    $outer.Background = [System.Windows.Media.SolidColorBrush]([System.Windows.Media.ColorConverter]::ConvertFromString("#09091a"))

    $grid = [System.Windows.Controls.Grid]::new()
    $col1 = [System.Windows.Controls.ColumnDefinition]::new(); $col1.Width = [System.Windows.GridLength]::Auto
    $col2 = [System.Windows.Controls.ColumnDefinition]::new(); $col2.Width = [System.Windows.GridLength]::new(1, [System.Windows.GridUnitType]::Star)
    $grid.ColumnDefinitions.Add($col1)
    $grid.ColumnDefinitions.Add($col2)

    $chk = [System.Windows.Controls.CheckBox]::new()
    $chk.IsChecked = -not $Item.Warn
    $chk.VerticalAlignment = "Center"
    $chk.Margin = [System.Windows.Thickness]::new(0, 0, 12, 0)
    $chk.Cursor = [System.Windows.Input.Cursors]::Hand
    [System.Windows.Controls.Grid]::SetColumn($chk, 0)
    $grid.Children.Add($chk) | Out-Null

    $textSp = [System.Windows.Controls.StackPanel]::new()
    $textSp.Cursor = [System.Windows.Input.Cursors]::Hand

    $labelColor = if ($Item.Warn) { "#f97316" } else { "#cbd5e1" }
    $labelText = $Item.Label
    if ($Item.Warn) { $labelText = "⚠  " + $labelText }

    $labelTb = [System.Windows.Controls.TextBlock]::new()
    $labelTb.Text = $labelText
    $labelTb.FontSize = 11
    $labelTb.FontWeight = "SemiBold"
    $labelTb.Foreground = [System.Windows.Media.SolidColorBrush]([System.Windows.Media.ColorConverter]::ConvertFromString($labelColor))
    $labelTb.TextWrapping = "Wrap"

    $detailTb = [System.Windows.Controls.TextBlock]::new()
    $detailTb.Text = $Item.Detail
    $detailTb.FontSize = 10
    $detailTb.Foreground = [System.Windows.Media.SolidColorBrush]([System.Windows.Media.ColorConverter]::ConvertFromString("#475569"))
    $detailTb.TextWrapping = "Wrap"
    $detailTb.Margin = [System.Windows.Thickness]::new(0, 2, 0, 0)

    $textSp.Children.Add($labelTb)  | Out-Null
    $textSp.Children.Add($detailTb) | Out-Null
    [System.Windows.Controls.Grid]::SetColumn($textSp, 1)
    $grid.Children.Add($textSp) | Out-Null

    # Clicking the row toggles the checkbox
    $outer.Add_MouseLeftButtonDown({
        $chk.IsChecked = -not $chk.IsChecked
        Update-SelectionDisplay
    }.GetNewClosure())

    $chk.Add_Checked({ Update-SelectionDisplay })
    $chk.Add_Unchecked({ Update-SelectionDisplay })

    $outer.Child = $grid

    $Script:CheckBoxes[$Item.Id] = $chk
    return $outer
}

#endregion

#region ── Populate Categories ────────────────────────────────────────────────

foreach ($cat in $Categories) {
    # Section header
    $CategoriesPanel.Children.Add((New-SectionHeader -Label $cat.Label -Color $cat.Color -CatId $cat.Id)) | Out-Null

    # Item rows
    $itemContainer = [System.Windows.Controls.Border]::new()
    $itemContainer.Background = [System.Windows.Media.SolidColorBrush]([System.Windows.Media.ColorConverter]::ConvertFromString("#09091a"))
    $itemContainer.BorderThickness = [System.Windows.Thickness]::new(0, 0, 0, 1)
    $itemContainer.BorderBrush = [System.Windows.Media.SolidColorBrush]([System.Windows.Media.ColorConverter]::ConvertFromString("#1e1e35"))
    $itemContainer.Margin = [System.Windows.Thickness]::new(0, 0, 0, 12)

    $itemStack = [System.Windows.Controls.StackPanel]::new()

    foreach ($item in $cat.Items) {
        $itemStack.Children.Add((New-ItemCheckBox -Item $item)) | Out-Null
    }

    $itemContainer.Child = $itemStack
    $CategoriesPanel.Children.Add($itemContainer) | Out-Null
}

#endregion

#region ── Populate BIOS Panel ────────────────────────────────────────────────

$BiosData = @(
    @{ Setting = "C-States";                   Value = "Disabled"; Why = "Prevents CPU micro-sleep cycles that cause DPC latency spikes. Most impactful BIOS tweak for audio."; Path = "Intel: Advanced > CPU Config > CPU C States | AMD: Advanced > AMD CBS > Global C-state Control" },
    @{ Setting = "CPU Enhanced Halt (C1E)";    Value = "Disabled"; Why = "A shallow sleep state often missed even when C-States are 'disabled' — causes micro-latency on halt/resume."; Path = "Intel: Advanced > CPU Config > C1E Support | AMD: Part of C-state hierarchy" },
    @{ Setting = "Hyper-Threading / SMT";      Value = "Disabled"; Why = "Shared cores introduce scheduling jitter. Most impactful on Intel 12th/13th gen P/E core systems."; Path = "Intel: Advanced > CPU Config > Hyper-Threading | AMD: Advanced > AMD CBS > SMT Mode" },
    @{ Setting = "SpeedStep / Cool'n'Quiet";   Value = "Disabled"; Why = "Dynamic clock scaling causes micro-latency as CPU ramps up under load. Redundant with powercfg but BIOS is more absolute."; Path = "Intel: Advanced > CPU Config > Intel SpeedStep (EIST) | AMD: Advanced > Cool'n'Quiet" },
    @{ Setting = "Turbo Boost / Precision Boost"; Value = "Disabled"; Why = "Burst clocking can trigger thermal throttle mid-show. Test under your actual plugin load before deciding."; Path = "Intel: Advanced > CPU Config > Turbo Boost | AMD: Advanced > Precision Boost Overdrive" },
    @{ Setting = "HPET (High Precision Event Timer)"; Value = "Enabled"; Why = "Hardware-accurate clock source. Pair with bcdedit useplatformclock for older hardware. Not needed on modern Intel/AMD with invariant TSC."; Path = "ASUS: Advanced > ACPI Settings > HPET | MSI: Advanced > Windows OS Config > HPET" },
    @{ Setting = "Onboard Audio";              Value = "Disabled"; Why = "Frees an IRQ and removes the onboard audio driver from the DPC chain. On a dedicated Dante/plugin server, onboard audio is pure latency overhead."; Path = "Advanced > Onboard Devices > HD Audio Controller | Gigabyte: Peripherals > Realtek Audio" },
    @{ Setting = "IOMMU / VT-d / AMD-Vi";     Value = "Disabled"; Why = "Virtualization I/O remapping adds interrupt overhead on every DMA transfer. Disable unless running VMs."; Path = "Intel: Advanced > CPU Config > VT-d | AMD: Advanced > AMD PBS > IOMMU" }
)

$BiosPanel.Children.Add($(
    $note = [System.Windows.Controls.Border]::new()
    $note.Background = [System.Windows.Media.SolidColorBrush]([System.Windows.Media.ColorConverter]::ConvertFromString("#0b0b1a"))
    $note.BorderThickness = [System.Windows.Thickness]::new(3, 0, 0, 0)
    $note.BorderBrush = [System.Windows.Media.SolidColorBrush]([System.Windows.Media.ColorConverter]::ConvertFromString("#6366f1"))
    $note.Padding = [System.Windows.Thickness]::new(14, 10, 14, 10)
    $note.Margin = [System.Windows.Thickness]::new(0, 0, 0, 16)
    $tb = [System.Windows.Controls.TextBlock]::new()
    $tb.Text = "These settings cannot be scripted — set manually in your motherboard BIOS before booting into Windows."
    $tb.FontSize = 11; $tb.Foreground = [System.Windows.Media.SolidColorBrush]([System.Windows.Media.ColorConverter]::ConvertFromString("#94a3b8"))
    $tb.TextWrapping = "Wrap"
    $note.Child = $tb
    $note
)) | Out-Null

foreach ($item in $BiosData) {
    $border = [System.Windows.Controls.Border]::new()
    $border.Background = [System.Windows.Media.SolidColorBrush]([System.Windows.Media.ColorConverter]::ConvertFromString("#0e0e1a"))
    $border.BorderThickness = [System.Windows.Thickness]::new(0, 0, 0, 1)
    $border.BorderBrush = [System.Windows.Media.SolidColorBrush]([System.Windows.Media.ColorConverter]::ConvertFromString("#1e1e35"))
    $border.Padding = [System.Windows.Thickness]::new(14, 10, 14, 10)
    $border.Margin = [System.Windows.Thickness]::new(0, 0, 0, 2)

    $sp = [System.Windows.Controls.StackPanel]::new()

    $headerSp = [System.Windows.Controls.StackPanel]::new()
    $headerSp.Orientation = [System.Windows.Controls.Orientation]::Horizontal

    $settingTb = [System.Windows.Controls.TextBlock]::new()
    $settingTb.Text = $item.Setting
    $settingTb.FontSize = 12; $settingTb.FontWeight = "SemiBold"
    $settingTb.Foreground = [System.Windows.Media.SolidColorBrush]([System.Windows.Media.ColorConverter]::ConvertFromString("#e2e8f0"))

    $valBorder = [System.Windows.Controls.Border]::new()
    $valBorder.Background = [System.Windows.Media.SolidColorBrush]([System.Windows.Media.ColorConverter]::ConvertFromString("#0d2010"))
    $valBorder.BorderBrush = [System.Windows.Media.SolidColorBrush]([System.Windows.Media.ColorConverter]::ConvertFromString("#14532d"))
    $valBorder.BorderThickness = [System.Windows.Thickness]::new(1)
    $valBorder.Padding = [System.Windows.Thickness]::new(8, 2, 8, 2)
    $valBorder.Margin = [System.Windows.Thickness]::new(12, 0, 0, 0)
    $valBorder.VerticalAlignment = "Center"
    $valTb = [System.Windows.Controls.TextBlock]::new()
    $valTb.Text = "→ " + $item.Value
    $valTb.FontSize = 9; $valTb.Foreground = [System.Windows.Media.SolidColorBrush]([System.Windows.Media.ColorConverter]::ConvertFromString("#4ade80"))
    $valBorder.Child = $valTb

    $headerSp.Children.Add($settingTb) | Out-Null
    $headerSp.Children.Add($valBorder) | Out-Null

    $whyTb = [System.Windows.Controls.TextBlock]::new()
    $whyTb.Text = $item.Why
    $whyTb.FontSize = 10; $whyTb.Foreground = [System.Windows.Media.SolidColorBrush]([System.Windows.Media.ColorConverter]::ConvertFromString("#64748b"))
    $whyTb.TextWrapping = "Wrap"; $whyTb.Margin = [System.Windows.Thickness]::new(0, 4, 0, 0)

    $pathTb = [System.Windows.Controls.TextBlock]::new()
    $pathTb.Text = "📍 " + $item.Path
    $pathTb.FontSize = 10; $pathTb.Foreground = [System.Windows.Media.SolidColorBrush]([System.Windows.Media.ColorConverter]::ConvertFromString("#475569"))
    $pathTb.TextWrapping = "Wrap"; $pathTb.Margin = [System.Windows.Thickness]::new(0, 4, 0, 0)

    $sp.Children.Add($headerSp) | Out-Null
    $sp.Children.Add($whyTb)   | Out-Null
    $sp.Children.Add($pathTb)  | Out-Null

    $border.Child = $sp
    $BiosPanel.Children.Add($border) | Out-Null
}

#endregion

#region ── Populate Manual Steps Panel ───────────────────────────────────────

$ManualData = @(
    @{ Title = "Uninstall Intel RST (if not using RAID)"; Tag = "HIGH IMPACT"; Steps = @(
        "Open Control Panel > Programs and Features",
        "Find 'Intel Rapid Storage Technology' and uninstall",
        "Windows automatically reverts storage to Microsoft Standard SATA AHCI Controller",
        "Reboot — verify in Device Manager: should show Standard SATA AHCI Controller",
        "Run LatencyMon 30+ min to confirm storport.sys spikes are gone",
        "WARNING: Do NOT uninstall if running a RAID array — data will be inaccessible" ) },
    @{ Title = "ISLC — Intelligent Standby List Cleaner"; Tag = "RECOMMENDED"; Steps = @(
        "Download ISLC from: wagnardsoft.com/forums/viewtopic.php?t=265",
        "Run as Administrator",
        "Set 'Purge standby list if free RAM < X MB' to ~1024 MB",
        "Set timer interval to 500ms",
        "Enable 'Start ISLC minimized and auto Start purging'" ) },
    @{ Title = "Process Lasso — CPU Affinity for DAW"; Tag = "RECOMMENDED"; Steps = @(
        "Download Process Lasso from: bitsum.com",
        "Launch your DAW or plugin host (e.g. SuperRack Performer)",
        "Right-click the process > CPU Affinity > Always > select P-cores only",
        "On i7-14700: P-cores = 0-19, E-cores = 20-27",
        "Set Priority Class > Always > Above Normal",
        "Save profile for automatic application on next launch" ) },
    @{ Title = "DDU — Clean GPU Driver Install"; Tag = "RECOMMENDED"; Steps = @(
        "Download DDU from: guru3d.com",
        "Boot into Safe Mode (Shift > Restart > Troubleshoot > Advanced > Startup Settings)",
        "Run DDU, select NVIDIA, click 'Clean and Restart'",
        "After reboot, install NVIDIA Studio Driver from nvidia.com/en-us/studio/drivers/",
        "NVIDIA Control Panel > 3D Settings > Power Management > Prefer Maximum Performance",
        "Verify with LatencyMon" ) },
    @{ Title = "IRQ Priority — Interrupt Affinity Policy Tool"; Tag = "ADVANCED"; Steps = @(
        "Search 'intpolicy.exe Microsoft download' to find the tool",
        "Run as Administrator",
        "Find your Dante PCIe card (e.g. Marian Clara E) in the device list",
        "Set interrupt affinity to a dedicated P-core (avoid core 0 — handles many system interrupts)",
        "Optionally pin GPU to a different core to separate DPC chains",
        "Always test changes with LatencyMon — some settings can worsen latency" ) },
    @{ Title = "GeForce Experience — Full Uninstall"; Tag = "RECOMMENDED"; Steps = @(
        "Control Panel > Programs and Features > Uninstall 'NVIDIA GeForce Experience'",
        "Check services.msc for remaining NvContainer entries and stop/delete them",
        "GPU driver is unaffected — GeForce Experience is separate",
        "Future drivers: DDU + manual download from nvidia.com/drivers",
        "Custom Install > select 'Display Driver' component only" ) }
)

$ManualPanel.Children.Add($(
    $note = [System.Windows.Controls.Border]::new()
    $note.Background = [System.Windows.Media.SolidColorBrush]([System.Windows.Media.ColorConverter]::ConvertFromString("#0b0a0a"))
    $note.BorderThickness = [System.Windows.Thickness]::new(3, 0, 0, 0)
    $note.BorderBrush = [System.Windows.Media.SolidColorBrush]([System.Windows.Media.ColorConverter]::ConvertFromString("#f97316"))
    $note.Padding = [System.Windows.Thickness]::new(14, 10, 14, 10)
    $note.Margin = [System.Windows.Thickness]::new(0, 0, 0, 16)
    $tb = [System.Windows.Controls.TextBlock]::new()
    $tb.Text = "These items require manual execution or third-party software — they cannot be safely scripted."
    $tb.FontSize = 11; $tb.Foreground = [System.Windows.Media.SolidColorBrush]([System.Windows.Media.ColorConverter]::ConvertFromString("#94a3b8"))
    $tb.TextWrapping = "Wrap"
    $note.Child = $tb
    $note
)) | Out-Null

$TagColors = @{ "HIGH IMPACT" = "#f97316"; "RECOMMENDED" = "#f59e0b"; "ADVANCED" = "#a78bfa" }

foreach ($item in $ManualData) {
    $border = [System.Windows.Controls.Border]::new()
    $border.Background = [System.Windows.Media.SolidColorBrush]([System.Windows.Media.ColorConverter]::ConvertFromString("#0e0e1a"))
    $border.BorderThickness = [System.Windows.Thickness]::new(0, 0, 0, 1)
    $border.BorderBrush = [System.Windows.Media.SolidColorBrush]([System.Windows.Media.ColorConverter]::ConvertFromString("#1e1e35"))
    $border.Padding = [System.Windows.Thickness]::new(14, 10, 14, 10)
    $border.Margin = [System.Windows.Thickness]::new(0, 0, 0, 2)

    $sp = [System.Windows.Controls.StackPanel]::new()

    $headerSp = [System.Windows.Controls.StackPanel]::new()
    $headerSp.Orientation = [System.Windows.Controls.Orientation]::Horizontal

    $titleTb = [System.Windows.Controls.TextBlock]::new()
    $titleTb.Text = $item.Title
    $titleTb.FontSize = 12; $titleTb.FontWeight = "SemiBold"
    $titleTb.Foreground = [System.Windows.Media.SolidColorBrush]([System.Windows.Media.ColorConverter]::ConvertFromString("#e2e8f0"))

    $tagColor = $TagColors[$item.Tag]
    $tagBorder = [System.Windows.Controls.Border]::new()
    $tagBorder.Background = [System.Windows.Media.SolidColorBrush]([System.Windows.Media.ColorConverter]::ConvertFromString("#1c0800"))
    $tagBorder.BorderBrush = [System.Windows.Media.SolidColorBrush]([System.Windows.Media.ColorConverter]::ConvertFromString($tagColor))
    $tagBorder.BorderThickness = [System.Windows.Thickness]::new(1)
    $tagBorder.Padding = [System.Windows.Thickness]::new(8, 2, 8, 2)
    $tagBorder.Margin = [System.Windows.Thickness]::new(10, 0, 0, 0)
    $tagBorder.VerticalAlignment = "Center"
    $tagTb = [System.Windows.Controls.TextBlock]::new()
    $tagTb.Text = $item.Tag; $tagTb.FontSize = 9
    $tagTb.Foreground = [System.Windows.Media.SolidColorBrush]([System.Windows.Media.ColorConverter]::ConvertFromString($tagColor))
    $tagBorder.Child = $tagTb

    $headerSp.Children.Add($titleTb) | Out-Null
    $headerSp.Children.Add($tagBorder) | Out-Null
    $sp.Children.Add($headerSp) | Out-Null

    $num = 1
    foreach ($step in $item.Steps) {
        $stepSp = [System.Windows.Controls.StackPanel]::new()
        $stepSp.Orientation = [System.Windows.Controls.Orientation]::Horizontal
        $stepSp.Margin = [System.Windows.Thickness]::new(0, 4, 0, 0)

        $numTb = [System.Windows.Controls.TextBlock]::new()
        $numTb.Text = "$num."
        $numTb.Width = 20; $numTb.FontSize = 10
        $numTb.Foreground = [System.Windows.Media.SolidColorBrush]([System.Windows.Media.ColorConverter]::ConvertFromString("#f97316"))

        $stepTb = [System.Windows.Controls.TextBlock]::new()
        $stepTb.Text = $step; $stepTb.FontSize = 10; $stepTb.TextWrapping = "Wrap"
        $stepTb.Foreground = [System.Windows.Media.SolidColorBrush]([System.Windows.Media.ColorConverter]::ConvertFromString("#64748b"))

        $stepSp.Children.Add($numTb) | Out-Null
        $stepSp.Children.Add($stepTb) | Out-Null
        $sp.Children.Add($stepSp)    | Out-Null
        $num++
    }

    $border.Child = $sp
    $ManualPanel.Children.Add($border) | Out-Null
}

#endregion

#region ── Event Handlers ────────────────────────────────────────────────────

# Tab switching
$MainTabs.Add_SelectionChanged({
    $idx = $MainTabs.SelectedIndex
    $PanelOptimize.Visibility = if ($idx -eq 0) { "Visible" } else { "Collapsed" }
    $PanelBios.Visibility     = if ($idx -eq 1) { "Visible" } else { "Collapsed" }
    $PanelManual.Visibility   = if ($idx -eq 2) { "Visible" } else { "Collapsed" }
})

# Show/hide reboot delay options
$ChkAutoReboot.Add_Checked({   $RebootDelayPanel.Visibility = "Visible"   })
$ChkAutoReboot.Add_Unchecked({ $RebootDelayPanel.Visibility = "Collapsed" })

# Select All / Clear All
$BtnSelectAll.Add_Click({
    foreach ($chk in $Script:CheckBoxes.Values) { $chk.IsChecked = $true }
    Update-SelectionDisplay
})
$BtnSelectNone.Add_Click({
    foreach ($chk in $Script:CheckBoxes.Values) { $chk.IsChecked = $false }
    Update-SelectionDisplay
})

# Run button
$BtnRun.Add_Click({
    $selected = $Script:CheckBoxes.Keys | Where-Object { $Script:CheckBoxes[$_].IsChecked }
    if (-not $selected) {
        [System.Windows.MessageBox]::Show(
            "No optimizations selected. Please select at least one item.",
            "Nothing Selected",
            [System.Windows.MessageBoxButton]::OK,
            [System.Windows.MessageBoxImage]::Information
        ) | Out-Null
        return
    }

    $itemCount = @($selected).Count
    $confirm = [System.Windows.MessageBox]::Show(
        "Apply $itemCount optimization$(if ($itemCount -ne 1) { 's' }) to this system?`n`nA System Restore Point will $(if ($ChkRestorePoint.IsChecked) { 'be created first.' } else { 'NOT be created.' })",
        "Confirm",
        [System.Windows.MessageBoxButton]::YesNo,
        [System.Windows.MessageBoxImage]::Question
    )

    if ($confirm -ne [System.Windows.MessageBoxResult]::Yes) { return }

    # Store selections for post-window execution
    $Script:SelectedIds     = $selected
    $Script:UseRestorePoint = $ChkRestorePoint.IsChecked
    $Script:UseReboot       = $ChkAutoReboot.IsChecked
    $Script:RebootDelay     = if ($Delay15.IsChecked) { 15 } elseif ($Delay60.IsChecked) { 60 } elseif ($Delay120.IsChecked) { 120 } else { 30 }
    $Script:ShouldRun       = $true

    $Window.Close()
})

# Resize: update progress bar width
$Window.Add_SizeChanged({ Update-SelectionDisplay })

#endregion

#region ── Show Window ────────────────────────────────────────────────────────

Update-SelectionDisplay
$Window.ShowDialog() | Out-Null

#endregion

#region ── Execute Selected Items ────────────────────────────────────────────

if (-not $Script:ShouldRun) {
    Write-Host ""
    Write-Host "  Cancelled — no changes were made." -ForegroundColor Yellow
    Write-Host ""
    exit 0
}

Write-Host ""
Write-Host "  ============================================================" -ForegroundColor Cyan
Write-Host "  Audio PC Optimizer — Executing" -ForegroundColor Cyan
Write-Host "  ============================================================" -ForegroundColor Cyan
Write-Host ""

# ── System Restore Point ─────────────────────────────────────────────────────
if ($Script:UseRestorePoint) {
    Write-Host "--- Creating System Restore Point ---" -ForegroundColor Magenta
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore" `
        -Name "SystemRestorePointCreationFrequency" -Value 0 -ErrorAction SilentlyContinue
    Enable-ComputerRestore -Drive "C:\" -ErrorAction SilentlyContinue
    try {
        $rpDesc = "Audio Optimizer — $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
        Checkpoint-Computer -Description $rpDesc -RestorePointType "MODIFY_SETTINGS" -ErrorAction Stop
        Write-Host "✓ Restore point created: $rpDesc" -ForegroundColor Green
    } catch {
        Write-Warning "Could not create restore point: $_"
        $confirm = Read-Host "Continue without restore point? (Y/N)"
        if ($confirm -ne 'Y' -and $confirm -ne 'y') {
            Write-Host "  Aborted." -ForegroundColor Yellow
            exit 1
        }
    }
    Write-Host ""
}

# ── Run Selected Commands ─────────────────────────────────────────────────────
$winVer    = [System.Environment]::OSVersion.Version
$win10plus = ($winVer.Major -ge 10)
$win81plus = ($winVer.Major -gt 6) -or ($winVer.Major -eq 6 -and $winVer.Minor -ge 3)

Write-Host "Windows $($winVer.Major).$($winVer.Minor) detected." -ForegroundColor DarkGray
Write-Host ""

$done = 0
$errors = 0

foreach ($cat in $Categories) {
    $catItems = $cat.Items | Where-Object { $Script:SelectedIds -contains $_.Id }
    foreach ($item in $catItems) {
        try {
            Invoke-Expression $item.Cmd
        } catch {
            Write-Host "  ✗ Error in '$($item.Label)': $_" -ForegroundColor Red
            $errors++
        }
        $done++
        Write-Host ""
    }
}

# ── Summary ───────────────────────────────────────────────────────────────────
Write-Host "  ============================================================" -ForegroundColor Cyan
Write-Host "  Complete: $done item$(if ($done -ne 1) { 's' }) applied$(if ($errors -gt 0) { ", $errors error$(if ($errors -ne 1) { 's' })" })." -ForegroundColor Cyan
Write-Host "  Run LatencyMon for 30+ minutes after reboot to verify." -ForegroundColor Cyan
Write-Host "  ============================================================" -ForegroundColor Cyan
Write-Host ""

# ── Auto-Reboot ───────────────────────────────────────────────────────────────
if ($Script:UseReboot) {
    $delay = $Script:RebootDelay
    Write-Host "  Rebooting in $delay seconds — press Ctrl+C to cancel." -ForegroundColor Yellow
    Write-Host ""
    for ($i = $delay; $i -gt 0; $i--) {
        $pct   = [int](((($delay - $i) / $delay)) * 40)
        $bar   = "[" + ("=" * $pct) + (" " * (40 - $pct)) + "] $i s"
        Write-Host "`r  $bar" -NoNewline -ForegroundColor Yellow
        Start-Sleep -Seconds 1
    }
    Write-Host ""
    Write-Host "  Rebooting now..." -ForegroundColor Red
    Restart-Computer -Force
} else {
    Write-Host "  Reboot when ready to apply all changes." -ForegroundColor Yellow
    Write-Host ""
}

#endregion
