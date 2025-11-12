using System;
using System.Drawing;
using System.Runtime.InteropServices;
using System.Windows.Automation;

namespace DesktopCapture
{
    class ElementInfo
    {
        public string Role { get; set; } = "";
        public string Text { get; set; } = "";
        public string DocPath { get; set; } = "";
    }

    class UIAutomationHelper
    {
        [DllImport("user32.dll")]
        private static extern IntPtr WindowFromPoint(POINT point);

        [StructLayout(LayoutKind.Sequential)]
        private struct POINT
        {
            public int x;
            public int y;
        }

        public ElementInfo GetElementInfo(Point clickPoint)
        {
            try
            {
                // Convert Point to POINT
                POINT pt = new POINT { x = clickPoint.X, y = clickPoint.Y };

                // Get element at point using UI Automation
                var element = AutomationElement.FromPoint(new System.Windows.Point(clickPoint.X, clickPoint.Y));

                if (element == null)
                {
                    return new ElementInfo();
                }

                string role = GetControlType(element);
                string text = GetText(element);
                string docPath = GetDocumentPath(element);

                return new ElementInfo
                {
                    Role = role,
                    Text = text,
                    DocPath = docPath
                };
            }
            catch (Exception ex)
            {
                Console.Error.WriteLine($"UI Automation error: {ex.Message}");
                return new ElementInfo();
            }
        }

        private string GetControlType(AutomationElement element)
        {
            try
            {
                var controlType = element.Current.ControlType;
                return controlType.ProgrammaticName.Replace("ControlType.", "").ToLower();
            }
            catch
            {
                return "element";
            }
        }

        private string GetText(AutomationElement element)
        {
            try
            {
                // Try different text patterns
                string[] textToTry = new string[]
                {
                    element.Current.Name,
                    GetValuePattern(element),
                    GetTextPattern(element),
                    element.Current.HelpText
                };

                foreach (var text in textToTry)
                {
                    if (!string.IsNullOrWhiteSpace(text))
                    {
                        return text;
                    }
                }

                return "";
            }
            catch
            {
                return "";
            }
        }

        private string GetValuePattern(AutomationElement element)
        {
            try
            {
                if (element.TryGetCurrentPattern(ValuePattern.Pattern, out object? pattern))
                {
                    var valuePattern = pattern as ValuePattern;
                    return valuePattern?.Current.Value ?? "";
                }
            }
            catch { }
            return "";
        }

        private string GetTextPattern(AutomationElement element)
        {
            try
            {
                if (element.TryGetCurrentPattern(TextPattern.Pattern, out object? pattern))
                {
                    var textPattern = pattern as TextPattern;
                    return textPattern?.DocumentRange.GetText(-1) ?? "";
                }
            }
            catch { }
            return "";
        }

        private string GetDocumentPath(AutomationElement element)
        {
            try
            {
                // Walk up the tree to find window
                var current = element;
                int maxIterations = 20;
                int iterations = 0;

                while (current != null && iterations < maxIterations)
                {
                    iterations++;

                    // Check if this is a document window (PDF viewer, etc.)
                    var className = current.Current.ClassName;
                    var name = current.Current.Name;

                    // Adobe Reader, Acrobat
                    if (className.Contains("Acrobat", StringComparison.OrdinalIgnoreCase) ||
                        name.Contains(".pdf", StringComparison.OrdinalIgnoreCase))
                    {
                        // Try to extract path from window title
                        if (name.Contains(".pdf", StringComparison.OrdinalIgnoreCase))
                        {
                            return ExtractPathFromTitle(name);
                        }
                    }

                    // Try to get document property
                    try
                    {
                        var automationId = current.Current.AutomationId;
                        if (!string.IsNullOrEmpty(automationId) && automationId.Contains(":\\"))
                        {
                            return automationId;
                        }
                    }
                    catch { }

                    // Move to parent
                    try
                    {
                        current = TreeWalker.ControlViewWalker.GetParent(current);
                    }
                    catch
                    {
                        break;
                    }
                }

                return "";
            }
            catch
            {
                return "";
            }
        }

        private string ExtractPathFromTitle(string title)
        {
            try
            {
                // Remove common suffixes like " - Adobe Acrobat Reader DC"
                var cleanTitle = title;
                var separators = new[] { " - ", " – " };

                foreach (var sep in separators)
                {
                    int index = cleanTitle.IndexOf(sep);
                    if (index > 0)
                    {
                        cleanTitle = cleanTitle.Substring(0, index);
                    }
                }

                // If it looks like a full path, return it
                if (cleanTitle.Contains(":\\"))
                {
                    return cleanTitle.Trim();
                }

                // Otherwise, it's just a filename
                return cleanTitle.Trim();
            }
            catch
            {
                return title;
            }
        }
    }
}
