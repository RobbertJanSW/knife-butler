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
mkdir -f $($runpath)\data_bags
mkdir -f C:\Users\ADMINI~1\AppData\Local\Temp\kitchen\cache
copy-item -Recurse "C:\ProgramData\butler\cookbooks\$($repo_name)\test\fixtures\data_bags\*.*" "$($runpath)\data_bags"
copy-item -Recurse "C:\ProgramData\butler\cookbooks\$($repo_name)\test\fixtures\data_bags\*" "$($runpath)\data_bags"
copy-item "C:\ProgramData\butler\cookbooks\$($repo_name)\test\integration\default\encrypted_data_bag_secret" "C:\Chef"
New-Item C:\Programdata\butler\validation_key -ItemType file
copy-item "C:\ProgramData\butler\cookbooks\$($repo_name)\test\environments\*.*" "$($runpath)\environments"

if ($environment.length -gt 3) {
  # Runlist run
  c:\opscode\chef\bin\chef-client.bat -z -E $environment -c C:\ProgramData\butler\chef-solo.rb -o "$runlist" -L C:\chef\client.log
} else {
  Add-Content -Path C:\ProgramData\butler\cookbooks\config.rb -Value ""
  Add-Content -Path C:\ProgramData\butler\cookbooks\config.rb -Value "use_policyfile true"
  Add-Content -Path C:\ProgramData\butler\cookbooks\config.rb -Value "versioned_cookbooks true"
  Add-Content -Path C:\ProgramData\butler\cookbooks\config.rb -Value "policy_document_native_api true"
  Add-Content -Path C:\ProgramData\butler\cookbooks\config.rb -Value "policy_name 'build'"
  Add-Content -Path C:\ProgramData\butler\cookbooks\config.rb -Value "policy_group 'local'"

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
