$ErrorActionPreference='Stop'
$taskPrivate=Join-Path $env:USERPROFILE '.codex\.secrets\draftai'
$taskSecure=(Get-Content (Join-Path $taskPrivate 'groq.dpapi') -Raw).Trim() | ConvertTo-SecureString
$env:AI_API_KEY=[System.Net.NetworkCredential]::new('', $taskSecure).Password
$taskOpenFile=Join-Path $taskPrivate 'openai.dpapi'
if (Test-Path -LiteralPath $taskOpenFile) {
  $taskOpenSecure=(Get-Content $taskOpenFile -Raw).Trim() | ConvertTo-SecureString
  $env:AI_PRO_API_KEY=[System.Net.NetworkCredential]::new('', $taskOpenSecure).Password
}
$env:DRAFTAI_STATE_DIR=Join-Path $taskPrivate 'runtime'
try { & node (Join-Path $PSScriptRoot 'debug-server.mjs') }
finally { Remove-Item Env:AI_API_KEY,Env:AI_PRO_API_KEY -ErrorAction SilentlyContinue }
