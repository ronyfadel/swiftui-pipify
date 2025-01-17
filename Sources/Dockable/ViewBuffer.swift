//
//  File.swift
//  Dockable
//
//  Created by James Sherlock on 01/07/2022.
//

import SwiftUI
import AVFoundation

@available(macOS 13.0, *)
extension View {
    /// Creates a `CMSampleBuffer` containing the rendered view.
    func makeBuffer(renderer: ImageRenderer<some View>) async throws -> CMSampleBuffer {
        // Pixel Buffer
        var buffer: CVPixelBuffer?
        await renderer.render { size, callback in
            let status = CVPixelBufferCreate(
                kCFAllocatorDefault,
                Int(size.width),
                Int(size.height),
                kCVPixelFormatType_32ARGB,
                [
                    kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue!,
                    kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue!,
                    kCVPixelBufferIOSurfacePropertiesKey: [:] as CFDictionary,
                ] as CFDictionary,
                &buffer
            )
            
            guard let unwrappedBuffer = buffer, status == kCVReturnSuccess else {
                return
            }
            
            CVPixelBufferLockBaseAddress(unwrappedBuffer, [])
            defer { CVPixelBufferUnlockBaseAddress(unwrappedBuffer, []) }

            let context = CGContext(
                data: CVPixelBufferGetBaseAddress(unwrappedBuffer),
                width: Int(size.width),
                height: Int(size.height),
                bitsPerComponent: 8,
                bytesPerRow: CVPixelBufferGetBytesPerRow(unwrappedBuffer),
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
            )
            
            guard let unwrappedContext = context else {
                return
            }
            
            callback(unwrappedContext)
        }
        
        guard let unwrappedPixelBuffer = buffer else {
            throw NSError(domain: "com.getsidetrack.dockable", code: 0)
        }
        
        // Format Description
        var formatDescription: CMFormatDescription?
        let status = CMVideoFormatDescriptionCreateForImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: unwrappedPixelBuffer,
            formatDescriptionOut: &formatDescription
        )
        
        guard let unwrappedFormatDescription = formatDescription, status == kCVReturnSuccess else {
            throw NSError(domain: "com.getsidetrack.dockable", code: 1)
        }
        
        // Timing Info
        let now = CMTime(
            seconds: CACurrentMediaTime(),
            preferredTimescale: 120
        )
        
        let timingInfo = CMSampleTimingInfo(
            duration: .init(seconds: 1, preferredTimescale: 60),
            presentationTimeStamp: now,
            decodeTimeStamp: now
        )

        return try CMSampleBuffer(
            imageBuffer: unwrappedPixelBuffer,
            formatDescription: unwrappedFormatDescription,
            sampleTiming: timingInfo
        )
    }
}
