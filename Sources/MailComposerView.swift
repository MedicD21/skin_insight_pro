import SwiftUI
import MessageUI

struct MailComposerView: UIViewControllerRepresentable {
    @Environment(\.dismiss) var dismiss
    let recipient: String
    let subject: String
    let body: String
    let pdfData: Data
    let pdfFileName: String
    var onResult: ((Result<MFMailComposeResult, Error>) -> Void)?

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let composer = MFMailComposeViewController()
        composer.mailComposeDelegate = context.coordinator
        composer.setToRecipients([recipient])
        composer.setSubject(subject)
        composer.setMessageBody(body, isHTML: false)
        composer.addAttachmentData(pdfData, mimeType: "application/pdf", fileName: pdfFileName)
        return composer
    }

    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let parent: MailComposerView

        init(_ parent: MailComposerView) {
            self.parent = parent
        }

        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            if let error = error {
                parent.onResult?(.failure(error))
            } else {
                parent.onResult?(.success(result))
            }
            parent.dismiss()
        }
    }
}

// Helper to check if mail is available
extension MFMailComposeViewController {
    static var isMailAvailable: Bool {
        return canSendMail()
    }
}
