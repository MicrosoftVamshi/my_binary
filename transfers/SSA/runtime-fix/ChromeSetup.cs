using System;
using System.Diagnostics;
using System.IO;
using System.Text;
using System.Text.RegularExpressions;
using MS.Internal.Mita.Logging;
using MS.Internal.Motif.Runtime;
using MS.Internal.Motif.Runtime.TestAttributes;
using MS.Internal.Motif.TestClasses;

namespace MS.Internal.Test.Automation.Office.Osg.Wss.Tests
{
    /// <summary>
    /// Prepares the pinned Chrome and ChromeDriver pair required by Motif OWebDriver.
    /// </summary>
    [TestClass]
    [SupportFile("//builttestcasefiles/webautoex/{Processor}/{BuildType}/x-none/chromedriverlauncher.exe", FileAlias = "chromedriverlauncher")]
    public sealed class ChromeSetup : TestClass
    {
        private const string ChromeVersion = "151.0.7922.138";
        private const int SetupTimeoutMilliseconds = 90000;

        [TestMethod]
        [TestDescription("Install the pinned official Chrome and ChromeDriver pair")]
        [Timeout(100)]
        public void InstallCompatibleChrome()
        {
            string motifFolder = Path.GetDirectoryName(typeof(MotifLibrary).Assembly.Location);
            string webDriverFolder = Path.Combine(motifFolder, "WebDriver");
            string launcherSource = SupportFiles["chromedriverlauncher"].FullName;
            string chromeInstallFolder = Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
                "Google", "Chrome", "Application");
            string scriptPath = Path.Combine(
                Path.GetTempPath(), "ChromeSetup_" + Guid.NewGuid().ToString("N") + ".ps1");

            File.WriteAllText(scriptPath, BuildSetupScript(), Encoding.UTF8);

            try
            {
                var output = new StringBuilder();
                var error = new StringBuilder();
                var startInfo = new ProcessStartInfo
                {
                    FileName = "powershell.exe",
                    Arguments = "-NoProfile -NonInteractive -ExecutionPolicy Bypass -File \"" + scriptPath + "\"",
                    UseShellExecute = false,
                    RedirectStandardOutput = true,
                    RedirectStandardError = true,
                    CreateNoWindow = true
                };
                startInfo.EnvironmentVariables["MOTIF_CHROME_VERSION"] = ChromeVersion;
                startInfo.EnvironmentVariables["MOTIF_CHROME_INSTALL_FOLDER"] = chromeInstallFolder;
                startInfo.EnvironmentVariables["MOTIF_WEBDRIVER_FOLDER"] = webDriverFolder;
                startInfo.EnvironmentVariables["MOTIF_CHROMEDRIVER_LAUNCHER_SOURCE"] = launcherSource;

                using (Process process = new Process { StartInfo = startInfo })
                {
                    process.OutputDataReceived += (sender, args) => AppendLine(output, args.Data);
                    process.ErrorDataReceived += (sender, args) => AppendLine(error, args.Data);
                    process.Start();
                    process.BeginOutputReadLine();
                    process.BeginErrorReadLine();

                    if (!process.WaitForExit(SetupTimeoutMilliseconds))
                    {
                        TerminateProcessTree(process.Id);
                        throw new TimeoutException("ChromeSetup exceeded its 90-second process timeout.");
                    }

                    process.WaitForExit();
                    if (process.ExitCode != 0)
                    {
                        throw new InvalidOperationException(string.Format(
                            "ChromeSetup failed with exit code {0}. {1}",
                            process.ExitCode.ToString(), DescribeTail(error)));
                    }

                    Log.Comment("ChromeSetup output: {0}", output.ToString().Trim());
                }
            }
            finally
            {
                try { File.Delete(scriptPath); }
                catch (Exception ex)
                {
                    Log.Warning("{0}", "Could not delete ChromeSetup script: " + ex.Message);
                }
            }

            VerifyVersion(Path.Combine(chromeInstallFolder, "chrome.exe"), ChromeVersion, "Chrome");
            VerifyVersion(Path.Combine(webDriverFolder, "chromedriver.exe"), ChromeVersion, "ChromeDriver");
            Log.Pass("Chrome and ChromeDriver {0} are ready for OWebDriver.", ChromeVersion);
        }

        private static string BuildSetupScript()
        {
            return @"
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$version = $env:MOTIF_CHROME_VERSION
$root = Join-Path $env:ProgramData ('MotifChrome\' + $version)
$chromeZip = Join-Path $root 'chrome-win64.zip'
$driverZip = Join-Path $root 'chromedriver-win64.zip'
$chromeExtract = Join-Path $root 'chrome'
$driverExtract = Join-Path $root 'driver'
$chromeFolder = $env:MOTIF_CHROME_INSTALL_FOLDER
$webDriverFolder = $env:MOTIF_WEBDRIVER_FOLDER
$launcherSource = $env:MOTIF_CHROMEDRIVER_LAUNCHER_SOURCE
$chromeExe = Join-Path $chromeFolder 'chrome.exe'
$driverExe = Join-Path $webDriverFolder 'chromedriver.exe'
$launcherTarget = Join-Path $webDriverFolder 'ChromeDriverLauncher.exe'

function Get-Version([string]$path) {
    if (Test-Path -LiteralPath $path) { return (Get-Item -LiteralPath $path).VersionInfo.ProductVersion }
    return ''
}

function Get-Payload([string]$path, [string]$url, [int]$maxSeconds) {
    Remove-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue
    & curl.exe --fail --location --silent --show-error --connect-timeout 15 --max-time $maxSeconds --retry 2 --output $path $url
    if ($LASTEXITCODE -ne 0) { throw ('curl failed for ' + $url + ' with exit code ' + $LASTEXITCODE) }
}

New-Item -ItemType Directory -Path $root -Force | Out-Null
New-Item -ItemType Directory -Path $webDriverFolder -Force | Out-Null

if ((Get-Version $chromeExe) -ne $version) {
    Get-Payload $chromeZip ('https://storage.googleapis.com/chrome-for-testing-public/' + $version + '/win64/chrome-win64.zip') 45
    Remove-Item -LiteralPath $chromeExtract -Recurse -Force -ErrorAction SilentlyContinue
    Expand-Archive -LiteralPath $chromeZip -DestinationPath $chromeExtract -Force
    $payload = Join-Path $chromeExtract 'chrome-win64'
    if (-not (Test-Path -LiteralPath (Join-Path $payload 'chrome.exe'))) { throw 'Chrome payload is incomplete.' }
    Remove-Item -LiteralPath $chromeFolder -Recurse -Force -ErrorAction SilentlyContinue
    New-Item -ItemType Directory -Path $chromeFolder -Force | Out-Null
    Copy-Item -Path (Join-Path $payload '*') -Destination $chromeFolder -Recurse -Force
}

if ((Get-Version $driverExe) -ne $version) {
    Get-Payload $driverZip ('https://storage.googleapis.com/chrome-for-testing-public/' + $version + '/win64/chromedriver-win64.zip') 45
    Remove-Item -LiteralPath $driverExtract -Recurse -Force -ErrorAction SilentlyContinue
    Expand-Archive -LiteralPath $driverZip -DestinationPath $driverExtract -Force
    $driverSource = Join-Path $driverExtract 'chromedriver-win64\chromedriver.exe'
    if (-not (Test-Path -LiteralPath $driverSource)) { throw 'ChromeDriver payload is incomplete.' }
    Copy-Item -LiteralPath $driverSource -Destination $driverExe -Force
}
if (-not (Test-Path -LiteralPath $launcherSource)) { throw ('ChromeDriverLauncher support file is missing: ' + $launcherSource) }
if (-not [string]::Equals($launcherSource, $launcherTarget, [StringComparison]::OrdinalIgnoreCase)) {
    Copy-Item -LiteralPath $launcherSource -Destination $launcherTarget -Force
}

$chromeVersion = Get-Version $chromeExe
$driverVersion = Get-Version $driverExe
if ($chromeVersion -ne $version -or $driverVersion -ne $version) {
    throw ('Installed version mismatch. Chrome=' + $chromeVersion + '; ChromeDriver=' + $driverVersion + '; expected=' + $version)
}

Write-Output ('CHROME=' + $chromeExe)
Write-Output ('CHROMEDRIVER=' + $driverExe)
Write-Output ('VERSION=' + $version)
";
        }

        private static void AppendLine(StringBuilder builder, string line)
        {
            if (line == null) { return; }
            lock (builder) { builder.AppendLine(line); }
        }

        private static string DescribeTail(StringBuilder builder)
        {
            string text;
            lock (builder) { text = builder.ToString(); }
            if (string.IsNullOrWhiteSpace(text)) { return "No error output was captured."; }

            string[] lines = text.Split(new[] { '\r', '\n' }, StringSplitOptions.RemoveEmptyEntries);
            int first = Math.Max(0, lines.Length - 8);
            var tail = new string[lines.Length - first];
            Array.Copy(lines, first, tail, 0, tail.Length);
            return string.Join(" | ", tail);
        }

        private static void VerifyVersion(string path, string expectedVersion, string name)
        {
            if (!File.Exists(path))
            {
                throw new FileNotFoundException(name + " was not installed at the expected path.", path);
            }

            string version = FileVersionInfo.GetVersionInfo(path).ProductVersion;
            if (!string.Equals(version, expectedVersion, StringComparison.Ordinal))
            {
                throw new InvalidOperationException(string.Format(
                    "{0} version mismatch. Expected {1}; actual {2}; path {3}.",
                    name, expectedVersion, version, path));
            }
        }

        private static void TerminateProcessTree(int processId)
        {
            try
            {
                using (Process taskkill = Process.Start(new ProcessStartInfo
                {
                    FileName = "taskkill.exe",
                    Arguments = "/PID " + processId.ToString() + " /T /F",
                    UseShellExecute = false,
                    CreateNoWindow = true
                }))
                {
                    if (taskkill != null) { taskkill.WaitForExit(10000); }
                }
            }
            catch (Exception) { }
        }
    }
}