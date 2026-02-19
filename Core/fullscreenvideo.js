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

    function postVideo(video) {
        const src = getVideoSrc(video);
        if (!isAllowedUrl(src)) {
            return;
        }

        const now = Date.now();
        if (src === lastSentSrc && (now - lastSentAt) < THROTTLE_MS) {
            return;
        }
        lastSentSrc = src;
        lastSentAt = now;

        const payload = {
            action: 'videoDetected',
            src,
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
