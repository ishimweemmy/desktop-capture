// Background service worker for Desktop Capture extension
// Handles Native Messaging communication with the macOS app

const NATIVE_HOST_NAME = "com.desktopcapture.host";

let nativePort = null;
let isConnecting = false;

// Connect to native messaging host
function connectToNativeHost() {
  if (isConnecting || (nativePort && nativePort.name)) {
    return; // Already connected or connecting
  }

  isConnecting = true;

  try {
    nativePort = chrome.runtime.connectNative(NATIVE_HOST_NAME);

    nativePort.onMessage.addListener((message) => {
      console.log("Received message from native app:", message);
    });

    nativePort.onDisconnect.addListener(() => {
      console.log("Disconnected from native app");
      if (chrome.runtime.lastError) {
        console.error("Native app error:", chrome.runtime.lastError.message);
      }
      nativePort = null;
      isConnecting = false;

      // Attempt to reconnect after 5 seconds
      setTimeout(connectToNativeHost, 5000);
    });

    console.log("Connected to native app");
    isConnecting = false;
  } catch (error) {
    console.error("Failed to connect to native app:", error);
    nativePort = null;
    isConnecting = false;

    // Retry connection after 5 seconds
    setTimeout(connectToNativeHost, 5000);
  }
}

// Send click data to native app
function sendClickToNative(clickData) {
  if (!nativePort) {
    console.log("Not connected to native app, attempting to connect...");
    connectToNativeHost();

    // Queue message to send after connection
    setTimeout(() => {
      if (nativePort) {
        nativePort.postMessage(clickData);
      }
    }, 100);
    return;
  }

  try {
    nativePort.postMessage(clickData);
    console.log("Sent click data to native app:", clickData);
  } catch (error) {
    console.error("Failed to send message to native app:", error);
    nativePort = null;
    connectToNativeHost();
  }
}

// Listen for messages from content scripts
chrome.runtime.onMessage.addListener((message, sender, sendResponse) => {
  if (message.type === "click_data") {
    // Add tab info
    message.tabId = sender.tab?.id;
    message.url = sender.tab?.url || message.url;

    // Send to native app
    sendClickToNative(message);
    sendResponse({ success: true });
  }
  return true;
});

// Connect on startup
connectToNativeHost();

// Reconnect when browser starts up
chrome.runtime.onStartup.addListener(() => {
  console.log("Browser startup, connecting to native app...");
  connectToNativeHost();
});

// Handle extension installation
chrome.runtime.onInstalled.addListener(() => {
  console.log("Desktop Capture Helper extension installed");
  connectToNativeHost();
});
