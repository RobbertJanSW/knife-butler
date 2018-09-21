function wait_for_file($file) {
  while ($true) {
    if (Test-Path $file -ErrorAction SilentlyContinue) { break; }
    sleep 1
  }
}

$repo_name = $args[0]

wait_for_file('C:\ProgramData\Butler\test_data.json')

$test_data = Get-Content -Raw -Path  'C:\ProgramData\Butler\test_data.json' | ConvertFrom-Json

$repo = $test_data.repository

# Copy data bags from repo to databags path
mkdir -f C:\Programdata\Butler\data_bags
copy-item -Recurse "C:\ProgramData\butler\cookbooks\$($repo_name)\test\fixtures\data_bags" "C:\ProgramData\butler\data_bags"
copy-item "C:\ProgramData\butler\cookbooks\$($repo_name)\test\integration\default\encrypted_data_bag_secret" "C:\Chef"
New-Item C:\Programdata\butler\validation_key -ItemType file
copy-item "C:\ProgramData\butler\cookbooks\$($repo_name)\test\environments\*.*" "C:\Programdata\butler\environments"


c:\opscode\chef\bin\chef-client.bat -z -E test -c C:\ProgramData\butler\chef-solo.rb
