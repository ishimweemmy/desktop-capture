using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Imaging;
using System.Globalization;
using System.IO;
using System.Text;
using Newtonsoft.Json;

namespace DesktopCapture
{
    class OutputManager
    {
        private readonly string baseDir;
        private string? currentDateFolder;

        private StreamWriter? ndjsonWriter;
        private StreamWriter? csvWriter;
        private bool csvHeaderWritten = false;

        public OutputManager(string baseDir)
        {
            this.baseDir = baseDir;
        }

        /// <summary>
        /// Creates today's output folder (YYYY-MM-DD in UTC)
        /// </summary>
        public void CreateTodayFolder()
        {
            string today = GetTodayFolderName();
            string folderPath = Path.Combine(baseDir, today);

            currentDateFolder = folderPath;

            // Create directory if it doesn't exist
            Directory.CreateDirectory(folderPath);

            // Open log files
            OpenLogFiles();
        }

        /// <summary>
        /// Gets today's folder name in YYYY-MM-DD format (UTC)
        /// </summary>
        private string GetTodayFolderName()
        {
            return DateTime.UtcNow.ToString("yyyy-MM-dd");
        }

        /// <summary>
        /// Opens log files for writing
        /// </summary>
        private void OpenLogFiles()
        {
            if (currentDateFolder == null)
                return;

            string ndjsonPath = Path.Combine(currentDateFolder, "clicks.ndjson");
            string csvPath = Path.Combine(currentDateFolder, "clicks.csv");

            // Check if CSV file already exists (header already written)
            csvHeaderWritten = File.Exists(csvPath);

            // Open file streams for appending
            ndjsonWriter = new StreamWriter(ndjsonPath, append: true, Encoding.UTF8);
            csvWriter = new StreamWriter(csvPath, append: true, Encoding.UTF8);

            // Set auto-flush for immediate writes
            ndjsonWriter.AutoFlush = true;
            csvWriter.AutoFlush = true;

            // Write CSV header if needed
            if (!csvHeaderWritten)
            {
                csvWriter.WriteLine("ts,x,y,app,window_title,role,text,browser_url,doc_path,display_id,source");
                csvHeaderWritten = true;
            }
        }

        /// <summary>
        /// Closes log files
        /// </summary>
        private void CloseLogFiles()
        {
            ndjsonWriter?.Close();
            csvWriter?.Close();
            ndjsonWriter = null;
            csvWriter = null;
        }

        /// <summary>
        /// Saves a screenshot with UTC timestamp filename
        /// </summary>
        public void SaveScreenshot(Bitmap bitmap, int displayId)
        {
            try
            {
                // Check if we need to create a new folder (date changed)
                string todayFolder = GetTodayFolderName();
                string? currentFolder = currentDateFolder != null ? Path.GetFileName(currentDateFolder) : null;

                if (todayFolder != currentFolder)
                {
                    CloseLogFiles();
                    CreateTodayFolder();
                }

                if (currentDateFolder == null)
                    return;

                // Generate filename: YYYY-MM-DDTHH-MM-SS.mmmZ.png
                DateTime timestamp = DateTime.UtcNow;
                string filename = GetScreenshotFilename(timestamp, displayId);
                string filePath = Path.Combine(currentDateFolder, filename);

                // Save as PNG
                bitmap.Save(filePath, ImageFormat.Png);
            }
            catch (Exception ex)
            {
                Console.Error.WriteLine($"Error saving screenshot: {ex.Message}");
            }
        }

        /// <summary>
        /// Generates screenshot filename with ISO-8601 format
        /// </summary>
        private string GetScreenshotFilename(DateTime date, int displayId)
        {
            // Format: YYYY-MM-DDTHH-MM-SS.mmmZ.png
            // ISO8601 gives us: 2025-11-11T14:30:15.123Z
            // We need to replace colons with dashes for filesystem compatibility
            string isoString = date.ToString("yyyy-MM-ddTHH:mm:ss.fffZ", CultureInfo.InvariantCulture);
            string formatted = isoString.Replace(":", "-");

            // Add display ID suffix if not primary display
            string displaySuffix = displayId == 1 ? "" : $"-display{displayId}";

            return $"{formatted}{displaySuffix}.png";
        }

        /// <summary>
        /// Logs a click event to both NDJSON and CSV files
        /// </summary>
        public void LogClick(ClickEvent clickEvent)
        {
            try
            {
                // Check if we need to create a new folder
                string todayFolder = GetTodayFolderName();
                string? currentFolder = currentDateFolder != null ? Path.GetFileName(currentDateFolder) : null;

                if (todayFolder != currentFolder)
                {
                    CloseLogFiles();
                    CreateTodayFolder();
                }

                // Write to NDJSON
                if (ndjsonWriter != null)
                {
                    string ndjson = ToNDJSON(clickEvent);
                    ndjsonWriter.WriteLine(ndjson);
                }

                // Write to CSV
                if (csvWriter != null)
                {
                    string csv = ToCSVRow(clickEvent);
                    csvWriter.WriteLine(csv);
                }
            }
            catch (Exception ex)
            {
                Console.Error.WriteLine($"Error logging click: {ex.Message}");
            }
        }

        /// <summary>
        /// Converts click event to NDJSON format
        /// </summary>
        private string ToNDJSON(ClickEvent clickEvent)
        {
            var dict = new Dictionary<string, object>
            {
                { "ts", clickEvent.Timestamp.ToString("yyyy-MM-ddTHH:mm:ss.fffZ", CultureInfo.InvariantCulture) },
                { "x", clickEvent.X },
                { "y", clickEvent.Y },
                { "app", clickEvent.App },
                { "window_title", clickEvent.WindowTitle },
                { "role", clickEvent.Role },
                { "text", clickEvent.Text },
                { "browser_url", clickEvent.BrowserUrl },
                { "doc_path", clickEvent.DocPath },
                { "display_id", clickEvent.DisplayId },
                { "source", clickEvent.Source }
            };

            return JsonConvert.SerializeObject(dict);
        }

        /// <summary>
        /// Converts click event to CSV row
        /// </summary>
        private string ToCSVRow(ClickEvent clickEvent)
        {
            string Escape(string str)
            {
                if (str.Contains(",") || str.Contains("\"") || str.Contains("\n") || str.Contains("\r"))
                {
                    return "\"" + str.Replace("\"", "\"\"") + "\"";
                }
                return str;
            }

            return string.Join(",", new[]
            {
                clickEvent.Timestamp.ToString("yyyy-MM-ddTHH:mm:ss.fffZ", CultureInfo.InvariantCulture),
                clickEvent.X.ToString(),
                clickEvent.Y.ToString(),
                Escape(clickEvent.App),
                Escape(clickEvent.WindowTitle),
                Escape(clickEvent.Role),
                Escape(clickEvent.Text),
                Escape(clickEvent.BrowserUrl),
                Escape(clickEvent.DocPath),
                clickEvent.DisplayId.ToString(),
                clickEvent.Source
            });
        }
    }
}
