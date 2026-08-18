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

  window.setBgPreviewMode = function(isPreview) {
    _isPreviewMode = isPreview;
    if (_isPreviewMode && _originalStream) {
      const origTrack = _originalStream.getVideoTracks()[0];
      if (origTrack) _replaceWebRTCVideoTrack(origTrack);
    }
  };

  window.setBgTheme = function(type, value) {
    _bgType = type;
    if (type === 'blur') {
      _blurAmount = value || 15;
    } else if (type === 'image') {
      _bgImage = new Image();
      _bgImage.crossOrigin = 'anonymous';
      _bgImage.src = value;
    }
  };

  // Deep search for video elements including shadow DOMs
  function _getAllVideoElements(root) {
    let videos = [];
    if (!root) return videos;
    if (root.tagName === 'VIDEO') videos.push(root);
    
    if (root.shadowRoot) {
      videos = videos.concat(_getAllVideoElements(root.shadowRoot));
    }
    
    const children = root.children || root.childNodes;
    if (children) {
      for (let i = 0; i < children.length; i++) {
        videos = videos.concat(_getAllVideoElements(children[i]));
      }
    }
    return videos;
  }

  function _findLocalVideoElement() {
    const allVideos = _getAllVideoElements(document.body);
    let validVideos = allVideos.filter(v => (v.srcObject && v.srcObject.getVideoTracks && v.srcObject.getVideoTracks().length > 0) || (v.readyState >= 2 && v.videoWidth > 0 && !v.paused));
    
    if (validVideos.length === 0) {
      if (allVideos.length > 0) return allVideos[allVideos.length - 1];
      return null;
    }

    // Sort by left coordinate descending (furthest right first)
    validVideos.sort((a, b) => b.getBoundingClientRect().left - a.getBoundingClientRect().left);
    
    return validVideos[0];
  }

  function _onResults(results) {
    if (!_running || !_canvas || !_ctx) return;

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
      _ctx.filter = `blur(${_blurAmount}px)` + (_isLowLight ? ' brightness(1.3) contrast(1.1)' : '');
      _ctx.drawImage(results.image, 0, 0, w, h);
      _ctx.filter = 'none';
    }

    if (_offscreen) {
      if (_offscreen.width !== w) _offscreen.width = w;
      if (_offscreen.height !== h) _offscreen.height = h;

      _offCtx.clearRect(0, 0, w, h);
      
      if (_isLowLight) _offCtx.filter = 'brightness(1.3) contrast(1.1)';
      _offCtx.drawImage(results.image, 0, 0, w, h);
      _offCtx.filter = 'none';

      _offCtx.globalCompositeOperation = 'destination-in';
      _offCtx.drawImage(results.segmentationMask, 0, 0, w, h);
      _offCtx.globalCompositeOperation = 'source-over';

      _ctx.drawImage(_offscreen, 0, 0, w, h);
    }
    _ctx.restore();
  }

  async function _processLoop() {
    if (!_running || !_segmentation || !_hiddenVideo) return;
    
    if (_hiddenVideo.readyState >= 2) {
      try {
        const t0 = performance.now();
        await _segmentation.send({ image: _hiddenVideo });
        const t1 = performance.now();
        
        if (t1 - t0 > 35) {
          _animFrameId = setTimeout(() => requestAnimationFrame(_processLoop), 30);
          return;
        }
      } catch (e) {}
    }
    _animFrameId = requestAnimationFrame(_processLoop);
  }

  window.startBgBlur = async function (blurAmount) {
    if (_running) return;
    _blurAmount = blurAmount || 15;
    _bgType = 'blur';

    if (typeof SelfieSegmentation === 'undefined') {
      console.warn('BgBlur: MediaPipe SelfieSegmentation not loaded.');
      if (window._onBgBlurReady) window._onBgBlurReady(false);
      return;
    }

    _uiVideoElement = _findLocalVideoElement();
    if (!_uiVideoElement) {
      console.warn('BgBlur: No local video element found.');
      if (window._onBgBlurReady) window._onBgBlurReady(false);
      return;
    }

    _originalStream = _uiVideoElement.srcObject;

    // Create a hidden video element to read the raw camera stream un-disturbed
    _hiddenVideo = document.createElement('video');
    _hiddenVideo.srcObject = _originalStream;
    _hiddenVideo.autoplay = true;
    _hiddenVideo.muted = true;
    _hiddenVideo.playsInline = true;
    _hiddenVideo.style.display = 'none';
    document.body.appendChild(_hiddenVideo);

    // Create the offscreen canvas to process the video
    _canvas = document.createElement('canvas');
    _ctx = _canvas.getContext('2d');
    
    _offscreen = document.createElement('canvas');
    _offCtx = _offscreen.getContext('2d');

    _segmentation = new SelfieSegmentation({
      locateFile: (file) => `https://cdn.jsdelivr.net/npm/@mediapipe/selfie_segmentation/${file}`,
    });
    _segmentation.setOptions({
      modelSelection: 1,
      selfieMode: false,
    });
    _segmentation.onResults(_onResults);

    _running = true;
    _processLoop();

    if (_enforcerInterval) clearInterval(_enforcerInterval);
    _enforcerInterval = setInterval(() => {
      if (!_running || !_processedStream) return;
      
      if (_isPreviewMode) {
        if (_originalStream) {
          const origTrack = _originalStream.getVideoTracks()[0];
          if (origTrack) _replaceWebRTCVideoTrack(origTrack);
        }
      } else {
        const processedTrack = _processedStream.getVideoTracks()[0];
        if (processedTrack) {
          _replaceWebRTCVideoTrack(processedTrack);
        }
      }

      // Check if Flutter overwrote the UI video element with a new raw camera stream (e.g. after camera toggle)
      if (_uiVideoElement && _uiVideoElement.srcObject && _uiVideoElement.srcObject !== _processedStream) {
        const newRawStream = _uiVideoElement.srcObject;
        if (newRawStream.getVideoTracks().length > 0) {
          _originalStream = newRawStream;
          if (_hiddenVideo) _hiddenVideo.srcObject = _originalStream;
          // Force the UI back to our processed stream
          _uiVideoElement.srcObject = _processedStream;
        }
      }
    }, 1000);

    // Give it a moment to process the first frame, then pipe the blurred canvas stream into the UI!
    setTimeout(() => {
      if (_running && _canvas) {
        _processedStream = _canvas.captureStream(30);
        // Overwrite the Flutter UI's video feed with our blurred canvas stream
        _uiVideoElement.srcObject = _processedStream;
        
        // Also overwrite the WebRTC outgoing stream so remote participants see the blur!
        const newTrack = _processedStream.getVideoTracks()[0];
        _replaceWebRTCVideoTrack(newTrack);

        if (window._onBgBlurReady) window._onBgBlurReady(true);
      }
    }, 800);
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
      _segmentation.close();
      _segmentation = null;
    }
    
    // Restore the original camera stream to the UI
    if (_uiVideoElement && _originalStream) {
      _uiVideoElement.srcObject = _originalStream;
      
      // Restore WebRTC stream to remote participants
      const originalTrack = _originalStream.getVideoTracks()[0];
      if (originalTrack) {
        _replaceWebRTCVideoTrack(originalTrack);
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
  };

  window.isBgBlurAvailable = function () {
    return typeof SelfieSegmentation !== 'undefined';
  };
  window.setBgBlurReadyCallback = function(callback) {
    window._onBgBlurReady = callback;
  };

})();
