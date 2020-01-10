//
//  ALTDeviceManager+Installation.swift
//  AltServer
//
//  Created by Riley Testut on 7/1/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

import Cocoa
import UserNotifications
import ObjectiveC

enum InstallError: LocalizedError
{
    case cancelled
    case noTeam
    case noSuchDevice
    case missingPrivateKey
    case missingCertificate
    
    var errorDescription: String? {
        switch self
        {
        case .cancelled: return NSLocalizedString("The operation was cancelled.", comment: "")
        case .noTeam: return NSLocalizedString("You are not a member of any developer teams.", comment: "")
        case .noSuchDevice: return NSLocalizedString("This device is not registered to your development team, turn on \"Register Device Automatically\" if necessary.", comment: "")
        case .missingPrivateKey: return NSLocalizedString("The developer certificate's private key could not be found.", comment: "")
        case .missingCertificate: return NSLocalizedString("The developer certificate could not be found.", comment: "")
        }
    }
}

extension ALTDeviceManager
{
    @objc func installApplication(to device: ALTDevice, appleID: String, password: String, applicationURL: URL, completion: @escaping (Error?) -> Void) -> Progress
    {
        let destinationDirectoryURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        
        func finish(_ error: Error?, title: String = "")
        {
			if let error = error {
				completion(error)
			}
			else {
				completion(nil)
			}
            try? FileManager.default.removeItem(at: destinationDirectoryURL)
        }
        
        let progress = Progress.init(totalUnitCount: 19)
        progress.localizedDescription = "Requesting anisette data...";
        
        AnisetteDataManager.shared.requestAnisetteData { (result) in
            do
            {
                let anisetteData = try result.get()
                progress.completedUnitCount += 1
				progress.localizedDescription = "Authenticating with your Apple ID...";
                
                self.authenticate(appleID: appleID, password: password, anisetteData: anisetteData) { (result) in
                    do
                    {
                        let (account, session) = try result.get()
						progress.completedUnitCount += 1
						progress.localizedDescription = "Fetching team information...";
                        
                        self.fetchTeam(for: account, session: session) { (result) in
                            do
                            {
                                let team = try result.get()
								progress.completedUnitCount += 1
								progress.localizedDescription = "Registering device...";
                                
                                self.fetchOrRegister(device, team: team, session: session) { (result) in
                                    do
                                    {
                                        let device = try result.get()
										progress.completedUnitCount += 1
										progress.localizedDescription = "Fetching certificates...";
                                        
                                        self.fetchCertificate(for: team, session: session) { (result) in
                                            do
                                            {
                                                let certificate = try result.get()
												progress.completedUnitCount += 1
												progress.localizedDescription = "Downloading your app...";
                                                
                                                self.downloadApp(applicationURL: applicationURL) { (result) in
                                                    do
                                                    {
                                                        let fileURL = try result.get()
                                                        
                                                        try FileManager.default.createDirectory(at: destinationDirectoryURL, withIntermediateDirectories: true, attributes: nil)
                                                        
                                                        let appBundleURL = try FileManager.default.unzipAppBundle(at: fileURL, toDirectory: destinationDirectoryURL)
                                                        
                                                        do
                                                        {
                                                            try FileManager.default.removeItem(at: fileURL)
                                                        }
                                                        catch
                                                        {
                                                            print("Failed to remove downloaded .ipa.", error)
                                                        }
                                                        
                                                        guard let application = ALTApplication(fileURL: appBundleURL) else { throw ALTError(.invalidApp) }
														progress.completedUnitCount += 1
														progress.localizedDescription = "Registering the App ID...";
                                                        
                                                        self.registerAppID(name: "ALT- \(application.name)", identifier: application.bundleIdentifier, team: team, session: session) { (result) in
                                                            do
                                                            {
                                                                let appID = try result.get()
																progress.completedUnitCount += 1
																progress.localizedDescription = "Updating App ID...";
                                                                
                                                                self.updateFeatures(for: appID, app: application, team: team, session: session) { (result) in
                                                                    do
                                                                    {
                                                                        let appID = try result.get()
																		progress.completedUnitCount += 1
																		progress.localizedDescription = "Fetching the provisioning profile...";
                                                                        
                                                                        self.fetchProvisioningProfile(for: appID, team: team, session: session) { (result) in
                                                                            do
                                                                            {
                                                                                let provisioningProfile = try result.get()
																				progress.completedUnitCount += 1
																				progress.localizedDescription = "Beginning installation...";
                                                                                
                                                                                self.install(application, to: device, team: team, appID: appID, certificate: certificate, profile: provisioningProfile, progress: progress) { (result) in
                                                                                    finish(result.error, title: "Failed to Install App")
                                                                                }
                                                                            }
                                                                            catch
                                                                            {
                                                                                finish(error, title: "Failed to Fetch Provisioning Profile")
                                                                            }
                                                                        }
                                                                    }
                                                                    catch
                                                                    {
                                                                        finish(error, title: "Failed to Update App ID")
                                                                    }
                                                                }
                                                            }
                                                            catch
                                                            {
                                                                finish(error, title: "Failed to Register App")
                                                            }
                                                        }
                                                    }
                                                    catch
                                                    {
                                                        finish(error, title: "Failed to Download App")
                                                        return
                                                    }
                                                }
                                            }
                                            catch
                                            {
                                                finish(error, title: "Failed to Fetch Certificate")
                                            }
                                        }
                                    }
                                    catch
                                    {
                                        finish(error, title: "Failed to Register Device")
                                    }
                                }
                            }
                            catch
                            {
                                finish(error, title: "Failed to Fetch Team")
                            }
                        }
                    }
                    catch
                    {
                        finish(error, title: "Failed to Authenticate")
                    }
                }
            }
            catch
            {
                finish(error, title: "Failed to Fetch Anisette Data")
            }
        }
        
        return progress
    }
    
    func downloadApp(applicationURL: URL, completionHandler: @escaping (Result<URL, Error>) -> Void)
    {
		if applicationURL.isFileURL {
			DispatchQueue.global().async {
				let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID.init().uuidString).appendingPathExtension("ipa")
				do {
					try FileManager.default.copyItem(at: applicationURL, to: fileURL)
					completionHandler(.success(fileURL))
				}
				catch let error {
					completionHandler(.failure(error))
				}
			}
		}
		else {
			let request = NSMutableURLRequest.init(url: applicationURL)
			request.addValue(applicationURL.host!, forHTTPHeaderField: "Referer")
			let finalRequest = request.copy() as! URLRequest
			let downloadTask = URLSession.shared.downloadTask(with: finalRequest) { (fileURL, response, error) in
				do
				{
					let (fileURL, _) = try Result((fileURL, response), error).get()
					completionHandler(.success(fileURL))
				}
				catch
				{
					completionHandler(.failure(error))
				}
			}
			
			downloadTask.resume()
        }
    }
    
    func authenticate(appleID: String, password: String, anisetteData: ALTAnisetteData, completionHandler: @escaping (Result<(ALTAccount, ALTAppleAPISession), Error>) -> Void)
    {
        func handleVerificationCode(_ completionHandler: @escaping (String?) -> Void)
        {
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = NSLocalizedString("Two-Factor Authentication Enabled", comment: "")
                alert.informativeText = NSLocalizedString("Please enter the 6-digit verification code that was sent to your Apple devices.", comment: "")
                
                let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 22))
                textField.delegate = self
                textField.translatesAutoresizingMaskIntoConstraints = false
                textField.placeholderString = NSLocalizedString("123456", comment: "")
                alert.accessoryView = textField
                alert.window.initialFirstResponder = textField
                
                alert.addButton(withTitle: NSLocalizedString("Continue", comment: ""))
                alert.addButton(withTitle: NSLocalizedString("Cancel", comment: ""))
                
                self.securityCodeAlert = alert
                self.securityCodeTextField = textField
                self.validate()
                
                NSRunningApplication.current.activate(options: .activateIgnoringOtherApps)
                
                let response = alert.runModal()
                if response == .alertFirstButtonReturn
                {
                    let code = textField.stringValue
                    completionHandler(code)
                }
                else
                {
                    completionHandler(nil)
                }
            }
        }
        
        ALTAppleAPI.shared.authenticate(appleID: appleID, password: password, anisetteData: anisetteData, verificationHandler: handleVerificationCode) { (account, session, error) in
            if let account = account, let session = session
            {
                completionHandler(.success((account, session)))
            }
            else
            {
                completionHandler(.failure(error ?? ALTAppleAPIError(.unknown)))
            }
        }
    }
    
    func fetchTeam(for account: ALTAccount, session: ALTAppleAPISession, completionHandler: @escaping (Result<ALTTeam, Error>) -> Void)
    {
        func finish(_ result: Result<ALTTeam, Error>)
        {
            switch result
            {
            case .failure(let error):
                completionHandler(.failure(error))
                
            case .success(let team):
                
                var isCancelled = false
                
                if team.type != .free
                {
                    DispatchQueue.main.sync {
                        let alert = NSAlert()
                        alert.messageText = NSLocalizedString("Installing AltDeploy will revoke your iOS development certificate.", comment: "")
                        alert.informativeText = NSLocalizedString("""
This will not affect apps you've submitted to the App Store, but may cause apps you've installed to your devices with Xcode to stop working until you reinstall them.

To prevent this from happening, feel free to try again with another Apple ID to install AltDeploy.
""", comment: "")
                        
                        alert.addButton(withTitle: NSLocalizedString("Continue", comment: ""))
                        alert.addButton(withTitle: NSLocalizedString("Cancel", comment: ""))
                        
                        NSRunningApplication.current.activate(options: .activateIgnoringOtherApps)
                        
                        let buttonIndex = alert.runModal()
                        if buttonIndex == NSApplication.ModalResponse.alertSecondButtonReturn
                        {
                            isCancelled = true
                        }
                    }
                    
                    if isCancelled
                    {
                        return completionHandler(.failure(InstallError.cancelled))
                    }
                }
                
                completionHandler(.success(team))
            }
        }
        
        ALTAppleAPI.shared.fetchTeams(for: account, session: session) { (teams, error) in
            do
            {
                let teams = try Result(teams, error).get()
                
                if let team = teams.first(where: { $0.type == .free })
                {
                    return finish(.success(team))
                }
                else if let team = teams.first(where: { $0.type == .individual })
                {
                    return finish(.success(team))
                }
                else if let team = teams.first
                {
                    return finish(.success(team))
                }
                else
                {
                    throw InstallError.noTeam
                }
            }
            catch
            {
                finish(.failure(error))
            }
        }
    }
    
    func fetchCertificate(for team: ALTTeam, session: ALTAppleAPISession, completionHandler: @escaping (Result<ALTCertificate, Error>) -> Void)
    {
        ALTAppleAPI.shared.fetchCertificates(for: team, session: session) { (certificates, error) in
            do
            {
                let certificates = try Result(certificates, error).get()
                
                if let certificate = certificates.first
                {
                    ALTAppleAPI.shared.revoke(certificate, for: team, session: session) { (success, error) in
                        do
                        {
                            try Result(success, error).get()
                            self.fetchCertificate(for: team, session: session, completionHandler: completionHandler)
                        }
                        catch
                        {
                            completionHandler(.failure(error))
                        }
                    }
                }
                else
                {
                    ALTAppleAPI.shared.addCertificate(machineName: "AltDeploy", to: team, session: session) { (certificate, error) in
                        do
                        {
                            let certificate = try Result(certificate, error).get()
                            guard let privateKey = certificate.privateKey else { throw InstallError.missingPrivateKey }
                            
                            ALTAppleAPI.shared.fetchCertificates(for: team, session: session) { (certificates, error) in
                                do
                                {
                                    let certificates = try Result(certificates, error).get()
                                    
                                    guard let certificate = certificates.first(where: { $0.serialNumber == certificate.serialNumber }) else {
                                        throw InstallError.missingCertificate
                                    }
                                    
                                    certificate.privateKey = privateKey
                                    
                                    completionHandler(.success(certificate))
                                }
                                catch
                                {
                                    completionHandler(.failure(error))
                                }
                            }
                        }
                        catch
                        {
                            completionHandler(.failure(error))
                        }
                    }
                }
            }
            catch
            {
                completionHandler(.failure(error))
            }
        }
    }
    
    func registerAppID(name appName: String, identifier: String, team: ALTTeam, session: ALTAppleAPISession, completionHandler: @escaping (Result<ALTAppID, Error>) -> Void)
    {
        ALTAppleAPI.shared.fetchAppIDs(for: team, session: session) { (appIDs, error) in
            do
            {
                let appIDs = try Result(appIDs, error).get()
                
                if let appID = appIDs.first(where: { $0.bundleIdentifier.hasSuffix(".\(identifier)") })
                {
                    completionHandler(.success(appID))
                }
                else
                {
                    let uuid = UUID.init().uuidString;
                    let bundleID = "ALT-\(uuid).\(identifier)"
                    
                    ALTAppleAPI.shared.addAppID(withName: appName, bundleIdentifier: bundleID, team: team, session: session) { (appID, error) in
                        completionHandler(Result(appID, error))
                    }
                }
            }
            catch
            {
                completionHandler(.failure(error))
            }
        }
    }
    
    func updateFeatures(for appID: ALTAppID, app: ALTApplication, team: ALTTeam, session: ALTAppleAPISession, completionHandler: @escaping (Result<ALTAppID, Error>) -> Void)
    {
        let requiredFeatures = app.entitlements.compactMap { (entitlement, value) -> (ALTFeature, Any)? in
            guard let feature = ALTFeature(entitlement: entitlement) else { return nil }
            return (feature, value)
        }
        
        var features = requiredFeatures.reduce(into: [ALTFeature: Any]()) { $0[$1.0] = $1.1 }
        
        if let applicationGroups = app.entitlements[.appGroups] as? [String], !applicationGroups.isEmpty
        {
            features[.appGroups] = true
        }
        
        let appID = appID.copy() as! ALTAppID
        appID.features = features
        
        ALTAppleAPI.shared.update(appID, team: team, session: session) { (appID, error) in
            completionHandler(Result(appID, error))
        }
    }
    
    func fetchOrRegister(_ device: ALTDevice, team: ALTTeam, session: ALTAppleAPISession, completionHandler: @escaping (Result<ALTDevice, Error>) -> Void)
    {
        ALTAppleAPI.shared.fetchDevices(for: team, session: session) { (devices, error) in
            do
            {
                let devices = try Result(devices, error).get()
                
                if let device = devices.first(where: { $0.identifier == device.identifier })
                {
                    completionHandler(.success(device))
                }
                else
                {
                    if self.registerDeviceAutomatically {
                        ALTAppleAPI.shared.registerDevice(name: device.name, identifier: device.identifier, team: team, session: session) { (device, error) in
                            completionHandler(Result(device, error))
                        }
                    } else {
                        completionHandler(.failure(InstallError.noSuchDevice))
                    }
                }
            }
            catch
            {
                completionHandler(.failure(error))
            }
        }
    }
    
    func fetchProvisioningProfile(for appID: ALTAppID, team: ALTTeam, session: ALTAppleAPISession, completionHandler: @escaping (Result<ALTProvisioningProfile, Error>) -> Void)
    {
        ALTAppleAPI.shared.fetchProvisioningProfile(for: appID, team: team, session: session) { (profile, error) in
            completionHandler(Result(profile, error))
        }
    }
    
    func install(_ application: ALTApplication, to device: ALTDevice, team: ALTTeam, appID: ALTAppID, certificate: ALTCertificate, profile: ALTProvisioningProfile, progress: Progress, completionHandler: @escaping (Result<Void, Error>) -> Void)
    {
        DispatchQueue.global().async {
			let resigner = ALTSigner(team: team, certificate: certificate)
			resigner.signApp(at: application.fileURL, provisioningProfiles: [profile]) { (success, error) in
				do
				{
					try Result(success, error).get()
					
					ALTDeviceManager.shared.installApp(at: application.fileURL, toDeviceWithUDID: device.identifier, progress: progress) { (success, error) in
						completionHandler(Result(success, error))
					}
				}
				catch
				{
					completionHandler(.failure(error))
				}
			}
        }
    }
}

private var securityCodeAlertKey = 0
private var securityCodeTextFieldKey = 0

extension ALTDeviceManager: NSTextFieldDelegate
{
    var securityCodeAlert: NSAlert? {
        get { return objc_getAssociatedObject(self, &securityCodeAlertKey) as? NSAlert }
        set { objc_setAssociatedObject(self, &securityCodeAlertKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
    
    var securityCodeTextField: NSTextField? {
        get { return objc_getAssociatedObject(self, &securityCodeTextFieldKey) as? NSTextField }
        set { objc_setAssociatedObject(self, &securityCodeTextFieldKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
    
    public override func controlTextDidChange(_ obj: Notification)
    {
        self.validate()
    }
    
    public override func controlTextDidEndEditing(_ obj: Notification)
    {
        self.validate()
    }
    
    private func validate()
    {
        guard let code = self.securityCodeTextField?.stringValue.trimmingCharacters(in: .whitespacesAndNewlines) else { return }
        
        if code.count == 6
        {
            self.securityCodeAlert?.buttons.first?.isEnabled = true
        }
        else
        {
            self.securityCodeAlert?.buttons.first?.isEnabled = false
        }
        
        self.securityCodeAlert?.layout()
    }
}
