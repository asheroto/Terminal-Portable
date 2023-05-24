# Windows Terminal Portable

[Windows Terminal](https://github.com/microsoft/terminal) portable edition. It is identical to the [release by Microsoft](https://github.com/microsoft/terminal/releases), just in one quick and easy EXE.

The x64 version of Windows Terminal is included. If you want another architecture type, read below to create a custom version.

The `.portable` file has been included alongside `WindowsTerminal.exe` which is described [here](https://learn.microsoft.com/en-us/windows/terminal/distributions#windows-terminal-portable).

# Download

Download the latest version in releases. The Terminal Portable release version will always match the Windows Terminal release version.

You only need `wtp.exe` but can use either or both. Rename if desired.

|Filename|Description|
|--|--|
|`wtp.exe`|Terminal launches using "Run as Administrator" by default|
|`wtp_user.exe`|Terminal runs as the current user by default|

# Updates / Releases

An updated version of Windows Terminal Portable should be available in the releases section within a few days of a new Windows Terminal release.

# How it Works

This is simply a self-extracting archive of the the "Terminal" folder contained in the `msixbundle` file [released here](https://github.com/microsoft/terminal/releases).

It extracts to `%temp%\Terminal-Portable` and then runs `%temp%\Terminal-Portable\Terminal\wt.exe`. Each time you run it, the folder will be deleted and recreated.

# How to Modify

**Common reasons to modify:**
- To adjust the default configuration located in `defaults.json`
- To include extra files/scripts
- To create your own portable using a different version

**Prerequisites:**
- You must have [WinRAR](https://www.rarlab.com/) installed (other archive utilities won't work because it's a WinRAR self-extracting archive)
- Enable file name extensions in Windows

**Modifying files/folders:**
- Right-click `wtp.exe` and click `Extract to "wtp\"` (you may need to choose the WinRAR option first)
- Change the files in `wtp\Terminal`
- When finished, right-click `wtp.exe` and click `Open with WinRAR`
- Click the `Terminal` folder in WinRAR and press Delete and then Yes
- Drag the `Terminal` folder you extracted into WinRAR
- **Notes:**
  - If you change the name or path of `Terminal` in WinRAR, then it will not open Terminal correctly
  - Anything you add to the root of the archive will extract to `%temp%\Terminal-Portable` (and then be deleted on next run)

**Modifying the self-extracting archive itself:**
- When finished, right-click `wtp.exe` and click `Open with WinRAR`
- Click the `SFX` button at the top right of WinRAR
- Click `Advanced SFX Options` at the bottom
- After you click OK, then OK again, WinRAR will update the EXE
- The icon will not be kept, but there are two ways to fix this:
  - Quickest method, but may not always show icon correctly:
    - In the `Text and icon` tab, specify `Load SFX icon`
    - Use `icon.ico` provided after extracting the EXE
  - Method to ensure the icon shows at all sizes:
    - Open the EXE in [Resource Hacker](http://angusj.com/resourcehacker/)
    - Double-click the `Icon` folder, then right-click the `Icon` folder and click `Replace Icon`
    - Use `icon.ico` provided after extracting the EXE
    - Don't delete the `Icon` group or it may not work as expected
- You can adjust Run as Administrator under the `Advanced` tab