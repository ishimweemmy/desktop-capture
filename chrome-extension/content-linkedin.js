// Content script for LinkedIn post detection and expansion
// Detects clicks on LinkedIn posts, expands "See more", and extracts full text

(function() {
  'use strict';

  console.log('Desktop Capture: LinkedIn content script loaded');

  // LinkedIn post selectors
  const SELECTORS = {
    // Post container (feed post)
    postContainer: [
      '.feed-shared-update-v2',
      'div[data-urn]',
      '.occludable-update',
      'article'
    ],

    // "See more" button
    seeMoreButton: [
      '.feed-shared-inline-show-more-text__see-more-less-toggle',
      'button[aria-label*="more"]',
      '.see-more',
      'button.inline-show-more-text__button'
    ],

    // Post text container
    textContainer: [
      '.feed-shared-update-v2__description',
      '.feed-shared-text',
      '.break-words',
      '.update-components-text'
    ],

    // Post link (for canonical URL)
    postLink: [
      'a[href*="/feed/update/"]',
      'a[data-control-name="like_toggle"]',
      '.update-components-header__text-view'
    ]
  };

  // Find the closest matching element using multiple selectors
  function findClosest(element, selectors) {
    for (const selector of selectors) {
      const closest = element.closest(selector);
      if (closest) return closest;
    }
    return null;
  }

  // Find the first matching element within a container
  function findWithin(container, selectors) {
    for (const selector of selectors) {
      const element = container.querySelector(selector);
      if (element) return element;
    }
    return null;
  }

  // Find all matching elements within a container
  function findAllWithin(container, selectors) {
    for (const selector of selectors) {
      const elements = container.querySelectorAll(selector);
      if (elements.length > 0) return Array.from(elements);
    }
    return [];
  }

  // Extract post URL
  function getPostURL(postContainer) {
    // Try to find post link
    const link = findWithin(postContainer, SELECTORS.postLink);
    if (link && link.href) {
      return link.href;
    }

    // Fallback to current page URL
    return window.location.href;
  }

  // Expand "See more" button if present
  async function expandPost(postContainer) {
    const seeMoreButton = findWithin(postContainer, SELECTORS.seeMoreButton);

    if (seeMoreButton && seeMoreButton.offsetParent !== null) {
      // Button is visible, click it
      console.log('Desktop Capture: Expanding LinkedIn post');
      seeMoreButton.click();

      // Wait for expansion animation
      await new Promise(resolve => setTimeout(resolve, 300));
      return true;
    }

    return false;
  }

  // Extract full text from post
  function extractPostText(postContainer) {
    const textElements = findAllWithin(postContainer, SELECTORS.textContainer);

    if (textElements.length === 0) {
      return '';
    }

    // Get text from all text containers
    const texts = textElements.map(el => {
      // Get visible text, excluding hidden elements
      return el.innerText || el.textContent || '';
    });

    return texts.join('\n\n').trim();
  }

  // Handle click on LinkedIn post
  async function handleClick(event) {
    const clickX = event.clientX + window.scrollX;
    const clickY = event.clientY + window.scrollY;
    const globalX = event.screenX;
    const globalY = event.screenY;

    // Find the post container
    const postContainer = findClosest(event.target, SELECTORS.postContainer);

    if (!postContainer) {
      console.log('Desktop Capture: Click not on LinkedIn post');
      return;
    }

    console.log('Desktop Capture: Click detected on LinkedIn post');

    // Expand post if needed
    await expandPost(postContainer);

    // Extract text and URL
    const text = extractPostText(postContainer);
    const url = getPostURL(postContainer);

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
      platform: 'linkedin',
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

  console.log('Desktop Capture: LinkedIn click listener installed');

})();
