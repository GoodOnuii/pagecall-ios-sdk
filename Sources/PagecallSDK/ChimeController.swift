//
//  ChimeController.swift
//
//
//  Created by 록셉 on 2022/07/27.
//

import AmazonChimeSDK
import AVFoundation
import Foundation

struct MediaType: Codable {
    var audio: Bool?
    var video: Bool?
}

class ChimeController {
    let emitter: WebViewEmitter
    var chimeMeetingSession: ChimeMeetingSession?

    init(emitter: WebViewEmitter) {
        self.emitter = emitter
    }

    func createMeetingSession(joinMeetingData: Data, callback: (Error?) -> Void) {
        let logger = ConsoleLogger(name: "DefaultMeetingSession", level: LogLevel.INFO)

        let meetingSessionConfiguration = JoinRequestService.getMeetingSessionConfiguration(data: joinMeetingData)

        guard let meetingSessionConfiguration = meetingSessionConfiguration else {
            callback(NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to parse joinMeetingData"]))
            return
        }
        if let prevChimeMeetingSession = self.chimeMeetingSession {
            prevChimeMeetingSession.dispose()
        }

        let chimeMeetingSession = ChimeMeetingSession(configuration: meetingSessionConfiguration, logger: logger, emitter: emitter)
        self.chimeMeetingSession = chimeMeetingSession
        callback(nil)
    }

    func start(callback: (Error?) -> Void) {
        if let chimeMeetingSession = chimeMeetingSession {
            chimeMeetingSession.start { (error: Error?) in
                if error != nil {
                    callback(NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to start session"]))
                } else {
                    callback(nil)
                }
            }
        } else {
            callback(NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "ChimeMeetingSession not exist"]))
        }
    }

    func stop(callback: (Error?) -> Void) {
        if let chimeMeetingSession = chimeMeetingSession {
            chimeMeetingSession.stop()
            callback(nil)
        } else {
            callback(NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "ChimeMeetingSession not exist"]))
        }
    }

    func getPermissions(constraint: Data, callback: (Error?) -> Void) -> Data? {
        guard let mediaType = try? JSONDecoder().decode(MediaType.self, from: constraint) else {
            callback(NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Wrong Constraint"]))
            return nil
        }

        func getAudioStatus() -> Bool? {
            if let audio = mediaType.audio {
                if !audio { return nil }
                let status = AVCaptureDevice.authorizationStatus(for: .audio)
                switch status {
                    case .notDetermined: return nil
                    case .restricted: return false
                    case .denied: return false
                    case .authorized: return true
                    default: return nil
                }
            } else { return nil }
        }
        func getVideoStatus() -> Bool? {
            if let video = mediaType.video {
                if !video { return nil }
                let status = AVCaptureDevice.authorizationStatus(for: .video)
                switch status {
                    case .notDetermined: return nil
                    case .restricted: return false
                    case .denied: return false
                    case .authorized: return true
                    default: return nil
                }
            } else { return nil }
        }

        if let data = try? JSONEncoder().encode(MediaType(audio: getAudioStatus(), video: getVideoStatus())) {
            return data
        } else {
            callback(NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to getPermissions"]))
            return nil
        }
    }

    // TODO: video permission
    func requestPermissions(constraint: Data, callback: @escaping (MediaType?, Error?) -> Void) {
        guard let mediaType = try? JSONDecoder().decode(MediaType.self, from: constraint) else {
            callback(nil, NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Wrong Constraint"]))
            return
        }

        if let video = mediaType.video {
            if video {
                callback(nil, NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Not Implemented for Video Permission"]))
                return
            }
        }

        func requestAudioPermission(callback: @escaping (Bool) -> Void) {
            if let audio = mediaType.audio {
                if !audio {
                    callback(false)
                    return
                }
                AVCaptureDevice.requestAccess(for: .audio) {
                    isAudio in callback(isAudio)
                }
            } else {
                callback(false)
            }
        }

        requestAudioPermission { isAudio in callback(MediaType(audio: isAudio, video: false), nil) }
    }

    func pauseAudio(callback: (Error?) -> Void) {
        if let chimeMeetingSession = chimeMeetingSession {
            let isSucceed = chimeMeetingSession.pauseAudio()
            if isSucceed {
                callback(nil)
            } else {
                callback(NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed at chimeMeetingSession.pauseAudio"]))
            }
        } else {
            callback(NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "ChimeMeetingSession not exist"]))
        }
    }

    func resumeAudio(callback: (Error?) -> Void) {
        if let chimeMeetingSession = chimeMeetingSession {
            let isSucceed = chimeMeetingSession.resumeAudio()
            if isSucceed {
                callback(nil)
            } else {
                callback(NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed at chimeMeetingSession.resumeAudio"]))
                return
            }
        } else {
            callback(NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "ChimeMeetingSession not exist"]))
        }
    }

    func setAudioDevice(deviceData: Data, callback: (Error?) -> Void) {
        struct DeviceId: Codable {
            var deviceId: String
        }

        guard let deviceId = try? JSONDecoder().decode(DeviceId.self, from: deviceData) else {
            callback(NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "DeviceId not exist"]))
            return
        }

        guard let chimeMeetingSession = chimeMeetingSession else {
            callback(NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "ChimeMeetingSession not exist"]))
            return
        }

        chimeMeetingSession.setAudioDevice(label: deviceId.deviceId)
        callback(nil)
    }

    func getAudioDevices() -> [MediaDeviceInfo] {
        guard let chimeMeetingSession = chimeMeetingSession else {
            return []
        }

        let audioDevices = chimeMeetingSession.getAudioDevices()

        return audioDevices.map { mediaDevice in
            MediaDeviceInfo(deviceId: mediaDevice.label, groupId: "DefaultGroupId", kind: .audioinput, label: mediaDevice.label)
        }
    }
}
