import UIKit

func showConversationActions(for conversation: Conversation, sourceView: UIView, sourceRect: CGRect, in vc: UIViewController) {
    let sheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
    let starTitle = conversation.isStarred ? L("sidebar.unstar", "Sidebar") : L("sidebar.star", "Sidebar")
    sheet.addAction(UIAlertAction(title: starTitle, style: .default) { _ in
        ConversationStore.shared.toggleStar(id: conversation.id)
    })
    sheet.addAction(UIAlertAction(title: L("sidebar.rename", "Sidebar"), style: .default) { _ in
        let alert = UIAlertController(title: L("sidebar.rename", "Sidebar"), message: nil, preferredStyle: .alert)
        alert.addTextField { $0.text = conversation.title }
        alert.addAction(UIAlertAction(title: L("common.save", "Common"), style: .default) { _ in
            if let t = alert.textFields?.first?.text, !t.isEmpty {
                ConversationStore.shared.rename(id: conversation.id, title: t)
            }
        })
        alert.addAction(UIAlertAction(title: L("common.cancel", "Common"), style: .cancel))
        vc.present(alert, animated: true)
    })
    sheet.addAction(UIAlertAction(title: L("sidebar.delete", "Sidebar"), style: .destructive) { _ in
        let confirm = UIAlertController(title: L("sidebar.deleteConfirm", "Sidebar"), message: conversation.title, preferredStyle: .alert)
        confirm.addAction(UIAlertAction(title: L("sidebar.delete", "Sidebar"), style: .destructive) { _ in
            ConversationStore.shared.delete(id: conversation.id)
        })
        confirm.addAction(UIAlertAction(title: L("common.cancel", "Common"), style: .cancel))
        vc.present(confirm, animated: true)
    })
    sheet.addAction(UIAlertAction(title: L("common.cancel", "Common"), style: .cancel))
    if let pop = sheet.popoverPresentationController {
        pop.sourceView = sourceView
        pop.sourceRect = sourceRect
    }
    vc.present(sheet, animated: true)
}
