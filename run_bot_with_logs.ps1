Set-Location "c:\Users\usuario\Documents\2"

# Create output file
$outfile = "bot_live_output.txt"
"[$(Get-Date)] Starting bot with live logging..." | Out-File $outfile -Append

# Run Python with real-time output
& python main.py 2>&1 | ForEach-Object {
    $_ | Out-File $outfile -Append
    Write-Host $_
}