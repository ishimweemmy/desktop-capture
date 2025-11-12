using System;
using System.Collections.Generic;
using System.IO;
using System.Text;
using System.Threading;
using Newtonsoft.Json;

namespace DesktopCapture
{
    class NativeMessaging
    {
        public Action<Dictionary<string, object>>? OnMessageReceived { get; set; }

        private Thread? inputThread;
        private bool isRunning = false;

        public void Start()
        {
            isRunning = true;

            // Start listening on stdin in background thread
            inputThread = new Thread(ListenForMessages)
            {
                IsBackground = true
            };
            inputThread.Start();
        }

        public void Stop()
        {
            isRunning = false;
        }

        /// <summary>
        /// Listens for messages from Chrome extension on stdin
        /// Native Messaging format: 4-byte length (little-endian) + JSON message
        /// </summary>
        private void ListenForMessages()
        {
            using (var stdin = Console.OpenStandardInput())
            {
                while (isRunning)
                {
                    try
                    {
                        // Read 4-byte message length
                        byte[] lengthBytes = new byte[4];
                        int bytesRead = stdin.Read(lengthBytes, 0, 4);

                        if (bytesRead == 0)
                        {
                            // EOF - Chrome closed connection
                            return;
                        }

                        if (bytesRead != 4)
                        {
                            Console.Error.WriteLine("Invalid length data received");
                            continue;
                        }

                        // Convert to uint (little-endian)
                        uint messageLength = BitConverter.ToUInt32(lengthBytes, 0);

                        if (messageLength == 0 || messageLength > 1024 * 1024)
                        {
                            Console.Error.WriteLine($"Invalid message length: {messageLength}");
                            continue;
                        }

                        // Read message data
                        byte[] messageBytes = new byte[messageLength];
                        int totalRead = 0;

                        while (totalRead < messageLength)
                        {
                            int read = stdin.Read(messageBytes, totalRead, (int)messageLength - totalRead);
                            if (read == 0)
                            {
                                Console.Error.WriteLine("Incomplete message received");
                                break;
                            }
                            totalRead += read;
                        }

                        if (totalRead != messageLength)
                        {
                            continue;
                        }

                        // Parse JSON
                        string messageJson = Encoding.UTF8.GetString(messageBytes);
                        var message = JsonConvert.DeserializeObject<Dictionary<string, object>>(messageJson);

                        if (message != null)
                        {
                            OnMessageReceived?.Invoke(message);
                        }
                    }
                    catch (IOException)
                    {
                        // Stream closed
                        return;
                    }
                    catch (Exception ex)
                    {
                        Console.Error.WriteLine($"Error reading message: {ex.Message}");
                    }
                }
            }
        }

        /// <summary>
        /// Sends a message to Chrome extension via stdout
        /// </summary>
        public void SendMessage(Dictionary<string, object> message)
        {
            try
            {
                string messageJson = JsonConvert.SerializeObject(message);
                byte[] messageBytes = Encoding.UTF8.GetBytes(messageJson);

                uint messageLength = (uint)messageBytes.Length;
                byte[] lengthBytes = BitConverter.GetBytes(messageLength);

                using (var stdout = Console.OpenStandardOutput())
                {
                    // Write length
                    stdout.Write(lengthBytes, 0, lengthBytes.Length);

                    // Write message
                    stdout.Write(messageBytes, 0, messageBytes.Length);

                    stdout.Flush();
                }
            }
            catch (Exception ex)
            {
                Console.Error.WriteLine($"Failed to send message: {ex.Message}");
            }
        }
    }
}
