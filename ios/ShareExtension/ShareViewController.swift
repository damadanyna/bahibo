import receive_sharing_intent

// Registered as NSExtensionPrincipalClass in Info.plist. shouldAutoRedirect
// = true means the extension hands off to Banay immediately with no
// intermediate compose screen — the "choose a conversation" step happens
// inside the app itself (see ShareTargetPickerPage in Dart).
class ShareViewController: RSIShareViewController {
    override func shouldAutoRedirect() -> Bool {
        return true
    }
}
