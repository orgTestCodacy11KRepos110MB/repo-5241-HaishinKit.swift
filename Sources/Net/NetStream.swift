import AVFoundation
import CoreImage

/// The `NetStream` class is the foundation of a RTMPStream, HTTPStream.
open class NetStream: NSObject {
    /// The lockQueue.
    public let lockQueue: DispatchQueue = {
        let queue = DispatchQueue(label: "com.haishinkit.HaishinKit.NetStream.lock")
        queue.setSpecific(key: queueKey, value: queueValue)
        return queue
    }()

    private static let queueKey = DispatchSpecificKey<UnsafeMutableRawPointer>()
    private static let queueValue = UnsafeMutableRawPointer.allocate(byteCount: 1, alignment: 1)

    /// The mixer object.
    public private(set) var mixer = IOMixer()

    /// Specifies the metadata for the stream.
    public var metadata: [String: Any?] = [:]

    /// Specifies the context object.
    public var context: CIContext {
        get {
            mixer.videoIO.context
        }
        set {
            mixer.videoIO.context = newValue
        }
    }

    #if os(iOS) || os(macOS)
    /// Specifiet the device torch indicating wheter the turn on(TRUE) or not(FALSE).
    public var torch: Bool {
        get {
            var torch: Bool = false
            lockQueue.sync {
                torch = self.mixer.videoIO.torch
            }
            return torch
        }
        set {
            lockQueue.async {
                self.mixer.videoIO.torch = newValue
            }
        }
    }

    /// Specifies the frame rate of a device capture.
    public var frameRate: Float64 {
        get {
            var frameRate: Float64 = IOMixer.defaultFrameRate
            lockQueue.sync {
                frameRate = self.mixer.videoIO.frameRate
            }
            return frameRate
        }
        set {
            lockQueue.async {
                self.mixer.videoIO.frameRate = newValue
            }
        }
    }

    /// Specifies the sessionPreset for the AVCaptureSession.
    public var sessionPreset: AVCaptureSession.Preset {
        get {
            var sessionPreset: AVCaptureSession.Preset = .default
            lockQueue.sync {
                sessionPreset = self.mixer.sessionPreset
            }
            return sessionPreset
        }
        set {
            lockQueue.async {
                self.mixer.sessionPreset = newValue
            }
        }
    }

    /// Specifies the video orientation for stream.
    public var videoOrientation: AVCaptureVideoOrientation {
        get {
            mixer.videoIO.videoOrientation
        }
        set {
            mixer.videoIO.videoOrientation = newValue
        }
    }

    /// Specifies the multi camera capture properties.
    public var multiCamCaptureSettings: MultiCamCaptureSetting {
        get {
            mixer.videoIO.multiCamCaptureSettings
        }
        set {
            mixer.videoIO.multiCamCaptureSettings = newValue
        }
    }
    #endif

    /// Specifies the hasAudio indicies whether no signal audio or not.
    public var hasAudio: Bool {
        get {
            !mixer.audioIO.muted
        }
        set {
            mixer.audioIO.muted = !newValue
        }
    }

    /// Specifies the hasVideo indicies whether freeze video signal or not.
    public var hasVideo: Bool {
        get {
            !mixer.videoIO.muted
        }
        set {
            mixer.videoIO.muted = !newValue
        }
    }

    /// Specifies the audio compression properties.
    public var audioSettings: Setting<AudioCodec, AudioCodec.Option> {
        get {
            mixer.audioIO.codec.settings
        }
        set {
            mixer.audioIO.codec.settings = newValue
        }
    }

    /// Specifies the video compression properties.
    public var videoSettings: Setting<VideoCodec, VideoCodec.Option> {
        get {
            mixer.videoIO.codec.settings
        }
        set {
            mixer.videoIO.codec.settings = newValue
        }
    }

    /// Specifies the recorder properties.
    public var recorderSettings: [AVMediaType: [String: Any]] {
        get {
            mixer.recorder.outputSettings
        }
        set {
            mixer.recorder.outputSettings = newValue
        }
    }

    deinit {
        metadata.removeAll()
    }

    #if os(iOS) || os(macOS)
    /// Attaches the camera object.
    /// - Warning: This method can't use appendSampleBuffer at the same time.
    open func attachVideo(_ camera: IOVideoCaptureUnit?, onError: ((_ error: Error) -> Void)? = nil) {
        lockQueue.async {
            do {
                try self.mixer.videoIO.attachVideo(camera)
            } catch {
                onError?(error)
            }
        }
    }

    /// Attaches the video capture object for picture in picture.
    /// - Warning: This method can't use appendSampleBuffer at the same time.
    @available(iOS 13.0, *)
    open func attachMultiCamera(_ camera: IOVideoCaptureUnit?, onError: ((_ error: Error) -> Void)? = nil) {
        lockQueue.async {
            do {
                try self.mixer.videoIO.attachMultiCamera(camera)
            } catch {
                onError?(error)
            }
        }
    }

    /// Attaches the audio capture object.
    /// - Warning: This method can't use appendSampleBuffer at the same time.
    open func attachAudio(_ audio: IOAudioCaptureUnit?, automaticallyConfiguresApplicationAudioSession: Bool = false, onError: ((_ error: Error) -> Void)? = nil) {
        lockQueue.async {
            do {
                try self.mixer.audioIO.attachAudio(audio, automaticallyConfiguresApplicationAudioSession: automaticallyConfiguresApplicationAudioSession)
            } catch {
                onError?(error)
            }
        }
    }
    #endif

    open func attachScreen(_ screen: CaptureSessionConvertible?, useScreenSize: Bool = true) {
        lockQueue.async {
            self.mixer.videoIO.attachScreen(screen, useScreenSize: useScreenSize)
        }
    }

    /// Append a CMSampleBuffer?.
    /// - Warning: This method can't use attachCamera or attachAudio method at the same time.
    open func appendSampleBuffer(_ sampleBuffer: CMSampleBuffer, withType: AVMediaType, options: [NSObject: AnyObject]? = nil) {
        switch withType {
        case .audio:
            mixer.audioIO.lockQueue.async {
                self.mixer.audioIO.appendSampleBuffer(sampleBuffer)
            }
        case .video:
            mixer.videoIO.lockQueue.async {
                self.mixer.videoIO.appendSampleBuffer(sampleBuffer)
            }
        default:
            break
        }
    }

    /// Register a video effect.
    public func registerVideoEffect(_ effect: VideoEffect) -> Bool {
        mixer.videoIO.lockQueue.sync {
            self.mixer.videoIO.registerEffect(effect)
        }
    }

    /// Unregister a video effect.
    public func unregisterVideoEffect(_ effect: VideoEffect) -> Bool {
        mixer.videoIO.lockQueue.sync {
            self.mixer.videoIO.unregisterEffect(effect)
        }
    }

    /// Register a audio effect.
    public func registerAudioEffect(_ effect: AudioEffect) -> Bool {
        mixer.audioIO.lockQueue.sync {
            self.mixer.audioIO.registerEffect(effect)
        }
    }

    /// Unregister a audio effect.
    public func unregisterAudioEffect(_ effect: AudioEffect) -> Bool {
        mixer.audioIO.lockQueue.sync {
            self.mixer.audioIO.unregisterEffect(effect)
        }
    }

    /// Starts recording.
    public func startRecording() {
        mixer.recorder.startRunning()
    }

    /// Stop recording.
    public func stopRecording() {
        mixer.recorder.stopRunning()
    }
}
