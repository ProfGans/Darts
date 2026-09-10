param(
  [int]$StartRadius = 90,
  [int]$EndRadius = 110,
  [string]$OutputPath = "assets/data/bundled_simulation_warmup_snapshot.json"
)

$env:SIM_WARMUP_START_RADIUS = "$StartRadius"
$env:SIM_WARMUP_END_RADIUS = "$EndRadius"
$env:SIM_WARMUP_OUTPUT_PATH = $OutputPath

try {
  flutter test --no-pub test/manual/generate_simulation_warmup_snapshot_test.dart
}
finally {
  Remove-Item Env:SIM_WARMUP_START_RADIUS -ErrorAction SilentlyContinue
  Remove-Item Env:SIM_WARMUP_END_RADIUS -ErrorAction SilentlyContinue
  Remove-Item Env:SIM_WARMUP_OUTPUT_PATH -ErrorAction SilentlyContinue
}
