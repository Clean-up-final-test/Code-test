// Proprietary Software License Version 1.0
//
// Copyright (C) 2025 BDG
//
// Backdoor App Signer is proprietary software. You may not use, modify, or distribute it except as expressly permitted under the terms of the Proprietary Software License.

import CoreData
import Foundation
import SwiftUI
import UIKit
import UniformTypeIdentifiers

extension LibraryViewController: UIDocumentPickerDelegate {
    func startImporting() {
        let actionSheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)

        let documentPickerAction = UIAlertAction(title: String.localized("LIBRARY_VIEW_CONTROLLER_IMPORT_ACTION_SHEET_FILE"), style: .default) { [weak self] _ in
            self?.presentDocumentPicker(fileExtension: [
                UTType(filenameExtension: "ipa")!,
                UTType(filenameExtension: "tipa")!,
            ])
        }

        let photoLibraryAction = UIAlertAction(title: String.localized("LIBRARY_VIEW_CONTROLLER_IMPORT_ACTION_SHEET_URL"), style: .default) { [weak self] _ in
            self?.downloadFileFromUrl()
        }

        let cancelAction = UIAlertAction(title: String.localized("CANCEL"), style: .cancel, handler: nil)

        actionSheet.addAction(documentPickerAction)
        actionSheet.addAction(photoLibraryAction)
        actionSheet.addAction(cancelAction)

        if let popoverController = actionSheet.popoverPresentationController {
            popoverController.sourceView = self.view
            popoverController.sourceRect = CGRect(x: self.view.bounds.midX, y: self.view.bounds.midY, width: 0, height: 0)
            popoverController.permittedArrowDirections = []
        }

        self.present(actionSheet, animated: true, completion: nil)
    }

    func downloadFileFromUrl() {
        let alert = UIAlertController(title: String.localized("LIBRARY_VIEW_CONTROLLER_IMPORT_ACTION_SHEET_URL"), message: nil, preferredStyle: .alert)

        alert.addTextField { textField in
            textField.placeholder = "URL"
            textField.autocapitalizationType = .none
            textField.addTarget(self, action: #selector(self.textURLDidChange(_:)), for: .editingChanged)
        }

        let setAction = UIAlertAction(title: String.localized("IMPORT"), style: .default) { _ in
            guard let textField = alert.textFields?.first, let enteredURL = textField.text else { return }
            self.startDownloadIfNeeded(downloadURL: URL(string: enteredURL), sourceLocation: "Imported from URL")
            //			Preferences.onlinePath = enteredURL
        }

        setAction.isEnabled = false
        let cancelAction = UIAlertAction(title: String.localized("CANCEL"), style: .cancel, handler: nil)

        alert.addAction(setAction)
        alert.addAction(cancelAction)
        present(alert, animated: true, completion: nil)
    }

    @objc func textURLDidChange(_ textField: UITextField) {
        guard let alertController = presentedViewController as? UIAlertController, let setAction = alertController.actions.first(where: { $0.title == String.localized("IMPORT") }) else { return }

        let enteredURL = textField.text ?? ""
        setAction.isEnabled = isValidURL(enteredURL)
    }

    func isValidURL(_ url: String) -> Bool {
        let urlPredicate = NSPredicate(format: "SELF MATCHES %@", "https://.+")
        return urlPredicate.evaluate(with: url)
    }

    //

    func presentDocumentPicker(fileExtension: [UTType]) {
        let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: fileExtension, asCopy: true)
        documentPicker.delegate = self
        documentPicker.allowsMultipleSelection = false
        present(documentPicker, animated: true, completion: nil)
    }

    func documentPicker(_: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let selectedFileURL = urls.first else { return }

        guard let loaderAlert = self.loaderAlert else {
            Debug.shared.log(message: "Loader alert is not initialized.", type: .error)
            return
        }

        DispatchQueue.main.async {
            self.present(loaderAlert, animated: true)
        }

        let dl = AppDownload()
        let uuid = UUID().uuidString

        DispatchQueue.global(qos: .background).async {
            do {
                try handleIPAFile(destinationURL: selectedFileURL, uuid: uuid, dl: dl)

                DispatchQueue.main.async {
                    self.loaderAlert?.dismiss(animated: true)
                }

            } catch {
                Debug.shared.log(message: "Failed to Import: \(error)", type: .error)

                DispatchQueue.main.async {
                    self.loaderAlert?.dismiss(animated: true)
                }
            }
        }
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        controller.dismiss(animated: true, completion: nil)
    }
}

extension LibraryViewController {
    static var appDownload: AppDownload?
    func startDownloadIfNeeded(downloadURL: URL?, sourceLocation: String) {
        guard let downloadURL = downloadURL else {
            return
        }

        DispatchQueue.main.async {
            self.present(self.loaderAlert!, animated: true)
        }

        if LibraryViewController.appDownload == nil {
            LibraryViewController.appDownload = AppDownload()
        }
        DispatchQueue(label: "DL").async {
            LibraryViewController.appDownload?.downloadFile(url: downloadURL, appuuid: UUID().uuidString) { [weak self] uuid, filePath, error in
                guard let self = self else { return }
                if let error = error {
                    DispatchQueue.main.async {
                        self.loaderAlert?.dismiss(animated: true)
                    }
                    Debug.shared.log(message: "Failed to Import: \(error)", type: .error)
                } else if let uuid = uuid, let filePath = filePath {
                    LibraryViewController.appDownload?.extractCompressedBundle(packageURL: filePath) { targetBundle, error in

                        if let error = error {
                            DispatchQueue.main.async {
                                self.loaderAlert?.dismiss(animated: true)
                            }
                            Debug.shared.log(message: "Failed to Import: \(error)", type: .error)
                        } else if let targetBundle = targetBundle {
                            LibraryViewController.appDownload?.addToApps(bundlePath: targetBundle, uuid: uuid, sourceLocation: sourceLocation) { error in
                                if let error = error {
                                    DispatchQueue.main.async {
                                        self.loaderAlert?.dismiss(animated: true)
                                    }
                                    Debug.shared.log(message: "Failed to Import: \(error)", type: .error)
                                } else {
                                    DispatchQueue.main.async {
                                        self.loaderAlert?.dismiss(animated: true)
                                    }
                                    Debug.shared.log(message: String.localized("DONE"), type: .success)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

extension LibraryViewController {
    @objc func startInstallProcess(app: NSManagedObject, filePath: String) {
        guard !filePath.isEmpty else {
            Debug.shared.log(message: "Empty file path provided for installation", type: .error)
            return
        }
        
        UIApplication.shared.isIdleTimerDisabled = true

        let name = app.value(forKey: "name") as? String ?? "Unknown App"
        let bundleID = app.value(forKey: "bundleidentifier") as? String ?? "com.unknown.app"
        let version = app.value(forKey: "version") as? String ?? "1.0"

        presentTransferPreview(
            with: filePath, 
            id: bundleID, 
            version: version, 
            name: name
        )
    }

    @objc func shareFile(app: NSManagedObject, filePath: String) {
        guard !filePath.isEmpty else {
            Debug.shared.log(message: "Empty file path provided for sharing", type: .error)
            return
        }
        
        UIApplication.shared.isIdleTimerDisabled = true

        let name = app.value(forKey: "name") as? String ?? "Unknown App"
        let bundleID = app.value(forKey: "bundleidentifier") as? String ?? "com.unknown.app"
        let version = app.value(forKey: "version") as? String ?? "1.0"

        presentTransferPreview(
            with: filePath, 
            isSharing: true, 
            id: bundleID, 
            version: version, 
            name: name
        )
    }
    
    // MARK: - Legacy methods for backward compatibility
    
    @objc func startInstallProcess(meow: NSManagedObject, filePath: String) {
        startInstallProcess(app: meow, filePath: filePath)
    }
    
    @objc func shareFile(meow: NSManagedObject, filePath: String) {
        shareFile(app: meow, filePath: filePath)
    }

    func presentTransferPreview(
        with appPath: String,
        isSharing: Bool = false,
        id: String,
        version: String,
        name: String
    ) {
        do {
            guard let versionNumber = Int(version) ?? Int("1") else {
                Debug.shared.log(message: "Failed to parse version number", type: .error)
                return
            }
            
            let installer = try Installer(
                path: nil,
                metadata: AppData(id: id, version: versionNumber, name: name)
            )
            
            self.installer = installer

            let transferPreview = TransferPreview(
                installer: installer,
                appPath: appPath,
                appName: name,
                isSharing: isSharing
            )
            .onDisappear { [weak self] in
                self?.installer?.shutdownServer()
                self?.installer = nil
                UIApplication.shared.isIdleTimerDisabled = false
            }

            let hostingController = UIHostingController(rootView: transferPreview)
            hostingController.modalPresentationStyle = .pageSheet

            if let presentationController = hostingController.presentationController as? UISheetPresentationController {
                let detent = UISheetPresentationController.Detent._detent(
                    withIdentifier: "TransferPreviewDetent",
                    constant: 200.0
                )
                presentationController.detents = [detent]
                presentationController.prefersGrabberVisible = true
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.present(hostingController, animated: true)
            }

        } catch {
            Debug.shared.log(message: "Error creating installer: \(error)", type: .error)
            installer?.shutdownServer()
            installer = nil
        }
    }
}
