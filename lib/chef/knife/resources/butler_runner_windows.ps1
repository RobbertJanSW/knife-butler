$repo_name = $args[0]
$environment = $args[1]
$runlist = $args[2]

$repo = $test_data.repository

# Copy data bags from repo to databags path
mkdir -f C:\Programdata\Butler\data_bags
mkdir -f C:\Users\ADMINI~1\AppData\Local\Temp\kitchen\cache
copy-item -Recurse "C:\ProgramData\butler\cookbooks\$($repo_name)\test\fixtures\data_bags\*.*" "C:\ProgramData\butler\data_bags"
copy-item -Recurse "C:\ProgramData\butler\cookbooks\$($repo_name)\test\fixtures\data_bags\*" "C:\ProgramData\butler\data_bags"
copy-item "C:\ProgramData\butler\cookbooks\$($repo_name)\test\integration\default\encrypted_data_bag_secret" "C:\Chef"
New-Item C:\Programdata\butler\validation_key -ItemType file
copy-item "C:\ProgramData\butler\cookbooks\$($repo_name)\test\environments\*.*" "C:\Programdata\butler\environments"


c:\opscode\chef\bin\chef-client.bat -z -E $environment -c C:\ProgramData\butler\chef-solo.rb -o "$runlist" -L C:\chef\client.log
# Register exit for bootstrap console cmd script
$LASTEXITCODE | Out-File -FilePath C:\chef\ps_exitcode.txt
# Remove log to trigger continuation of bootstrap console script
while (Test-Path 'C:\chef\client.log') { Remove-Item 'C:\chef\client.log' -Force -ErrorAction SilentlyContinue }
