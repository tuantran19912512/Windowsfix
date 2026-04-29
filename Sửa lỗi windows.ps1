# ========================================================================================================================
# CONG CU SUA CHUA WINDOWS TOAN DIEN (TU DONG QUA WINRE) - BAN TOI UU KET HOP LOGIC V12
# ========================================================================================================================

# Thiet lap giao dien dang ngang
$Host.UI.RawUI.WindowTitle = "Cong Cu Sua Chua Windows Toan Dien (Tu Dong Qua WinRE) - V2"
$Host.UI.RawUI.BackgroundColor = "Black"
$Host.UI.RawUI.ForegroundColor = "Cyan"
Clear-Host
try {
    $mode = $host.UI.RawUI
    $size = $mode.WindowSize
    $size.Width = 120
    $size.Height = 35
    $mode.WindowSize = $size
    $mode.BufferSize = New-Object System.Management.Automation.Host.Size(120, 3000)
} catch {}

# ========================================================================================================================
# 1. KIEM TRA QUYEN ADMIN VA THU VIEN
# ========================================================================================================================
if (-Not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "========================================================================================================================" -ForegroundColor Red
    Write-Host "                     LOI: VUI LONG CHAY SCRIPT NAY BANG QUYEN QUAN TRI VIEN (RUN AS ADMINISTRATOR)                      " -ForegroundColor Red
    Write-Host "========================================================================================================================" -ForegroundColor Red
    Read-Host "Nhan Enter de thoat..."
    Exit
}

Write-Host "========================================================================================================================"
Write-Host "                                        KIEM TRA THU VIEN VA MOI TRUONG HE THONG                                        "
Write-Host "========================================================================================================================"
if (-not (Get-Command "dism.exe" -ErrorAction SilentlyContinue)) { Write-Host "[X] Thieu DISM!" -ForegroundColor Red; Exit }
if (-not (Get-Command "reagentc.exe" -ErrorAction SilentlyContinue)) { Write-Host "[X] Thieu REAgentC!" -ForegroundColor Red; Exit }
Write-Host "[OK] Thu vien he thong day du." -ForegroundColor Green
Write-Host ""

# ========================================================================================================================
# 2. XU LY VA KHOI PHUC WINRE
# ========================================================================================================================
$WinREGoc = "C:\Windows\System32\Recovery\winre.wim"
$WinRECopy = "C:\winre_xu-ly.wim"
$MountDir = "C:\MountRE"

Write-Host "[*] BUOC 1: Ép he thong nap va thu hoi file WinRE goc..." -ForegroundColor Yellow
reagentc.exe /enable | Out-Null
Start-Sleep -Seconds 2
reagentc.exe /disable | Out-Null
Start-Sleep -Seconds 2

if (-not (Test-Path $WinREGoc)) {
    Write-Host "[X] KHONG TIM THAY LOI WINRE! File winre.wim da bi xoa hoac hong hoan toan." -ForegroundColor Red
    Read-Host "Nhan Enter de thoat..."
    Exit
}

Write-Host "[*] BUOC 2: Chuan bi moi truong an toan (Tranh khoa file)..." -ForegroundColor Yellow
if (Test-Path $MountDir) { 
    dism.exe /Unmount-Image /MountDir:$MountDir /Discard | Out-Null
    Remove-Item -Recurse -Force $MountDir 
}
New-Item -ItemType Directory -Path $MountDir | Out-Null

Copy-Item $WinREGoc $WinRECopy -Force
Set-ItemProperty $WinRECopy IsReadOnly $false

Write-Host "[*] BUOC 3: Dang giai nen (Mount) ban sao cua WinRE..." -ForegroundColor Yellow
$dismMount = Start-Process -FilePath "dism.exe" -ArgumentList "/Mount-Image /ImageFile:`"$WinRECopy`" /Index:1 /MountDir:`"$MountDir`"" -Wait -NoNewWindow -PassThru
if ($dismMount.ExitCode -ne 0) {
    Write-Host "[X] Loi khi mount winre.wim!" -ForegroundColor Red
    dism /Cleanup-Wim | Out-Null
    Exit
}

# ========================================================================================================================
# 3. NHUNG KICH BAN SUA CHUA VAO WINRE
# ========================================================================================================================
Write-Host "[*] BUOC 4: Dang ghi kịch bản tự động hóa (SFC & DISM)..." -ForegroundColor Yellow

$autoScriptPath = "$MountDir\Windows\System32\AutoRepair_WinRE.cmd"
$winpeShlPath = "$MountDir\Windows\System32\winpeshl.ini"

$autoScriptContent = @"
@echo off
wpeinit
echo ===============================================================================
echo             DANG TU DONG SUA CHUA WINDOWS OFFLINE TRONG WINRE                  
echo ===============================================================================
echo Dang tim o dia chua he dieu hanh Windows...
set "OSDrive="
for %%I in (C D E F G H I J K L M N O P Q R S T U V W X Y Z) do (
    if exist "%%I:\Windows\System32\cmd.exe" set "OSDrive=%%I:"
)
if not defined OSDrive (
    echo [X] Khong tim thay o dia Windows!
    ping 127.0.0.1 -n 5 >nul
    wpeutil reboot
    exit
)
echo [OK] Da tim thay Windows tai o: %OSDrive%
echo.
echo [*] Dang chay DISM RestoreHealth...
dism /image:%OSDrive%\ /cleanup-image /restorehealth
echo.
echo [*] Dang chay SFC ScanNow...
sfc /scannow /offbootdir=%OSDrive%\ /offwindir=%OSDrive%\Windows
echo.
echo [OK] QUA TRINH SUA CHUA DA HOAN TAT! HE THONG SE KHOI DONG LAI SAU 5 GIAY...
ping 127.0.0.1 -n 6 >nul
wpeutil reboot
"@
$autoScriptContent | Out-File -FilePath $autoScriptPath -Encoding oem -Force

$winpeShlContent = @"
[LaunchApps]
X:\Windows\System32\AutoRepair_WinRE.cmd
"@
$winpeShlContent | Out-File -FilePath $winpeShlPath -Encoding ascii -Force

# ========================================================================================================================
# 4. DONG GOI VA KHOI DONG
# ========================================================================================================================
Write-Host "[*] BUOC 5: Dang dong goi (Commit) WinRE..." -ForegroundColor Yellow
Start-Process -FilePath "dism.exe" -ArgumentList "/Unmount-Image /MountDir:`"$MountDir`" /Commit" -Wait -NoNewWindow | Out-Null
Start-Sleep -Seconds 2

Write-Host "[*] BUOC 6: Nap lai vao he thong va thiet lap boot..." -ForegroundColor Yellow
cmd.exe /c "attrib -h -s -r `"$WinREGoc`"" | Out-Null
Copy-Item $WinRECopy $WinREGoc -Force
Remove-Item $WinRECopy -Force -ErrorAction SilentlyContinue

reagentc.exe /setreimage /path C:\Windows\System32\Recovery | Out-Null
reagentc.exe /enable | Out-Null
reagentc.exe /boottore | Out-Null

Write-Host "========================================================================================================================" -ForegroundColor Green
Write-Host "                                    HOAN TAT THIET LAP! DANG CHO XAC NHAN...                                            " -ForegroundColor Green
Write-Host "========================================================================================================================" -ForegroundColor Green

# Hien thi bang thong bao GUI de xac nhan (Dang Yes/No)
Add-Type -AssemblyName System.Windows.Forms
$ThongBaoText = "Môi trường thiết lập ban đầu đã đầy đủ.`n`nBạn có muốn khởi động máy tính ngay bây giờ để tiến hành sửa chữa hay không?"
$ThongBaoTieuDe = "Xác nhận khởi động"
$KetQuaLuaChon = [System.Windows.Forms.MessageBox]::Show($ThongBaoText, $ThongBaoTieuDe, "YesNo", "Question")

# Xu ly lua chon cua nguoi dung
if ($KetQuaLuaChon -eq "Yes") {
    Write-Host "Dang tien hanh khoi dong lai..." -ForegroundColor Cyan
    Restart-Computer -Force
} else {
    Write-Host "`n[OK] Da huy khoi dong lai. He thong se tu dong tien hanh sua chua vao lan khoi dong ke tiep." -ForegroundColor Yellow
    Start-Sleep -Seconds 5
}