# build.ps1 — packages the Lambda function into a zip ready for Terraform
#
# Run this script once before `terraform apply`, and again whenever you
# change lambda_function.py. Terraform's source_code_hash will detect the
# new zip and re-upload + redeploy automatically.
#
# Usage:
#   .\build.ps1

$ScriptDir  = Split-Path -Parent $MyInvocation.MyCommand.Path
$SourceFile = Join-Path $ScriptDir "lambda_function.py"
$ZipFile    = Join-Path $ScriptDir "lambda_function.zip"

Write-Host "Packaging Lambda function..."
Compress-Archive -Path $SourceFile -DestinationPath $ZipFile -Force

$size = (Get-Item $ZipFile).Length
Write-Host "Created: $ZipFile ($size bytes)"
Write-Host ""
Write-Host "Next steps:"
Write-Host "  terraform plan"
Write-Host "  terraform apply"
