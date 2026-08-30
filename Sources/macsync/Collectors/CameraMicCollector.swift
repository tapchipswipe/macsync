import AppKit
import CoreAudio
import Foundation
import IOKit

/// Detects whether camera / microphone hardware is currently in use.
/// METADATA ONLY: boolean device state + frontmost-app heuristic. No audio
/// or video content is ever touched.
final class CameraMicCollector {
    private let store = DataStore.shared
    private var timer: Timer?
    private var lastState: (cam: Bool, mic: Bool)?

    private let pollInterval: TimeInterval = 30

    func start() {
        stop()
        let t = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] _ in
            self?.poll()
        }
        t.fire()
        timer = t
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func poll() {
        let cam = Self.isCameraActive()
        let mic = Self.isAnyInputDeviceRunning()

        // Only log on state change or every ~15 min heartbeat to keep noise down.
        let heartbeat = Int(Date().timeIntervalSince1970) % (15 * 60) < Int(pollInterval)
        guard lastState?.cam != cam || lastState?.mic != mic || heartbeat else { return }
        lastState = (cam, mic)

        let front = NSWorkspace.shared.frontmostApplication?.localizedName
        let payload = CameraMicPayload(
            observedAt: Date(),
            cameraActive: cam,
            microphoneActive: mic,
            frontmostApp: front
        )
        store.append(TrackerEvent(ts: payload.observedAt, kind: .cameraMicState, payload: .cameraMicState(payload)))
    }

    // MARK: - Camera (IOKit: FaceTime camera device "in use" flag)

    static func isCameraActive() -> Bool {
        // The built-in camera exposes `IOCameraDevice` / VDC entries; when in use
        // the registry shows an active client. Simplest reliable proxy: check the
        // camera device's `IOService` busy state via `ioreg`-style matching.
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("AppleH13CamIn"), &iterator) == KERN_SUCCESS
           || IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("AppleEmbeddedCamera"), &iterator) == KERN_SUCCESS
        else { return false }
        defer { IOObjectRelease(iterator) }

        while case let service = IOIteratorNext(iterator), service != 0 {
            defer { IOObjectRelease(service) }
            var propsRef: Unmanaged<CFMutableDictionary>?
            if IORegistryEntryCreateCFProperties(service, &propsRef, kCFAllocatorDefault, 0) == KERN_SUCCESS,
               let props = propsRef?.takeRetainedValue() as? [String: Any] {
                if let inUse = props["CameraInUse"] as? Bool, inUse { return true }
                if let state = props["CameraState"] as? Int, state != 0 { return true }
            }
        }
        return false
    }

    // MARK: - Microphone (CoreAudio: any input device currently running)

    static func isAnyInputDeviceRunning() -> Bool {
        var prop = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &prop, 0, nil, &size) == noErr else { return false }
        let count = Int(size) / MemoryLayout<AudioDeviceID>.size
        var devices = [AudioDeviceID](repeating: 0, count: count)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &prop, 0, nil, &size, &devices) == noErr else { return false }

        for device in devices {
            var inputProp = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyDeviceIsRunning,
                mScope: kAudioDevicePropertyScopeInput,
                mElement: kAudioObjectPropertyElementMain
            )
            var running: UInt32 = 0
            var propSize = UInt32(MemoryLayout<UInt32>.size)
            if AudioObjectGetPropertyData(device, &inputProp, 0, nil, &propSize, &running) == noErr, running != 0 {
                return true
            }
        }
        return false
    }
}
