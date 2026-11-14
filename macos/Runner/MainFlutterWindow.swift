import AVFoundation
import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  private let continuityTone = ContinuityTone()

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    let tone = continuityTone
    FlutterMethodChannel(
      name: "ca.richyoung.mooshrevolt/continuity_tone",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    ).setMethodCallHandler { call, result in
      do {
        switch call.method {
        case "prepare": try tone.prepare()
        case "start": try tone.start()
        case "stop": tone.stop()
        case "release": tone.release()
        default:
          result(FlutterMethodNotImplemented)
          return
        }
        result(nil)
      } catch {
        result(
          FlutterError(
            code: "audio", message: error.localizedDescription, details: nil))
      }
    }

    super.awakeFromNib()
  }
}

/// A continuous 880 Hz continuity tone with no start-up latency.
///
/// Launching a player per beep takes hundreds of milliseconds, so the tone
/// lagged behind the reading it reports. Instead the audio engine keeps
/// running while continuity is armed and the render callback ramps its gain
/// between silence and the tone within a few milliseconds.
private final class ContinuityTone {
  private let engine = AVAudioEngine()
  private var source: AVAudioSourceNode?
  private var phase = 0.0
  private var gain: Float = 0
  // Written on the main thread, read on the render thread; a torn read only
  // delays a ramp by one buffer.
  private var targetGain: Float = 0

  private let frequency = 880.0
  private let amplitude: Float = 0.35
  private let rampSeconds = 0.005

  func prepare() throws {
    if source == nil {
      let sampleRate = engine.outputNode.outputFormat(forBus: 0).sampleRate
      guard
        let format = AVAudioFormat(
          standardFormatWithSampleRate: sampleRate, channels: 1)
      else { return }
      let phaseStep = 2 * Double.pi * frequency / sampleRate
      let rampStep = Float(1 / (rampSeconds * sampleRate))
      let node = AVAudioSourceNode(format: format) {
        [unowned self] _, _, frameCount, audioBufferList in
        let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)
        let target = self.targetGain
        for frame in 0..<Int(frameCount) {
          if self.gain < target {
            self.gain = min(target, self.gain + rampStep)
          } else if self.gain > target {
            self.gain = max(target, self.gain - rampStep)
          }
          let sample = Float(sin(self.phase)) * self.amplitude * self.gain
          self.phase += phaseStep
          if self.phase >= 2 * Double.pi { self.phase -= 2 * Double.pi }
          for buffer in buffers {
            buffer.mData?.assumingMemoryBound(to: Float.self)[frame] = sample
          }
        }
        return noErr
      }
      engine.attach(node)
      engine.connect(node, to: engine.mainMixerNode, format: format)
      source = node
    }
    if !engine.isRunning {
      engine.prepare()
      try engine.start()
    }
  }

  func start() throws {
    try prepare()
    targetGain = 1
  }

  func stop() {
    targetGain = 0
  }

  func release() {
    targetGain = 0
    gain = 0
    engine.stop()
  }
}
