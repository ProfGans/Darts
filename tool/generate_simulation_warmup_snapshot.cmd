@echo off
setlocal
set "SIM_WARMUP_START_RADIUS=%~1"
set "SIM_WARMUP_END_RADIUS=%~2"
set "SIM_WARMUP_OUTPUT_PATH=%~3"

if "%SIM_WARMUP_START_RADIUS%"=="" set "SIM_WARMUP_START_RADIUS=90"
if "%SIM_WARMUP_END_RADIUS%"=="" set "SIM_WARMUP_END_RADIUS=110"
if "%SIM_WARMUP_OUTPUT_PATH%"=="" set "SIM_WARMUP_OUTPUT_PATH=assets/data/bundled_simulation_warmup_snapshot.json"

flutter test --no-pub test/manual/generate_simulation_warmup_snapshot_test.dart
endlocal
