//
//  fullscreenvideo.js
//  DuckDuckGo + Sinker
//
//  Fullscreen polyfill + video source detection bridge.
//

(function () {
    // Keep existing fullscreen polyfill behavior.
    const canEnterFullscreen = HTMLVideoElement.prototype.webkitEnterFullscreen !== undefined;
    const browserHasExistingFullScreenSupport = document.fullscreenEnabled || document.webkitFullscreenEnabled;
    const isMobile = /mobile/i.test(navigator.userAgent);

    if (!browserHasExistingFullScreenSupport && canEnterFullscreen && !isMobile) {
        Object.defineProperty(document, 'fullscreenEnabled', {
            value: true
        });

        HTMLElement.prototype.requestFullscreen = function () {
            const video = this.querySelector('video');

            if (video) {
                video.webkitEnterFullscreen();
                return true;
            }

            return false;
        };
    }
})();

(function () {
    let lastSentSrc = null;
    let lastSentAt = 0;
    const THROTTLE_MS = 1200;
    const RECENT_VIDEO_URL_LIMIT = 40;
    const recentVideoUrls = [];

    function isAllowedUrl(url) {
        return url && (url.startsWith('http://') || url.startsWith('https://') || url.startsWith('blob:'));
    }

    function getVideoSrc(video) {
        let src = video.currentSrc || video.src;

        if (!src || src.startsWith('blob:')) {
            const sources = video.getElementsByTagName('source');
            for (let i = 0; i < sources.length; i += 1) {
                if (sources[i].src) {
                    src = sources[i].src;
                    break;
                }
            }
        }

        return src;
    }

    function looksLikeDirectVideoUrl(url) {
        if (!url || !url.startsWith('http')) {
            return false;
        }

        const lower = url.toLowerCase();
        return lower.includes('.m3u8') ||
               lower.includes('.mp4') ||
               lower.includes('.m4v') ||
               lower.includes('mime=video') ||
               lower.includes('video/mp4') ||
               lower.includes('application/vnd.apple.mpegurl');
    }

    function rememberVideoUrl(url) {
        if (!looksLikeDirectVideoUrl(url)) {
            return;
        }

        const index = recentVideoUrls.indexOf(url);
        if (index >= 0) {
            recentVideoUrls.splice(index, 1);
        }

        recentVideoUrls.push(url);
        if (recentVideoUrls.length > RECENT_VIDEO_URL_LIMIT) {
            recentVideoUrls.shift();
        }
    }

    function installNetworkHooks() {
        if (window.__sinkerNetworkHooked) {
            return;
        }
        window.__sinkerNetworkHooked = true;

        if (typeof window.fetch === 'function') {
            const originalFetch = window.fetch.bind(window);
            window.fetch = function () {
                try {
                    const request = arguments[0];
                    const candidate = typeof request === 'string' ? request : (request && request.url);
                    rememberVideoUrl(candidate);
                } catch (_) {
                    // no-op
                }
                return originalFetch.apply(this, arguments);
            };
        }

        if (window.XMLHttpRequest && window.XMLHttpRequest.prototype) {
            const originalOpen = window.XMLHttpRequest.prototype.open;
            window.XMLHttpRequest.prototype.open = function (method, url) {
                try {
                    rememberVideoUrl(url);
                } catch (_) {
                    // no-op
                }
                return originalOpen.apply(this, arguments);
            };
        }
    }

    function resolveBlobSource(video) {
        // 1) Try source tags first.
        const sources = video.getElementsByTagName('source');
        for (let i = 0; i < sources.length; i += 1) {
            const candidate = sources[i].src;
            if (looksLikeDirectVideoUrl(candidate)) {
                return candidate;
            }
        }

        // 2) Heuristic: recent network resources from Performance API.
        if (window.performance && typeof window.performance.getEntriesByType === 'function') {
            const resources = window.performance.getEntriesByType('resource');
            const maxScan = Math.min(resources.length, 250);
            for (let i = resources.length - 1; i >= resources.length - maxScan; i -= 1) {
                const entry = resources[i];
                if (!entry || !entry.name) {
                    continue;
                }
                if (looksLikeDirectVideoUrl(entry.name)) {
                    rememberVideoUrl(entry.name);
                    return entry.name;
                }
            }
        }

        // 3) Heuristic: recent URLs captured from fetch/XHR interception.
        if (recentVideoUrls.length > 0) {
            return recentVideoUrls[recentVideoUrls.length - 1];
        }

        return null;
    }

    function postVideo(video) {
        const src = getVideoSrc(video);
        if (!isAllowedUrl(src)) {
            return;
        }

        const resolvedSrc = src.startsWith('blob:') ? resolveBlobSource(video) : null;
        const dedupeKey = resolvedSrc || src;

        const now = Date.now();
        if (dedupeKey === lastSentSrc && (now - lastSentAt) < THROTTLE_MS) {
            return;
        }
        lastSentSrc = dedupeKey;
        lastSentAt = now;

        const payload = {
            action: 'videoDetected',
            src,
            resolvedSrc: resolvedSrc || undefined,
            title: document.title || 'Unknown Video',
            referrer: window.location.href
        };

        if (window.webkit &&
            window.webkit.messageHandlers &&
            window.webkit.messageHandlers.videoPlayHandler) {
            window.webkit.messageHandlers.videoPlayHandler.postMessage(payload);
        }
    }

    function hookVideo(video) {
        if (!video || video.getAttribute('data-sinker-hooked')) {
            return;
        }

        video.setAttribute('data-sinker-hooked', 'true');
        video.addEventListener('webkitbeginfullscreen', function (event) {
            postVideo(event.target);
        });
    }

    function scanDocument(doc) {
        const videos = doc.getElementsByTagName('video');
        for (let i = 0; i < videos.length; i += 1) {
            hookVideo(videos[i]);
        }
    }

    function scanAllFrames() {
        scanDocument(document);

        const iframes = document.getElementsByTagName('iframe');
        for (let i = 0; i < iframes.length; i += 1) {
            try {
                if (iframes[i].contentDocument) {
                    scanDocument(iframes[i].contentDocument);
                }
            } catch (_) {
                // Cross-origin iframe access denied.
            }
        }
    }

    function startObserver() {
        const observer = new MutationObserver(function (mutations) {
            mutations.forEach(function (mutation) {
                if (!mutation.addedNodes) {
                    return;
                }
                mutation.addedNodes.forEach(function (node) {
                    if (node.nodeName === 'VIDEO') {
                        hookVideo(node);
                    } else if (node.getElementsByTagName) {
                        const embedded = node.getElementsByTagName('video');
                        for (let i = 0; i < embedded.length; i += 1) {
                            hookVideo(embedded[i]);
                        }
                    }
                });
            });
        });

        if (document.body) {
            observer.observe(document.body, { childList: true, subtree: true });
        }
    }

    installNetworkHooks();

    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', function () {
            scanAllFrames();
            startObserver();
        });
    } else {
        scanAllFrames();
        startObserver();
    }
})();
