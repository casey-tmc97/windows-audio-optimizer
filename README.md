# TMC Audio PC Optimizer

A WinUtil-style Windows real-time audio optimizer for live broadcast and studio production.  
Built by **Texas Music Cafe** — Live Broadcast Engineering.

---

## Usage

Open an **elevated PowerShell terminal** (right-click → Run as administrator) and run:

```powershell
irm https://raw.githubusercontent.com/casey-tmc97/windows-audio-optimizer/main/winutil.ps1 | iex
```

A native Windows GUI launches in the same terminal session. Select your optimizations, click **Run**, and the script executes with live output streamed directly to the terminal.

> The script will auto-elevate itself via UAC if run without admin rights.

---

## What It Does

A tabbed WPF interface covering 8 optimization categories:

| Category | Items | Highlights |
|----------|-------|------------|
| Power & CPU | 8 | Core parking, C-states, PCIe ASPM, USB Root Hub |
| Boot Config | 3 | Dynamic tick, TSC sync, platform clock |
| Network & Drivers | 9 | EEE, interrupt moderation, flow control, NVIDIA HD Audio, Intel RST |
| Services | 7 | Search indexer, SysMain, Windows Update, BITS, telemetry |
| Scheduled Tasks | 7 | Defender scan timer, UpdateOrchestrator, W32Time, NVIDIA tasks |
| Scheduler & Threading | 3 | MMCSS Pro Audio, SystemResponsiveness, timer resolution |
| Visual & UI | 2 | Visual effects, system sounds |
| Storage & I/O | 3 | Disk sleep, prefetch, BitLocker |

**BIOS Checklist tab** — vendor-specific navigation paths for C-States, HT/SMT, SpeedStep, HPET, and more.

**Manual Steps tab** — step-by-step guides for Intel RST uninstall, ISLC, Process Lasso CPU affinity, DDU clean GPU install, and IRQ priority tuning.

---

## Script Options

Before running, toggle these in the GUI:

- **Create System Restore Point** (on by default) — snapshots the system before any changes, with a confirm prompt if creation fails
- **Auto-Reboot** (off by default) — reboots after completion with a configurable countdown (15s / 30s / 1m / 2m)

---

## Why This Exists

Windows ships with many power-saving and background-processing features that cause **DPC latency spikes** — the root cause of audio dropouts, buffer underruns, and the "fine for 15 minutes then dropout" pattern you'll see in [LatencyMon](https://www.resplendence.com/latencymon).

This tool specifically targets:

- The **periodic 15-minute spike** pattern caused by Defender scan tasks, W32Time NTP sync, and Intel RST timer callbacks
- **ndis.sys** latency from EEE, NIC power management, flow control, and IPv6 multicast activity
- **ntoskrnl.exe** spikes from core parking, MSI interrupts, and Update Orchestrator
- **storport.sys** spikes from Intel RST and scheduled defrag
- **nvlddmkm.sys** spikes from NVIDIA GeForce Experience tasks

---

## Requirements

- Windows 7 or later
- PowerShell 5.0+ (included in Win 10/11; available for Win 7/8 via WMF 5.1)
- .NET 4.5+ (required for WPF GUI — included in Win 8+, installable on Win 7)
- Administrator rights (auto-requested via UAC)

---

## Tested Equipment

- **Plugin servers:** Waves SuperRack LiveBox (Dante), custom Win 10 LTSC builds
- **FOH consoles:** Midas M32, Allen & Heath Avantis, Yamaha CL/QL series
- **Broadcast:** HP Z840, Lenovo ThinkStation (Dante Virtual Soundcard + Waves)
- **DAW workstations:** Various Intel 10th–14th gen platforms

---

## Run Locally (offline)

```powershell
# Download
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/casey-tmc97/windows-audio-optimizer/main/winutil.ps1" -OutFile "winutil.ps1"

# Run
powershell -ExecutionPolicy Bypass -File winutil.ps1
```

---

## Safety

- All changes are logged to the terminal in real time
- System Restore Point created before any changes (enabled by default)
- Items marked ⚠ are unchecked by default and require deliberate selection
- To undo all changes: Control Panel → System → System Protection → System Restore

---

## Credits

Developed for live broadcast concert production at Texas Music Cafe (TMC), Waco TX.  
Research sources: Steinberg forums, Gearspace, ResidentAdvisor, Microsoft documentation, LatencyMon community reports.
