# Windows Terminal Portable

[Windows Terminal](https://github.com/microsoft/terminal) portable edition. It is identical to the [release by Microsoft](https://github.com/microsoft/terminal/releases), just in one quick and easy EXE.

The x64 version of Windows Terminal is included. If you want another architecture type, read below to create a custom version.

The `.portable` file has been included alongside `WindowsTerminal.exe` which is described [here](https://learn.microsoft.com/en-us/windows/terminal/distributions#windows-terminal-portable).

# Download

Download the latest version in releases. The Terminal Portable release version will always match the Windows Terminal release version.

You only need `wtp_admin.exe` but can use either or both. Rename if desired.

| Filename        | Description                                               |
| --------------- | --------------------------------------------------------- |
| `wtp_admin.exe` | Terminal launches using "Run as Administrator" by default |
| `wtp_user.exe`  | Terminal runs as the current user by default              |

# Updates / Releases

An updated version of Windows Terminal Portable should be available in the releases section within a few days of a new Windows Terminal release.

# How it Works

This is simply a self-extracting archive of the the "Terminal" folder contained in the x64 `zip` file [released here](https://github.com/microsoft/terminal/releases).

It extracts to `%temp%\Terminal-Portable` and then runs `%temp%\Terminal-Portable\Terminal\wt.exe`. Each time you run it, the temp folder will be deleted and recreated.

# How to Modify

**Common reasons to modify:**
- To adjust configuration settings (see below)
- To include extra files/scripts
- To create your own portable using a different version

**Prerequisites:**
- You must have [WinRAR](https://www.rarlab.com/) installed (other archive utilities won't work because it's a WinRAR self-extracting archive)
- Enable file name extensions in Windows

**Modifying settings/appearance/etc.:**
1. Open `%TEMP%` and find the `Terminal-Portable` folder. Delete it.
2. Grab a new SFX file from [Releases](https://github.com/asheroto/Terminal-Portable/releases).
3. Run it. Then click the drop-down arrow and go to `Settings`:

![Image](https://github.com/user-attachments/assets/56388035-3110-4bd7-8a67-5b6e0f5fdb7c)

4. Change the settings you'd like to change and click `Save` when done.
5. Go to `%TEMP%\Terminal-Portable\Terminal` and you'll now find a newly created `settings` folder and `settings.json` file.
6. Update the SFX archive with both the folder and file from step 5.

**Modifying files/folders:**
1. Right-click `wtp_admin.exe` and click `Extract to "wtp\"` (you may need to choose the WinRAR option first)
2. Change the files in `wtp\Terminal`
3. When finished, right-click `wtp_admin.exe` and click `Open with WinRAR`
4. Click the `Terminal` folder in WinRAR and press Delete and then Yes
5. Drag the `Terminal` folder you extracted into WinRAR
- **Notes:**
  - If you change the name or path of `Terminal` in WinRAR, then it will not open Terminal correctly
  - Anything you add to the root of the archive will extract to `%temp%\Terminal-Portable`, then overwritten on next run

**Modifying the self-extracting archive itself:**
1. When finished, right-click `wtp_admin.exe` and click `Open with WinRAR`
2. Click the `SFX` button at the top right of WinRAR
3. Click `Advanced SFX Options` at the bottom
4. After you click OK, then OK again, WinRAR will update the EXE
5. The icon will not be kept, but there are two ways to fix this:
  - Quickest method:
    - In the `Text and icon` tab, specify `Load SFX icon`
    - Use `icon.ico` provided after extracting the EXE
  - Alternate method:
    - Open the EXE in [Resource Hacker](http://angusj.com/resourcehacker/)
    - Double-click the `Icon` folder, then right-click the `Icon` folder and click `Replace Icon`
    - Use `icon.ico` provided after extracting the EXE
    - Don't delete the `Icon` group or it may not work as expected
- You can adjust Run as Administrator under the `Advanced` tab