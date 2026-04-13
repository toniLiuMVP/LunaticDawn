@echo off
REM ============================================================
REM  俠客遊 II (Lunatic Dawn II) · Windows 啟動腳本
REM  吟遊詩人的傳說 · 俠客遊小站
REM  https://toniliumvp.github.io/LunaticDawn/
REM
REM  使用方式：
REM    1. 把此檔案 + dosbox-x.conf 放在和 LUNA2.EXE 同一個資料夾
REM    2. 雙擊這個 .bat 就會自動啟動遊戲
REM
REM  需要 DOSBox-X：
REM    winget install DOSBox-X.DOSBox-X
REM    或從 https://dosbox-x.com/ 下載安裝
REM ============================================================

REM 切到 UTF-8 code page 讓中文顯示正常
chcp 65001 >nul 2>&1

REM 切到腳本自身所在的目錄
cd /d "%~dp0"
set "GAME_DIR=%CD%"

echo ============================================================
echo   吟遊詩人的傳說 · 俠客遊 II 啟動器
echo   https://toniliumvp.github.io/LunaticDawn/
echo ============================================================
echo.

REM 尋找 DOSBox-X（按優先順序檢查常見位置）
set "DOSBOX="
if exist "%ProgramFiles%\DOSBox-X\dosbox-x.exe" set "DOSBOX=%ProgramFiles%\DOSBox-X\dosbox-x.exe"
if exist "%ProgramFiles(x86)%\DOSBox-X\dosbox-x.exe" set "DOSBOX=%ProgramFiles(x86)%\DOSBox-X\dosbox-x.exe"
if exist "%LOCALAPPDATA%\Programs\DOSBox-X\dosbox-x.exe" set "DOSBOX=%LOCALAPPDATA%\Programs\DOSBox-X\dosbox-x.exe"
if exist "%GAME_DIR%\dosbox-x\dosbox-x.exe" set "DOSBOX=%GAME_DIR%\dosbox-x\dosbox-x.exe"

REM 如果以上都找不到，試試 PATH
if "%DOSBOX%"=="" (
    for %%i in (dosbox-x.exe) do (
        if not "%%~$PATH:i"=="" set "DOSBOX=%%~$PATH:i"
    )
)

if "%DOSBOX%"=="" (
    echo [X] 找不到 DOSBox-X
    echo.
    echo     請先安裝 DOSBox-X：
    echo       winget install DOSBox-X.DOSBox-X
    echo     或到 https://dosbox-x.com/ 下載 .exe 手動安裝
    echo.
    pause
    exit /b 1
)

REM 檢查遊戲本體
if not exist "%GAME_DIR%\LUNA2.EXE" (
    echo [X] 找不到 LUNA2.EXE
    echo     目前路徑：%GAME_DIR%
    echo.
    echo     請把此啟動器（以及 dosbox-x.conf）放在和 LUNA2.EXE
    echo     同一個資料夾再執行。
    echo.
    pause
    exit /b 1
)

REM 檢查設定檔
if not exist "%GAME_DIR%\dosbox-x.conf" (
    echo [X] 找不到 dosbox-x.conf
    echo     目前路徑：%GAME_DIR%
    echo.
    echo     請從吟遊詩人的傳說 · 俠客遊小站下載 dosbox-x.conf：
    echo       https://toniliumvp.github.io/LunaticDawn/luna2/launcher/
    echo.
    pause
    exit /b 1
)

REM 檢查路徑是否包含非 ASCII 字元（中文等）
set "HAS_UNICODE=0"
for /f "delims=" %%a in ('echo %GAME_DIR%^| findstr /r /c:"[^A-Za-z0-9_\\.:/\\-]"') do set "HAS_UNICODE=1"
if "%HAS_UNICODE%"=="1" goto :unicode_warn
goto :unicode_ok
:unicode_warn
echo [!] 警告：遊戲路徑可能包含中文或特殊字元
echo     目前路徑：%GAME_DIR%
echo.
echo     DOSBox 可能無法正確掛載含中文的路徑。
echo     建議搬到純英文路徑，例如：
echo       D:\Games\Luna2\
echo       C:\Users\你的帳號\Games\Luna2\
echo.
set /p "REPLY=仍要繼續嗎？[y/N] "
if /i not "%REPLY%"=="y" exit /b 0
echo.
:unicode_ok

echo [OK] DOSBox-X：%DOSBOX%
echo [OK] 遊戲路徑：%GAME_DIR%
echo [OK] 設定檔：%GAME_DIR%\dosbox-x.conf
echo.
echo ^>^> 啟動遊戲 ...
echo.

REM 執行 DOSBox-X
REM   -conf      指定硬體設定檔
REM   -c         附加到 [autoexec] 後面的指令
REM
REM 我們已經 cd 到 GAME_DIR，所以 DOSBox-X 啟動時 cwd 也是這個目錄，
REM 因此 "mount c ." 就是掛載遊戲資料夾，完全不用知道實際路徑。
"%DOSBOX%" -conf "%GAME_DIR%\dosbox-x.conf" -c "mount c ." -c "c:" -c "LUNA2.EXE"

REM 遊戲結束後給使用者看結果
if errorlevel 1 (
    echo.
    echo [!] DOSBox-X 似乎有錯誤回傳，請查看上方訊息
    pause
)
