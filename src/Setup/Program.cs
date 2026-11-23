using System;
using System.Diagnostics;
using System.IO;
using System.Reflection;
using System.Security.Principal;
using System.Text;
using Microsoft.Win32;

// Win10EmojiRefresh release setup.
// This executable contains only code + the project's PowerShell scripts.
// The Microsoft font is never embedded or redistributed.
internal static class Program
{
    private const string InstallerResource = "Win11Emoji.ps1";
    private const string FixPendingResource = "FixPending.ps1";
    private const string RegistryKey = @"SYSTEM\CurrentControlSet\Control\Session Manager";
    private const string PendingValue = "PendingFileRenameOperations";

    private static int Main(string[] args)
    {
        try
        {
            if (IsHelp(args))
            {
                PrintUsage();
                return 0;
            }

            bool elevatedFlag = false;
            string source = null;
            for (int i = 0; i < args.Length; i++)
            {
                string a = args[i];
                if (a == "--elevated")
                {
                    elevatedFlag = true;
                }
                else if (a == "--source")
                {
                    if (i + 1 >= args.Length)
                    {
                        Console.WriteLine("ERROR: --source requires a file path.");
                        Pause();
                        return 2;
                    }
                    source = Path.GetFullPath(args[++i]);
                    if (!File.Exists(source))
                    {
                        Console.WriteLine("ERROR: font file not found: " + source);
                        Pause();
                        return 2;
                    }
                }
                else
                {
                    Console.WriteLine("ERROR: unknown argument: " + a);
                    PrintUsage();
                    Pause();
                    return 2;
                }
            }

            PrintBanner();

            if (!elevatedFlag && !AskYesNo("Do you want to continue with the installation?"))
            {
                Console.WriteLine("Installation canceled by the user.");
                Pause();
                return 0;
            }

            if (!IsAdministrator())
            {
                if (!elevatedFlag)
                {
                    Console.WriteLine("Requesting administrator rights (UAC)...");
                    Console.WriteLine("Do not right-click the file and choose 'Run as administrator'; UAC is requested automatically.");
                    try
                    {
                        ProcessStartInfo psi = new ProcessStartInfo();
                        psi.FileName = Assembly.GetExecutingAssembly().Location;
                        psi.Arguments = BuildChildArguments(source);
                        psi.Verb = "RunAs";
                        psi.UseShellExecute = true;
                        Process.Start(psi);
                        Console.WriteLine("Continue in the new elevated window.");
                        Pause();
                        return 0;
                    }
                    catch (Exception ex)
                    {
                        Console.WriteLine("ERROR: could not elevate: " + ex.Message);
                        Pause();
                        return 1;
                    }
                }

                Console.WriteLine("ERROR: the elevated process does not have administrator rights.");
                Pause();
                return 1;
            }

            Console.WriteLine("Administrator: confirmed.");
            Console.WriteLine();

            string workDir = Path.Combine(
                Path.GetTempPath(),
                "Win10EmojiRefresh-Setup-" + Guid.NewGuid().ToString("N"));
            Directory.CreateDirectory(workDir);

            try
            {
                string installer = ExtractResource(InstallerResource, workDir);
                string fixPending = ExtractResource(FixPendingResource, workDir);

                Console.WriteLine("=== 1/3 PendingFileRenameOperations ===");
                string fixOutput;
                int fixCode = RunPowerShell(fixPending, "-ClearOnly", out fixOutput);
                if (fixCode != 0)
                {
                    Console.WriteLine("ERROR: could not normalize the pending rename queue.");
                    Console.WriteLine("Installation aborted to avoid corrupting the system font.");
                    Pause();
                    return fixCode;
                }

                Console.WriteLine();
                Console.WriteLine("=== 2/3 Font installation (System mode) ===");
                string installArgs = "";
                if (source != null)
                {
                    installArgs = "-Source " + Quote(source);
                }
                string installOutput;
                int installCode = RunPowerShell(installer, installArgs, out installOutput);
                if (installCode != 0)
                {
                    Console.WriteLine("ERROR: installation failed (code " + installCode + ").");
                    Pause();
                    return installCode;
                }

                Console.WriteLine();
                Console.WriteLine("=== 3/3 Reboot ===");
                bool rebootQueued = HasEmojiPending(GetPendingEntries()) ||
                                    ContainsIgnoreCase(installOutput, "Swap queued") ||
                                    ContainsIgnoreCase(installOutput, "Restart the computer");

                if (!rebootQueued)
                {
                    Console.WriteLine("No reboot is needed. Close and reopen running applications.");
                    Console.WriteLine("To verify, run verify.cmd in the project folder.");
                    return 0;
                }

                Console.WriteLine("The font swap was queued for the next boot.");
                if (AskYesNo("Do you want to restart the computer NOW?"))
                {
                    Console.WriteLine("Restarting in 10 seconds. Save your work.");
                    RunProcess("shutdown.exe", "/r /t 10 /c \"Applying the Segoe UI Emoji font\"");
                }
                else
                {
                    Console.WriteLine("Reboot not authorized. Restart manually when convenient.");
                    Console.WriteLine("After the reboot, run verify.cmd in the project folder.");
                }

                return 0;
            }
            finally
            {
                try { Directory.Delete(workDir, true); } catch { }
                Pause();
            }
        }
        catch (Exception ex)
        {
            Console.WriteLine("ERROR: " + ex.Message);
            Pause();
            return 1;
        }
    }

    private static bool IsHelp(string[] args)
    {
        foreach (string a in args)
        {
            if (a == "--help" || a == "-h" || a == "/?") return true;
        }
        return false;
    }

    private static void PrintUsage()
    {
        Console.WriteLine("Win10 Emoji Refresh - release setup");
        Console.WriteLine();
        Console.WriteLine("Usage:");
        Console.WriteLine("  Win10EmojiRefresh-Setup.exe");
        Console.WriteLine("  Win10EmojiRefresh-Setup.exe --source C:\\Downloads\\seguiemj.ttf");
        Console.WriteLine();
        Console.WriteLine("Options:");
        Console.WriteLine("  --source <file>  use a local font instead of downloading from a mirror.");
        Console.WriteLine("  --help           show this help.");
        Console.WriteLine();
        Console.WriteLine("The setup requests UAC by itself, normalizes the boot queue,");
        Console.WriteLine("installs the font in System mode, and reboots only if you allow it.");
        Console.WriteLine("No Microsoft font is included in this executable.");
    }

    private static void PrintBanner()
    {
        Console.WriteLine("============================================================");
        Console.WriteLine(" Win10 Emoji Refresh - Windows 11 emoji font for Windows 10");
        Console.WriteLine("============================================================");
        Console.WriteLine();
        Console.WriteLine("WARNING: do not right-click and choose 'Run as administrator'.");
        Console.WriteLine("The setup requests UAC by itself.");
        Console.WriteLine("Segoe UI Emoji is proprietary to Microsoft: this file does not");
        Console.WriteLine("contain it; it will be downloaded from a mirror or supplied by you.");
        Console.WriteLine();
    }

    private static string BuildChildArguments(string source)
    {
        StringBuilder sb = new StringBuilder("--elevated");
        if (source != null)
        {
            sb.Append(" --source ").Append(Quote(source));
        }
        return sb.ToString();
    }

    private static bool IsAdministrator()
    {
        WindowsIdentity identity = WindowsIdentity.GetCurrent();
        WindowsPrincipal principal = new WindowsPrincipal(identity);
        return principal.IsInRole(WindowsBuiltInRole.Administrator);
    }

    private static bool AskYesNo(string question)
    {
        Console.Write(question + " [Y/N]: ");
        string answer = Console.ReadLine();
        if (answer == null) return false;
        answer = answer.Trim();
        return answer.StartsWith("Y", StringComparison.OrdinalIgnoreCase) ||
               answer.StartsWith("S", StringComparison.OrdinalIgnoreCase);
    }

    private static string ExtractResource(string name, string workDir)
    {
        Assembly asm = Assembly.GetExecutingAssembly();
        using (Stream s = asm.GetManifestResourceStream(name))
        {
            if (s == null)
            {
                throw new ErrorException("Missing embedded resource: " + name);
            }
            string path = Path.Combine(workDir, name);
            using (FileStream fs = File.Create(path))
            {
                byte[] buffer = new byte[8192];
                int read;
                while ((read = s.Read(buffer, 0, buffer.Length)) > 0)
                {
                    fs.Write(buffer, 0, read);
                }
            }
            return path;
        }
    }

    private static int RunPowerShell(string scriptPath, string extraArguments, out string output)
    {
        StringBuilder captured = new StringBuilder();

        ProcessStartInfo psi = new ProcessStartInfo();
        psi.FileName = GetPowerShellPath();
        psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -File " + Quote(scriptPath);
        if (!string.IsNullOrEmpty(extraArguments))
        {
            psi.Arguments += " " + extraArguments;
        }
        psi.UseShellExecute = false;
        psi.CreateNoWindow = true;
        psi.RedirectStandardOutput = true;
        psi.RedirectStandardError = true;

        Process p = new Process();
        p.StartInfo = psi;
        p.OutputDataReceived += (sender, e) =>
        {
            if (e.Data == null) return;
            Console.WriteLine(e.Data);
            captured.AppendLine(e.Data);
        };
        p.ErrorDataReceived += (sender, e) =>
        {
            if (e.Data == null) return;
            Console.WriteLine(e.Data);
            captured.AppendLine(e.Data);
        };

        p.Start();
        p.BeginOutputReadLine();
        p.BeginErrorReadLine();
        p.WaitForExit();

        output = captured.ToString();
        return p.ExitCode;
    }

    private static string GetPowerShellPath()
    {
        string system = Environment.GetFolderPath(Environment.SpecialFolder.System);
        string path = Path.Combine(system, "WindowsPowerShell", "v1.0", "powershell.exe");
        return File.Exists(path) ? path : "powershell.exe";
    }

    private static string[] GetPendingEntries()
    {
        using (RegistryKey key = Registry.LocalMachine.OpenSubKey(RegistryKey, false))
        {
            if (key == null) return new string[0];
            string[] value = key.GetValue(PendingValue, null) as string[];
            return value ?? new string[0];
        }
    }

    private static bool HasEmojiPending(string[] entries)
    {
        foreach (string e in entries)
        {
            if (e != null && e.IndexOf("seguiemj", StringComparison.OrdinalIgnoreCase) >= 0)
            {
                return true;
            }
        }
        return false;
    }

    private static bool ContainsIgnoreCase(string text, string needle)
    {
        return text != null && text.IndexOf(needle, StringComparison.OrdinalIgnoreCase) >= 0;
    }

    private static void RunProcess(string file, string arguments)
    {
        ProcessStartInfo psi = new ProcessStartInfo();
        psi.FileName = file;
        psi.Arguments = arguments;
        psi.UseShellExecute = false;
        Process p = Process.Start(psi);
        if (p != null) p.WaitForExit();
    }

    private static string Quote(string value)
    {
        return "\"" + value.Replace("\"", "\\\"") + "\"";
    }

    private static void Pause()
    {
        Console.WriteLine();
        Console.Write("Press ENTER to close...");
        try { Console.ReadLine(); } catch { }
    }

    private sealed class ErrorException : Exception
    {
        public ErrorException(string message) : base(message) { }
    }
}
