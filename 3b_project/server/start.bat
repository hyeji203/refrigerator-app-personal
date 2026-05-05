@echo off
title Backend Server
echo Step 1: Setting JAVA_HOME
set JAVA_HOME=C:\Program Files\Amazon Corretto\jdk25.0.2_10

echo Step 2: Checking Oracle DB
sc query OracleServiceXE | find "RUNNING" >nul 2>&1
if %errorlevel% neq 0 (
    echo Starting OracleServiceXE...
    net start OracleServiceXE
    timeout /t 5 /nobreak >nul
) else (
    echo Oracle already running.
)

echo Step 3: Moving to backend folder
cd /d "%~dp0"
echo Current dir: %cd%

echo Step 4: Starting Spring Boot (clean build)
"C:\maven\apache-maven-3.9.6\bin\mvn.cmd" clean spring-boot:run

pause
