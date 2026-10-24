# Update Windows and developer tools

`update-windows.ps1` checks for Windows software updates and updates supported package managers and developer tools installed on the system. It continues through failures and supports switches to skip the Windows Update or package update sections.

Run from an elevated PowerShell session for Windows Update installation:

```powershell
.\scripts\update-windows.ps1
```

Available switches:

- `-SkipWindowsUpdate` skips Windows Update.
- `-SkipPackages` skips package managers and developer tools.

The original PowerShell profile defines `u` as a shortcut to this script:

```powershell
function u {
    & (Join-Path $PSScriptRoot '..\..\Desktop\Delhi-AirCast-PS13\scripts\update-windows.ps1') @args
}
```

Update that path if you install the script elsewhere. Save your work before running updates; some may require a restart.
