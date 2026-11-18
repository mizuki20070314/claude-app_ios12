import UIKit

func showConversationActions(for conversation: Conversation, sourceView: UIView, sourceRect: CGRect, in vc: UIViewController) {
    let sheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
    let isRemote = (conversation.origin == "claudeAi")
    let starTitle = conversation.isStarred ? L("sidebar.unstar", "Sidebar") : L("sidebar.star", "Sidebar")
    sheet.addAction(UIAlertAction(title: starTitle, style: .default) { _ in
        let newStarred = !conversation.isStarred
        if isRemote {
            // optimistic local update
            if var c = ConversationStore.shared.conversation(id: conversation.id) {
                c.isStarred = newStarred
                ConversationStore.shared.save(c, touch: false)
            }
            ClaudeHistoryService.shared.setStarred(id: conversation.id, starred: newStarred) { err in
                DispatchQueue.main.async {
                    if let err = err {
                        // revert
                        if var c = ConversationStore.shared.conversation(id: conversation.id) {
                            c.isStarred = conversation.isStarred
                            ConversationStore.shared.save(c, touch: false)
                        }
                        let alert = UIAlertController(title: L("chat.error", "Chat"), message: err.localizedDescription, preferredStyle: .alert)
                        alert.addAction(UIAlertAction(title: L("common.ok", "Common"), style: .default))
                        vc.present(alert, animated: true)
                    }
                }
            }
        } else {
            ConversationStore.shared.toggleStar(id: conversation.id)
        }
    })
    sheet.addAction(UIAlertAction(title: L("sidebar.rename", "Sidebar"), style: .default) { _ in
        let alert = UIAlertController(title: L("sidebar.rename", "Sidebar"), message: nil, preferredStyle: .alert)
        alert.addTextField { $0.text = conversation.title }
        alert.addAction(UIAlertAction(title: L("common.save", "Common"), style: .default) { _ in
            if let t = alert.textFields?.first?.text, !t.isEmpty {
                if isRemote {
                    ConversationStore.shared.rename(id: conversation.id, title: t)
                    ClaudeHistoryService.shared.rename(id: conversation.id, title: t) { _ in }
                } else {
                    ConversationStore.shared.rename(id: conversation.id, title: t)
                }
            }
        })
        alert.addAction(UIAlertAction(title: L("common.cancel", "Common"), style: .cancel))
        vc.present(alert, animated: true)
    })
    sheet.addAction(UIAlertAction(title: L("sidebar.delete", "Sidebar"), style: .destructive) { _ in
        let confirm = UIAlertController(title: L("sidebar.deleteConfirm", "Sidebar"), message: conversation.title, preferredStyle: .alert)
        confirm.addAction(UIAlertAction(title: L("sidebar.delete", "Sidebar"), style: .destructive) { _ in
            if isRemote {
                ConversationStore.shared.delete(id: conversation.id)
                ClaudeHistoryService.shared.delete(id: conversation.id) { _ in }
            } else {
                ConversationStore.shared.delete(id: conversation.id)
            }
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