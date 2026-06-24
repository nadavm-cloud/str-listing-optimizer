@echo off
REM ===== STR Listing Optimizer — one-click launcher =====
REM Double-click this file. It will pop up a box to paste the listing URL,
REM run the full analysis, and open the finished PDF.
title STR Listing Optimizer
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0run_report.ps1" %*
