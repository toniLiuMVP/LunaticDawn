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
REM    winget install -e --id joncampbell123.DOSBox-X
REM    或從 https://dosbox-x.com/ 下載安裝（官方安裝程式預設裝在 C:\DOSBox-X）
REM
REM  注意：這支腳本沒有在 Windows 實機測試過。
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
REM 官方安裝程式的預設位置是系統磁碟根目錄的 DOSBox-X 資料夾
if exist "%SystemDrive%\DOSBox-X\dosbox-x.exe" set "DOSBOX=%SystemDrive%\DOSBox-X\dosbox-x.exe"
if exist "%ProgramData%\DOSBox-X\dosbox-x.exe" set "DOSBOX=%ProgramData%\DOSBox-X\dosbox-x.exe"
if exist "%LOCALAPPDATA%\DOSBox-X\dosbox-x.exe" set "DOSBOX=%LOCALAPPDATA%\DOSBox-X\dosbox-x.exe"
REM 放在遊戲資料夾內的版本放最後，找到時優先使用
if exist "%GAME_DIR%\dosbox-x\dosbox-x.exe" set "DOSBOX=%GAME_DIR%\dosbox-x\dosbox-x.exe"

REM 裝到其他位置時，官方安裝程式會把安裝位置寫進登錄檔（值名稱 Path）。
REM 只採用名稱是 Path 的那一行，不依賴 reg.exe 輸出的行數。
if not defined DOSBOX for /f "tokens=1,2,*" %%a in ('%SystemRoot%\System32\reg.exe query "HKCU\Software\DOSBox-X" /v Path 2^>nul') do if /i "%%a"=="Path" if exist "%%c\dosbox-x.exe" set "DOSBOX=%%c\dosbox-x.exe"
if not defined DOSBOX for /f "tokens=1,2,*" %%a in ('%SystemRoot%\System32\reg.exe query "HKLM\Software\DOSBox-X" /v Path 2^>nul') do if /i "%%a"=="Path" if exist "%%c\dosbox-x.exe" set "DOSBOX=%%c\dosbox-x.exe"

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
    echo       winget install -e --id joncampbell123.DOSBox-X
    echo     或到 https://dosbox-x.com/ 下載 .exe 手動安裝
    echo.
    pause
    exit /b 1
)

REM 下面的檢查刻意不用括號區塊：路徑含「)」時（例如 Luna2 (1)），
REM 括號區塊會被提前關閉，所以改用 goto 跳過錯誤訊息。

REM 檢查遊戲本體
if exist "%GAME_DIR%\LUNA2.EXE" goto :exe_ok
echo [X] 找不到 LUNA2.EXE
echo     目前路徑：%GAME_DIR%
echo.
echo     請把此啟動器（以及 dosbox-x.conf）放在和 LUNA2.EXE
echo     同一個資料夾再執行。
echo.
pause
exit /b 1
:exe_ok

REM 檢查設定檔
if exist "%GAME_DIR%\dosbox-x.conf" goto :conf_ok
echo [X] 找不到 dosbox-x.conf
echo     目前路徑：%GAME_DIR%
echo.
echo     請從吟遊詩人的傳說 · 俠客遊小站下載 dosbox-x.conf：
echo       https://toniliumvp.github.io/LunaticDawn/luna2/launcher/
echo.
pause
exit /b 1
:conf_ok

REM 檢查路徑是否包含非 ASCII 字元（中文等）
REM 先把路徑寫進暫存檔再比對，避免路徑裡的「)」弄壞 FOR /F 的語法
set "HAS_UNICODE=0"
set "LUNA2_PATHFILE=%TEMP%\luna2_path_%RANDOM%.txt"
>"%LUNA2_PATHFILE%" echo(%GAME_DIR%
findstr /r /c:"[^A-Za-z0-9_\\.:/\\-]" "%LUNA2_PATHFILE%" >nul && set "HAS_UNICODE=1"
del "%LUNA2_PATHFILE%" >nul 2>&1
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
set "REPLY="
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
