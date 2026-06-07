//
//  QRCodeError.swift
//  SwiftQRScanner
//
//  Created by Vinod Jagtap on 14/05/22.
//

import Foundation

public enum QRCodeError: Error, Equatable {
    case inputFailed
    case outputFailed
    case emptyResult
    case cameraPermissionDenied
}

extension QRCodeError: CustomStringConvertible, LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .inputFailed:
            return NSLocalizedString("Failed to add input.", comment: "Failed to add input.")
        case .outputFailed:
            return NSLocalizedString("Failed to add output.", comment: "Failed to add output.")
        case .emptyResult:
            return NSLocalizedString("Empty string found", comment: "Empty string found.")
        case .cameraPermissionDenied:
            return NSLocalizedString("Camera permission denied.", comment: "Camera permission denied.")
        }
    }

    public var description: String {
        return errorDescription ?? ""
    }
}
