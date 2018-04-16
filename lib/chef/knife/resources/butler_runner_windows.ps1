# Knife-Butler runner powershell script for Windows

function zipdata_server() {
  $socket = new-object System.Net.Sockets.TcpListener('0.0.0.0', 5999);
  if($socket -eq $null){
    exit 1;
  }
  $socket.start();
  $client = $socket.AcceptTcpClient();
  $stream = $client.GetStream();
  $buffer = new-object System.Byte[] 2048;
  mkdir "C:\Programdata\Butler\"
  $file = 'C:\Programdata\Butler\butler.zip';
  $fileStream = New-Object System.IO.FileStream($file, [System.IO.FileMode]'Create', [System.IO.FileAccess]'Write');
  do
  {
    $read = $null;
    while($stream.DataAvailable -or $read -eq $null) {
        $read = $stream.Read($buffer, 0, 2048);
        if ($read -gt 0) {
          $fileStream.Write($buffer, 0, $read);
        }
      }
  } While ($read -gt 0);
  $fileStream.Close();
  $socket.Stop();
  $client.close();
  $stream.Dispose();
}

# Fetch Butler zipfile network burst
zipdata_server
# Twice because of Gitlab runner portcheck
zipdata_server

# OK Now we have the zipfile. Extract it
mkdir 'C:\Programdata\Butler\content\'
$shell=new-object -com shell.application
$ZipFile = Get-Item 'C:\Programdata\Butler\butler.zip'
$ZipFolder = $shell.namespace($ZipFile.fullname)
$Location = $shell.NameSpace('C:\Programdata\Butler\content')
$Location.Copyhere($ZipFolder.items())

# Mkdir cache folder Chef solo
mkdir C:\Programdata\Butler\cache
#c:\opscode\chef\bin\chef-client.bat -c C:\Programdata\Butler\content\chef-solo.rb -L C:\programdata\Butler\chef-run.txt
c:\opscode\chef\bin\chef-client.bat --config C:\chef\extra-files\templates\chef-solo.rb --local-mode -L C:\programdata\Butler\chef-run.txt
