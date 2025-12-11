# Asset Analysis Runner - Simulates manual user research
Write-Host "╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║        Asset Analyzer Visual - Manual User Simulation          ║" -ForegroundColor Cyan
Write-Host "║          Searches assets and shows charts like a user          ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan

Write-Host "`n📊 Starting asset analysis..." -ForegroundColor Yellow

# Run the analyzer
python "c:\Users\usuario\Documents\2\asset_analyzer_visual.py"

Write-Host "`n✅ Analysis complete!" -ForegroundColor Green
Write-Host "📄 Report generated: asset_analysis_report.html" -ForegroundColor Cyan

# Try to open the HTML report if on Windows
if (Test-Path "asset_analysis_report.html") {
    $response = Read-Host "Open HTML report in browser? (y/n)"
    if ($response -eq 'y' -or $response -eq 'yes') {
        Start-Process "asset_analysis_report.html"
    }
}