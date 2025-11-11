// Content script for X/Twitter post detection and expansion
// Detects clicks on tweets, expands "Show more", and extracts full text

(function() {
  'use strict';

  console.log('Desktop Capture: X/Twitter content script loaded');

  // X/Twitter post selectors
  const SELECTORS = {
    // Tweet container
    tweetContainer: [
      'article[data-testid="tweet"]',
      'div[data-testid="tweet"]',
      'article',
      '[data-testid="cellInnerDiv"]'
    ],

    // "Show more" button
    showMoreButton: [
      'div[role="button"][aria-label*="more"]',
      'span:has-text("Show more")',
      '[data-testid="tweet-text-show-more-link"]'
    ],

    // Tweet text container
    textContainer: [
      'div[data-testid="tweetText"]',
      'div[lang]',
      '.css-1dbjc4n.r-1udh08x'
    ],

    // Tweet link (for canonical URL)
    tweetLink: [
      'a[href*="/status/"]',
      'time',
      'article a[role="link"]'
    ]
  };

  // Find the closest matching element using multiple selectors
  function findClosest(element, selectors) {
    for (const selector of selectors) {
      // Handle special :has-text() pseudo-selector
      if (selector.includes(':has-text(')) {
        continue; // Skip for closest, use for querySelector
      }

      const closest = element.closest(selector);
      if (closest) return closest;
    }
    return null;
  }

  // Find the first matching element within a container
  function findWithin(container, selectors) {
    for (const selector of selectors) {
      // Handle special :has-text() pseudo-selector
      if (selector.includes(':has-text(')) {
        const text = selector.match(/\("([^"]+)"\)/)?.[1];
        if (text) {
          const elements = container.querySelectorAll('*');
          for (const el of elements) {
            if (el.textContent.includes(text)) {
              return el;
            }
          }
        }
        continue;
      }

      const element = container.querySelector(selector);
      if (element) return element;
    }
    return null;
  }

  // Find all matching elements within a container
  function findAllWithin(container, selectors) {
    for (const selector of selectors) {
      if (selector.includes(':has-text(')) {
        continue;
      }

      const elements = container.querySelectorAll(selector);
      if (elements.length > 0) return Array.from(elements);
    }
    return [];
  }

  // Extract tweet URL
  function getTweetURL(tweetContainer) {
    // Find link to tweet status
    const timeElement = tweetContainer.querySelector('time');
    if (timeElement) {
      const link = timeElement.closest('a');
      if (link && link.href) {
        return link.href;
      }
    }

    // Try to find any status link
    const links = tweetContainer.querySelectorAll('a[href*="/status/"]');
    for (const link of links) {
      if (link.href.includes('/status/')) {
        return link.href;
      }
    }

    // Fallback to current page URL
    return window.location.href;
  }

  // Expand "Show more" button if present
  async function expandTweet(tweetContainer) {
    // Look for "Show more" text
    const allDivs = tweetContainer.querySelectorAll('div[role="button"], span');
    let showMoreButton = null;

    for (const div of allDivs) {
      const text = div.textContent || '';
      if (text.includes('Show more') || text.includes('Read more')) {
        showMoreButton = div;
        break;
      }
    }

    if (showMoreButton && showMoreButton.offsetParent !== null) {
      // Button is visible, click it
      console.log('Desktop Capture: Expanding tweet');
      showMoreButton.click();

      // Wait for expansion animation
      await new Promise(resolve => setTimeout(resolve, 300));
      return true;
    }

    return false;
  }

  // Extract full text from tweet
  function extractTweetText(tweetContainer) {
    const textElements = findAllWithin(tweetContainer, SELECTORS.textContainer);

    if (textElements.length === 0) {
      return '';
    }

    // Get text from all text containers
    const texts = textElements.map(el => {
      return el.innerText || el.textContent || '';
    });

    // Deduplicate (Twitter sometimes has multiple copies)
    const uniqueTexts = [...new Set(texts)];

    return uniqueTexts.join('\n\n').trim();
  }

  // Handle click on tweet
  async function handleClick(event) {
    const clickX = event.clientX + window.scrollX;
    const clickY = event.clientY + window.scrollY;
    const globalX = event.screenX;
    const globalY = event.screenY;

    // Find the tweet container
    const tweetContainer = findClosest(event.target, SELECTORS.tweetContainer);

    if (!tweetContainer) {
      console.log('Desktop Capture: Click not on tweet');
      return;
    }

    console.log('Desktop Capture: Click detected on tweet');

    // Expand tweet if needed
    await expandTweet(tweetContainer);

    // Extract text and URL
    const text = extractTweetText(tweetContainer);
    const url = getTweetURL(tweetContainer);

    // Get element role
    const role = event.target.tagName.toLowerCase();

    // Send to background script
    const clickData = {
      type: 'click_data',
      x: globalX,
      y: globalY,
      text: text,
      url: url,
      role: role,
      platform: 'twitter',
      timestamp: new Date().toISOString()
    };

    console.log('Desktop Capture: Sending click data:', clickData);

    chrome.runtime.sendMessage(clickData, (response) => {
      if (chrome.runtime.lastError) {
        console.error('Desktop Capture: Error sending message:', chrome.runtime.lastError);
      } else {
        console.log('Desktop Capture: Click data sent successfully');
      }
    });
  }

  // Listen for clicks on the page
  document.addEventListener('click', handleClick, true);

  console.log('Desktop Capture: X/Twitter click listener installed');

})();
