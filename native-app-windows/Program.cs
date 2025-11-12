using System;
using System.Threading;
using System.IO;

namespace DesktopCapture
{
    class Program
    {
        private static Config? config;
        private static DesktopCaptureApp? app;

        [STAThread]
        static void Main(string[] args)
        {
            // Parse command line arguments
            config = Config.Parse(args);

            if (config == null)
            {
                return; // Help was shown or error occurred
            }

            Console.WriteLine("Desktop Capture v0 (Windows) started");
            Console.WriteLine($"Capture rate: {config.Hz} Hz");
            Console.WriteLine($"Output directory: {config.OutputDir}");
            Console.WriteLine();
            Console.WriteLine("Monitoring clicks and capturing screenshots...");
            Console.WriteLine("Press Ctrl+C to stop");
            Console.WriteLine();

            // Set up graceful shutdown
            Console.CancelKeyPress += (sender, e) =>
            {
                e.Cancel = true;
                Console.WriteLine("\nStopping...");
                app?.Stop();
                Environment.Exit(0);
            };

            // Create and run the app
            app = new DesktopCaptureApp(config);
            app.Run();

            // Keep the main thread alive
            Thread.Sleep(Timeout.Infinite);
        }
    }

    class Config
    {
        public double Hz { get; set; } = 1.0;
        public string OutputDir { get; set; } = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.Desktop),
            "captures"
        );

        public static Config? Parse(string[] args)
        {
            var config = new Config();

            for (int i = 0; i < args.Length; i++)
            {
                switch (args[i])
                {
                    case "--hz":
                        if (i + 1 < args.Length && double.TryParse(args[i + 1], out double hz))
                        {
                            config.Hz = hz;
                            i++;
                        }
                        else
                        {
                            Console.Error.WriteLine("Error: --hz requires a numeric value");
                            return null;
                        }
                        break;

                    case "--output":
                        if (i + 1 < args.Length)
                        {
                            config.OutputDir = args[i + 1];
                            i++;
                        }
                        else
                        {
                            Console.Error.WriteLine("Error: --output requires a path");
                            return null;
                        }
                        break;

                    case "--help":
                    case "-h":
                        PrintUsage();
                        return null;

                    default:
                        Console.Error.WriteLine($"Unknown argument: {args[i]}");
                        PrintUsage();
                        return null;
                }
            }

            return config;
        }

        private static void PrintUsage()
        {
            Console.WriteLine(@"Desktop Capture v0 - Windows Screenshot and Click Logger

Usage: DesktopCapture.exe [options]

Options:
  --hz <number>      Screenshot capture rate in Hz (default: 1.0)
  --output <path>    Output directory (default: Desktop\captures)
  --help, -h         Show this help message

Output Structure:
  <output-dir>\YYYY-MM-DD\
    - YYYY-MM-DDTHH-MM-SS.mmmZ.png (screenshots)
    - clicks.ndjson (click logs in JSON format)
    - clicks.csv (click logs in CSV format)

Note: This application requires administrator privileges for global click monitoring.
");
        }
    }

    class DesktopCaptureApp
    {
        private readonly Config config;
        private readonly OutputManager outputManager;
        private readonly ScreenCapture screenCapture;
        private readonly ClickMonitor clickMonitor;
        private readonly NativeMessaging nativeMessaging;
        private readonly UIAutomationHelper uiAutomationHelper;

        private System.Threading.Timer? captureTimer;

        public DesktopCaptureApp(Config config)
        {
            this.config = config;
            this.outputManager = new OutputManager(config.OutputDir);
            this.screenCapture = new ScreenCapture();
            this.uiAutomationHelper = new UIAutomationHelper();
            this.nativeMessaging = new NativeMessaging();
            this.clickMonitor = new ClickMonitor(uiAutomationHelper, nativeMessaging, outputManager);
        }

        public void Run()
        {
            // Create output directory
            outputManager.CreateTodayFolder();

            // Start native messaging listener
            nativeMessaging.Start();

            // Start click monitor
            clickMonitor.Start();

            // Start screenshot capture timer
            int interval = (int)(1000 / config.Hz); // Convert Hz to milliseconds
            captureTimer = new System.Threading.Timer(
                _ => CaptureScreenshot(),
                null,
                0,
                interval
            );
        }

        public void Stop()
        {
            captureTimer?.Dispose();
            clickMonitor.Stop();
            nativeMessaging.Stop();
        }

        private void CaptureScreenshot()
        {
            try
            {
                var screenshots = screenCapture.CaptureAllDisplays();

                foreach (var (displayId, bitmap) in screenshots)
                {
                    outputManager.SaveScreenshot(bitmap, displayId);
                }
            }
            catch (Exception ex)
            {
                Console.Error.WriteLine($"Error capturing screenshot: {ex.Message}");
            }
        }
    }
}
