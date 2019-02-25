$repo_name = $args[0]
$environment = $args[1]
$runlist = $args[2]

$repo = $test_data.repository

if ($environment.length -gt 3) {
  $runpath = 'C:\ProgramData\butler'
} else {
  $runpath = 'C:\ProgramData\butler\cookbooks'
}

# Copy data bags from repo to databags path
mkdir -f "$($runpath)\data_bags" -ErrorAction SilentlyContinue
mkdir -f "C:\Users\ADMINI~1\AppData\Local\Temp\kitchen\cache" -ErrorAction SilentlyContinue
copy-item -Recurse "C:\ProgramData\butler\cookbooks\$($repo_name)\test\fixtures\data_bags\*.*" "$($runpath)\data_bags" -ErrorAction SilentlyContinue
copy-item -Recurse "C:\ProgramData\butler\cookbooks\$($repo_name)\test\fixtures\data_bags\*" "$($runpath)\data_bags" -ErrorAction SilentlyContinue
copy-item "C:\ProgramData\butler\cookbooks\$($repo_name)\test\integration\default\encrypted_data_bag_secret" "C:\Chef" -ErrorAction SilentlyContinue
New-Item C:\Programdata\butler\validation_key -ItemType file -ErrorAction SilentlyContinue
copy-item "C:\ProgramData\butler\cookbooks\$($repo_name)\test\environments\*.*" "$($runpath)\environments" -ErrorAction SilentlyContinue

if ($environment.length -gt 3) {
  # Runlist run
  c:\opscode\chef\bin\chef-client.bat -z -E $environment -c C:\ProgramData\butler\chef-solo.rb -o "$runlist" -L C:\chef\client.log
} else {
  Add-Content -Path C:\ProgramData\butler\cookbooks\config.rb -Value ""
  Add-Content -Path C:\ProgramData\butler\cookbooks\config.rb -Value "use_policyfile true"
  Add-Content -Path C:\ProgramData\butler\cookbooks\config.rb -Value "versioned_cookbooks true"
  Add-Content -Path C:\ProgramData\butler\cookbooks\config.rb -Value "policy_document_native_api true"
  Add-Content -Path C:\ProgramData\butler\cookbooks\config.rb -Value "policy_document_native_api true"
  Add-Content -Path C:\ProgramData\butler\cookbooks\config.rb -Value "validation_key C:\Programdata\butler\validation_key"

#  Add-Content -Path C:\ProgramData\butler\cookbooks\config.rb -Value "policy_name 'build'"
#  Add-Content -Path C:\ProgramData\butler\cookbooks\config.rb -Value "policy_group 'local'"

  cd C:\ProgramData\butler\cookbooks
  c:\opscode\chef\bin\chef-client.bat -z -L C:\chef\client.log -c C:\ProgramData\butler\cookbooks\config.rb
}
# Chef manages to exit with return code 0, even when failing and creating a stacktrace file. So lets check for that:
$resultcode = $LASTEXITCODE
if (($resultcode -eq 0) -And (Test-Path C:\Users\Administrator\AppData\Local\Temp\kitchen\cache\chef-stacktrace.out)) {
  $resultcode = 7382
}
# Remove log to trigger continuation of bootstrap console script
while (Test-Path 'C:\chef\client.log') { Remove-Item 'C:\chef\client.log' -Force -ErrorAction SilentlyContinue }
# Throw error code back upstream in case of unsuccessful run
if ($resultcode -ne 0) { throw $resultcode }
$error.clear()
