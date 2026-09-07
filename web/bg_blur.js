/**
 * Background Blur using MediaPipe Selfie Segmentation
 * 
 * This script:
 * 1. Captures the raw camera video stream
 * 2. Runs each frame through MediaPipe Selfie Segmentation model
 * 3. Draws blurred background + sharp person onto a canvas
 * 4. Exposes the canvas stream for Flutter to use
 *
 * Called from Flutter via dart:js:
 *   - window.startBgBlur(blurAmount)  → starts background blur
 *   - window.stopBgBlur()             → stops and restores original camera
 */

(function () {
  // --- Intercept RTCPeerConnection to apply blur to outgoing WebRTC streams ---
  window._rtcPeerConnections = window._rtcPeerConnections || [];
  const OrigPeerConnection = window.RTCPeerConnection;
  if (!window._rtcPeerConnectionPatched && OrigPeerConnection) {
    window.RTCPeerConnection = function(...args) {
      const pc = new OrigPeerConnection(...args);
      window._rtcPeerConnections.push(pc);
      pc.addEventListener('signalingstatechange', () => {
        if (pc.signalingState === 'closed') {
          window._rtcPeerConnections = window._rtcPeerConnections.filter(p => p !== pc);
        }
      });
      return pc;
    };
    window.RTCPeerConnection.prototype = OrigPeerConnection.prototype;
    window._rtcPeerConnectionPatched = true;
  }

  function _replaceWebRTCVideoTrack(newTrack) {
    if (!newTrack || !window._rtcPeerConnections) return;
    for (const pc of window._rtcPeerConnections) {
      if (pc.signalingState === 'closed') continue;
      const senders = pc.getSenders();
      for (const sender of senders) {
        if (sender.track && sender.track.kind === 'video' && sender.track !== newTrack) {
          sender.replaceTrack(newTrack).catch(e => console.error('BgBlur RTCPeerConnection error:', e));
        }
      }
    }
  }

  let _segmentation = null;
  let _animFrameId = null;
  let _uiVideoElement = null;
  let _hiddenVideo = null;
  let _canvas = null;
  let _ctx = null;
  let _offscreen = null;
  let _offCtx = null;
  let _blurAmount = 15;
  let _running = false;
  let _originalStream = null;
  let _processedStream = null;
  let _bgType = 'blur';
  let _bgImage = null;
  let _enforcerInterval = null;
  let _isPreviewMode = false;
  let _frameCount = 0;
  let _isLowLight = false;
  let _hasSegmentationResults = false;
  let _activeCanvasWrapper = null;
  let _isMirrored = true; // Mirror person preview horizontally (default true to match natural mirror preview)

  // Pre-load background images so they are immediately available without delay
  const _imgCache = {};
  function _preloadImage(path) {
    if (!path) return null;
    const origin = window.location.origin || (window.location.protocol + '//' + window.location.host);
    const full = path.startsWith('http') ? path : (origin + '/' + path.replace(/^\/+/, ''));
    if (_imgCache[full] && _imgCache[full].complete && _imgCache[full].naturalWidth > 0) {
      return _imgCache[full];
    }
    const img = new Image();
    img.crossOrigin = 'anonymous';
    img.onload = () => console.log('[BgBlur] Image cached successfully:', full);
    img.onerror = (e) => console.warn('[BgBlur] Failed to load image:', full, e);
    img.src = full;
    _imgCache[full] = img;
    return img;
  }
  // Immediately start caching default backgrounds
  _preloadImage('backgrounds/clinic_office.jpg');
  _preloadImage('backgrounds/medical_suite.jpg');

  window.setBgPreviewMode = function(isPreview) {
    _isPreviewMode = isPreview;
    if (_isPreviewMode && _originalStream) {
      const origTrack = _originalStream.getVideoTracks()[0];
      if (origTrack) _replaceWebRTCVideoTrack(origTrack);
    }
  };

  window.setBgMirror = function(enable) {
    _isMirrored = !!enable;
    console.log('[BgBlur] Mirror set to:', _isMirrored);
    return _isMirrored;
  };

  window.toggleBgMirror = function() {
    _isMirrored = !_isMirrored;
    console.log('[BgBlur] Mirror toggled to:', _isMirrored);
    return _isMirrored;
  };

  window.isBgMirrored = function() {
    return _isMirrored;
  };

  window.setBgTheme = function(type, value) {
    _bgType = type || 'image';
    if (_bgType === 'blur') {
      _blurAmount = value || 15;
      _bgImage = null;
    } else if (_bgType === 'image') {
      var rawPath = value || 'backgrounds/clinic_office.jpg';
      _bgImage = _preloadImage(rawPath);
    }
  };

  window.getVirtualBgCanvasElement = function() {
    if (!_canvas) {
      _canvas = document.createElement('canvas');
      _canvas.id = 'bg_blur_active_canvas_overlay';
      _canvas.width = 1280;
      _canvas.height = 720;
      _ctx = _canvas.getContext('2d');
    }

    _canvas.style.position = 'absolute';
    _canvas.style.top = '0';
    _canvas.style.left = '0';
    _canvas.style.width = '100%';
    _canvas.style.height = '100%';
    _canvas.style.objectFit = 'cover';
    _canvas.style.pointerEvents = 'none';
    _canvas.style.borderRadius = 'inherit';
    _canvas.style.display = 'block';

    const wrapper = document.createElement('div');
    wrapper.className = 'virtual-bg-live-canvas-host';
    wrapper.style.width = '100%';
    wrapper.style.height = '100%';
    wrapper.style.position = 'relative';
    wrapper.style.overflow = 'hidden';
    wrapper.style.borderRadius = 'inherit';
    wrapper.style.backgroundColor = '#0F172A';

    wrapper.appendChild(_canvas);
    _activeCanvasWrapper = wrapper;
    return wrapper;
  };

  // Deep recursive search for video elements including all shadow DOMs
  function _getAllVideoElements(root) {
    let videos = [];
    if (!root) return videos;
    if (root.tagName === 'VIDEO' && root.id !== 'bg_blur_internal_hidden_video') {
      videos.push(root);
    }
    
    if (root.querySelectorAll) {
      try {
        const found = root.querySelectorAll('video');
        for (let i = 0; i < found.length; i++) {
          if (found[i].id !== 'bg_blur_internal_hidden_video' && videos.indexOf(found[i]) === -1) {
            videos.push(found[i]);
          }
        }
      } catch (_) {}
      try {
        const all = root.querySelectorAll('*');
        for (let j = 0; j < all.length; j++) {
          if (all[j].shadowRoot) {
            const shadowVids = _getAllVideoElements(all[j].shadowRoot);
            for (let k = 0; k < shadowVids.length; k++) {
              if (videos.indexOf(shadowVids[k]) === -1) videos.push(shadowVids[k]);
            }
          }
        }
      } catch (_) {}
    }
    
    if (root.shadowRoot) {
      const shadowVids = _getAllVideoElements(root.shadowRoot);
      for (let k = 0; k < shadowVids.length; k++) {
        if (videos.indexOf(shadowVids[k]) === -1) videos.push(shadowVids[k]);
      }
    }
    return videos;
  }

  function _findLocalVideoElement() {
    const allVideos = _getAllVideoElements(document.body);
    if (!allVideos || allVideos.length === 0) return null;

    // Filter valid videos
    let validVideos = allVideos.filter(v => 
      v && v.id !== 'bg_blur_internal_hidden_video' &&
      ((v.srcObject && v.srcObject.getVideoTracks && v.srcObject.getVideoTracks().length > 0) || (v.readyState >= 1))
    );
    
    // In LiveKit & WebRTC, local video is muted to prevent acoustic feedback loop
    let targetPool = validVideos.length > 0 ? validVideos : allVideos;
    let localVideos = targetPool.filter(v => v.muted || v.volume === 0 || v.hasAttribute('muted'));
    if (localVideos.length > 0) return localVideos[0];
    return targetPool[0];
  }

  function _onResults(results) {
    if (!_running || !_canvas || !_ctx) return;
    _hasSegmentationResults = true;

    const w = results.image.width || 640;
    const h = results.image.height || 480;

    if (_canvas.width !== w) _canvas.width = w;
    if (_canvas.height !== h) _canvas.height = h;

    _frameCount++;
    if (_frameCount % 30 === 0) {
      const tmpCanvas = document.createElement('canvas');
      tmpCanvas.width = 10;
      tmpCanvas.height = 10;
      const tCtx = tmpCanvas.getContext('2d');
      tCtx.drawImage(results.image, 0, 0, 10, 10);
      const data = tCtx.getImageData(0,0,10,10).data;
      let sum = 0;
      for (let i = 0; i < data.length; i += 4) {
        sum += (data[i] + data[i+1] + data[i+2]) / 3;
      }
      const avgBrightness = sum / (data.length / 4);
      _isLowLight = avgBrightness < 70;
    }

    _ctx.save();
    
    if (_bgType === 'image' && _bgImage && _bgImage.complete && _bgImage.naturalWidth > 0) {
      const imgRatio = _bgImage.naturalWidth / _bgImage.naturalHeight;
      const canvasRatio = w / h;
      let drawW = w;
      let drawH = h;
      let drawX = 0;
      let drawY = 0;
      
      if (imgRatio > canvasRatio) {
        drawW = h * imgRatio;
        drawX = (w - drawW) / 2;
      } else {
        drawH = w / imgRatio;
        drawY = (h - drawH) / 2;
      }
      _ctx.drawImage(_bgImage, drawX, drawY, drawW, drawH);
    } else {
      _ctx.save();
      if (_isMirrored) {
        _ctx.translate(w, 0);
        _ctx.scale(-1, 1);
      }
      _ctx.filter = `blur(${_blurAmount}px)` + (_isLowLight ? ' brightness(1.3) contrast(1.1)' : '');
      _ctx.drawImage(results.image, 0, 0, w, h);
      _ctx.filter = 'none';
      _ctx.restore();
    }

    if (_offscreen) {
      if (_offscreen.width !== w) _offscreen.width = w;
      if (_offscreen.height !== h) _offscreen.height = h;

      _offCtx.clearRect(0, 0, w, h);
      
      _offCtx.save();
      if (_isMirrored) {
        _offCtx.translate(w, 0);
        _offCtx.scale(-1, 1);
      }
      if (_isLowLight) _offCtx.filter = 'brightness(1.3) contrast(1.1)';
      _offCtx.drawImage(results.image, 0, 0, w, h);
      _offCtx.filter = 'none';

      _offCtx.globalCompositeOperation = 'destination-in';
      _offCtx.drawImage(results.segmentationMask, 0, 0, w, h);
      _offCtx.restore();

      _offCtx.globalCompositeOperation = 'source-over';
      _ctx.drawImage(_offscreen, 0, 0, w, h);
    }
    _ctx.restore();
  }

  // Fast canvas-based fallback segmentation if MediaPipe CDN fails or is initializing
  function _renderFallbackBlurFrame(video) {
    if (!_canvas || !_ctx || !video || video.readyState < 2) return;
    const w = video.videoWidth || 640;
    const h = video.videoHeight || 480;
    if (_canvas.width !== w) _canvas.width = w;
    if (_canvas.height !== h) _canvas.height = h;

    _ctx.save();
    // 1. Draw background (image or blur)
    if (_bgType === 'image' && _bgImage && _bgImage.complete && _bgImage.naturalWidth > 0) {
      const imgRatio = _bgImage.naturalWidth / _bgImage.naturalHeight;
      const canvasRatio = w / h;
      let drawW = w;
      let drawH = h;
      let drawX = 0;
      let drawY = 0;
      if (imgRatio > canvasRatio) {
        drawW = h * imgRatio;
        drawX = (w - drawW) / 2;
      } else {
        drawH = w / imgRatio;
        drawY = (h - drawH) / 2;
      }
      _ctx.drawImage(_bgImage, drawX, drawY, drawW, drawH);
    } else {
      _ctx.save();
      if (_isMirrored) {
        _ctx.translate(w, 0);
        _ctx.scale(-1, 1);
      }
      _ctx.filter = `blur(${_blurAmount}px)`;
      _ctx.drawImage(video, 0, 0, w, h);
      _ctx.filter = 'none';
      _ctx.restore();
    }

    // 2. Composite sharp center person with soft vignette
    if (_offscreen) {
      if (_offscreen.width !== w) _offscreen.width = w;
      if (_offscreen.height !== h) _offscreen.height = h;
      _offCtx.clearRect(0, 0, w, h);
      
      _offCtx.save();
      if (_isMirrored) {
        _offCtx.translate(w, 0);
        _offCtx.scale(-1, 1);
      }
      _offCtx.drawImage(video, 0, 0, w, h);
      _offCtx.restore();

      _offCtx.globalCompositeOperation = 'destination-in';
      const grad = _offCtx.createRadialGradient(w * 0.5, h * 0.50, w * 0.16, w * 0.5, h * 0.50, w * 0.44);
      grad.addColorStop(0, 'rgba(0,0,0,1)');
      grad.addColorStop(0.72, 'rgba(0,0,0,0.95)');
      grad.addColorStop(1, 'rgba(0,0,0,0)');
      _offCtx.fillStyle = grad;
      _offCtx.fillRect(0, 0, w, h);
      _offCtx.globalCompositeOperation = 'source-over';

      _ctx.drawImage(_offscreen, 0, 0, w, h);
    }
    _ctx.restore();
  }

  async function _processLoop() {
    if (!_running) return;
    
    // Ensure we have active local video
    if (!_uiVideoElement || !_uiVideoElement.isConnected || _uiVideoElement.readyState < 2) {
      const detected = _findLocalVideoElement();
      if (detected) _uiVideoElement = detected;
    }

    const video = _uiVideoElement;
    if (video && video.readyState >= 2) {
      _mountCanvasOverlay(video);

      // Immediately render fallback image/blur so canvas is never transparent or blank
      if (!_hasSegmentationResults) {
        _renderFallbackBlurFrame(video);
      }

      if (_segmentation && typeof _segmentation.send === 'function') {
        try {
          await _segmentation.send({ image: video });
        } catch (e) {
          _renderFallbackBlurFrame(video);
        }
      } else {
        _renderFallbackBlurFrame(video);
      }
    }
    _animFrameId = requestAnimationFrame(_processLoop);
  }

  function _mountCanvasOverlay(uiVideo) {
    if (!_canvas) return;
    if (_activeCanvasWrapper && !_activeCanvasWrapper.contains(_canvas)) {
      _activeCanvasWrapper.appendChild(_canvas);
      return;
    }
    if (!uiVideo) return;
    const parent = uiVideo.parentElement;
    if (!parent) return;

    if (!parent.contains(_canvas) && !_activeCanvasWrapper) {
      parent.style.position = 'relative';
      parent.style.overflow = 'hidden';
      _canvas.id = 'bg_blur_active_canvas_overlay';
      _canvas.style.position = 'absolute';
      _canvas.style.top = '0';
      _canvas.style.left = '0';
      _canvas.style.width = '100%';
      _canvas.style.height = '100%';
      _canvas.style.objectFit = 'cover';
      _canvas.style.zIndex = '10';
      _canvas.style.pointerEvents = 'none';
      _canvas.style.borderRadius = 'inherit';
      parent.appendChild(_canvas);
      console.log("[BgBlur] Canvas overlay mounted directly on video parent.");
    }
  }

  window.startBgBlur = async function (blurAmount) {
    _blurAmount = blurAmount || 15;
    if (!_bgType) _bgType = 'blur';
    if (_running) {
      _hasSegmentationResults = false;
      const vid = _findLocalVideoElement();
      if (vid) {
        _uiVideoElement = vid;
        _renderFallbackBlurFrame(vid);
      }
      return;
    }
    _hasSegmentationResults = false;

    _uiVideoElement = _findLocalVideoElement();
    if (!_uiVideoElement) {
      console.warn('BgBlur: No local video element found on start. Will retry in loop.');
    } else {
      _originalStream = _uiVideoElement.srcObject;
    }

    // Create offscreen canvas
    _canvas = document.createElement('canvas');
    _ctx = _canvas.getContext('2d');
    
    _offscreen = document.createElement('canvas');
    _offCtx = _offscreen.getContext('2d');

    if (_uiVideoElement) {
      _mountCanvasOverlay(_uiVideoElement);
    }

    // Initialize MediaPipe SelfieSegmentation
    if (typeof SelfieSegmentation !== 'undefined') {
      try {
        _segmentation = new SelfieSegmentation({
          locateFile: (file) => `https://cdn.jsdelivr.net/npm/@mediapipe/selfie_segmentation/${file}`,
        });
        _segmentation.setOptions({
          modelSelection: 1,
          selfieMode: false,
        });
        _segmentation.onResults(_onResults);
        console.log("[BgBlur] MediaPipe SelfieSegmentation initialized.");
      } catch (e) {
        console.warn("[BgBlur] MediaPipe init notice, using adaptive canvas fallback:", e);
        _segmentation = null;
      }
    } else {
      console.log("[BgBlur] Using adaptive canvas segmentation fallback.");
    }

    _running = true;
    _processLoop();

    // Check periodically that overlay remains mounted even after Flutter rebuilds
    if (_enforcerInterval) clearInterval(_enforcerInterval);
    _enforcerInterval = setInterval(() => {
      if (!_running) return;
      const currentUiVideo = _findLocalVideoElement();
      if (currentUiVideo) {
        _uiVideoElement = currentUiVideo;
        _mountCanvasOverlay(_uiVideoElement);
      }
      if (_canvas && !_processedStream) {
        try {
          _processedStream = _canvas.captureStream(30);
          const newTrack = _processedStream.getVideoTracks()[0];
          if (newTrack) _replaceWebRTCVideoTrack(newTrack);
        } catch (_) {}
      }
    }, 1000);

    setTimeout(() => {
      if (_running && _canvas) {
        try {
          _processedStream = _canvas.captureStream(30);
          const newTrack = _processedStream.getVideoTracks()[0];
          if (newTrack) _replaceWebRTCVideoTrack(newTrack);
        } catch (_) {}
        if (window._onBgBlurReady) window._onBgBlurReady(true);
      }
    }, 500);
  };

  window.stopBgBlur = function () {
    _running = false;
    if (_animFrameId) {
      cancelAnimationFrame(_animFrameId);
      _animFrameId = null;
    }
    if (_enforcerInterval) {
      clearInterval(_enforcerInterval);
      _enforcerInterval = null;
    }
    if (_segmentation) {
      try { _segmentation.close(); } catch (_) {}
      _segmentation = null;
    }
    
    // Remove canvas overlay
    if (_canvas && _canvas.parentNode) {
      _canvas.parentNode.removeChild(_canvas);
    }

    // Reset video filter
    const currentUiVideo = _findLocalVideoElement();
    if (currentUiVideo) {
      try { currentUiVideo.style.filter = 'none'; } catch (_) {}
    }
    if (_uiVideoElement) {
      try { _uiVideoElement.style.filter = 'none'; } catch (_) {}
      if (_originalStream) {
        const originalTrack = _originalStream.getVideoTracks()[0];
        if (originalTrack) _replaceWebRTCVideoTrack(originalTrack);
      }
    }
    
    if (_hiddenVideo && _hiddenVideo.parentNode) {
      _hiddenVideo.parentNode.removeChild(_hiddenVideo);
    }
    
    _hiddenVideo = null;
    _canvas = null;
    _ctx = null;
    _offscreen = null;
    _offCtx = null;
    _uiVideoElement = null;
    _originalStream = null;
    _processedStream = null;
    console.log("[BgBlur] Background blur deactivated cleanly.");
  };

  window.isBgBlurAvailable = function () {
    return true; // Always available via adaptive Canvas or MediaPipe
  };
  window.setBgBlurReadyCallback = function(callback) {
    window._onBgBlurReady = callback;
  };

})();
