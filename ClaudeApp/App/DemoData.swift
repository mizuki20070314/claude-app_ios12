import UIKit

enum DemoData {
    static let sampleHTML: String = """
    <!DOCTYPE html>
    <html>
    <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Todo</title>
    <style>
    body { font-family: -apple-system, sans-serif; background: #FAF9F5; margin: 0; padding: 16px; }
    h1 { color: #D97757; }
    .todo { display: flex; align-items: center; gap: 8px; padding: 8px; border-bottom: 1px solid #e7e6e1; }
    .todo.done span { text-decoration: line-through; color: #949494; }
    .todo span { flex: 1; text-align: left; }
    .todo input[type="checkbox"] { accent-color: #D97757; }
    button { background: #D97757; color: white; border: none; border-radius: 8px; padding: 8px 12px; }
    #inp { flex: 1; padding: 8px; border: 1px solid #e7e6e1; border-radius: 8px; }
    .del { background: transparent; color: #949494; border: none; border-radius: 6px; padding: 4px 8px; font-size: 16px; }
    </style>
    </head>
    <body>
    <h1>Todo アプリ</h1>
    <div id="list"></div>
    <div style="display:flex; gap:8px; margin-top:12px;">
      <input id="inp" placeholder="新しいタスク">
      <button onclick="add()">追加</button>
    </div>
    <script>
    let todos = [{text:'牛乳を買う', done:false},{text:'コードを書く', done:true}];
    function render(){ const l=document.getElementById('list'); l.innerHTML=''; todos.forEach((t,i)=>{const d=document.createElement('div'); d.className='todo'+(t.done?' done':''); d.innerHTML='<input type="checkbox" '+(t.done?'checked':'')+' onchange="toggle('+i+')"><span>'+t.text+'</span><button class="del" onclick="remove('+i+')">×</button>'; l.appendChild(d);});}
    function add(){ const v=document.getElementById('inp').value.trim(); if(v){todos.push({text:v,done:false}); document.getElementById('inp').value=''; render();}}
    function toggle(i){ todos[i].done=!todos[i].done; render();}
    function remove(i){ todos.splice(i,1); render();}
    render();
    </script>
    </body>
    </html>
    """

    static var conversations: [Conversation] {
        var convs: [Conversation] = []
        let now = Date()

        // demo-chat
        var demo = Conversation(id: "demo-chat", title: "SwiftでFizzBuzzを書いて", createdAt: now.addingTimeInterval(-86400 * 2), updatedAt: now.addingTimeInterval(-86400 * 2), isStarred: true)
        demo.messages.append(Message(role: .user, text: "SwiftでFizzBuzzを書いて", createdAt: now.addingTimeInterval(-86400 * 2)))
        let thinking = "FizzBuzzの実装について考えます。1から100までループし、3と5の倍数を判定します。"
        let answer = """
        # FizzBuzz in Swift

        以下のように実装できます。

        ## ポイント
        - `1...100` の **レンジ** を使う
        - `where` 句で条件分岐

        ```swift
        for i in 1...100 {
            if i % 15 == 0 {
                print("FizzBuzz")
            } else if i % 3 == 0 {
                print("Fizz")
            } else if i % 5 == 0 {
                print("Buzz")
            } else {
                print(i)
            }
        }
        ```

        1. ループを回す
        2. 条件を判定する
        3. 出力する

        > 簡潔に書くこともできます。
        """
        demo.messages.append(Message(role: .assistant, text: answer, thinking: thinking, createdAt: now.addingTimeInterval(-86400 * 2 + 30), model: "claude-sonnet-5-5"))
        // second user with image
        let imgAttachment = makeImageAttachment()
        demo.messages.append(Message(role: .user, text: "この画像について説明して", attachments: [imgAttachment], createdAt: now.addingTimeInterval(-86400 * 2 + 60)))
        demo.messages.append(Message(role: .assistant, text: "青い正方形の画像ですね。特に問題ありません。", createdAt: now.addingTimeInterval(-86400 * 2 + 90), model: "claude-sonnet-5-5"))
        demo.messages.append(Message(role: .assistant, text: "青一色の正方形の画像ですね。シンプルなプレースホルダー画像のようです。", createdAt: now.addingTimeInterval(-86400 * 2 + 120), model: "claude-sonnet-5-5"))
        convs.append(demo)

        // project-linked chat
        var projChat = Conversation(id: "demo-proj-chat", title: "プロジェクトの相談", createdAt: now.addingTimeInterval(-86400 * 5), updatedAt: now.addingTimeInterval(-86400 * 5), isStarred: false, projectId: "demo-project")
        projChat.messages.append(Message(role: .user, text: "iOSアプリの設計について相談したい", createdAt: now.addingTimeInterval(-86400 * 5)))
        projChat.messages.append(Message(role: .assistant, text: "承知しました。どのような点について相談でしょうか？", createdAt: now.addingTimeInterval(-86400 * 5 + 20)))
        convs.append(projChat)

        let titles = [
            "旅行の計画",
            "レシピの提案",
            "コードレビュー",
            "英語の翻訳",
            "数学の問題",
            "日記の下書き"
        ]
        for (i, t) in titles.enumerated() {
            var c = Conversation(id: "demo-\(i)", title: t, createdAt: now.addingTimeInterval(-86400.0 * Double(i + 1)), updatedAt: now.addingTimeInterval(-86400.0 * Double(i + 1)))
            if i == 0 { c.isStarred = true }
            c.messages.append(Message(role: .user, text: "質問: \(t)", createdAt: now.addingTimeInterval(-86400.0 * Double(i + 1))))
            c.messages.append(Message(role: .assistant, text: "回答: \(t)についてお手伝いします。", createdAt: now.addingTimeInterval(-86400.0 * Double(i + 1) + 10)))
            convs.append(c)
        }

        return convs
    }

    static var projects: [Project] {
        var projects: [Project] = []
        let now = Date()
        var p = Project(id: "demo-project", name: "iOS アプリ開発", description: "iOS 12 クライアント開発", instructions: "Swift 5 / UIKit のみ。iOS 12 対応。", createdAt: now.addingTimeInterval(-86400 * 10), updatedAt: now.addingTimeInterval(-86400 * 2))
        p.knowledge.append(Attachment(kind: .textFile, fileName: "spec.md", mediaType: "text/plain", textContent: "# Spec\niOS 12 client"))
        p.knowledge.append(Attachment(kind: .textFile, fileName: "notes.txt", mediaType: "text/plain", textContent: "Notes"))
        p.isStarred = true
        projects.append(p)

        projects.append(Project(id: "demo-project-2", name: "ブログ執筆", description: "技術ブログ", instructions: "", createdAt: now.addingTimeInterval(-86400 * 20), updatedAt: now.addingTimeInterval(-86400 * 8)))
        projects.append(Project(id: "demo-project-3", name: "学習メモ", description: "学習用", instructions: "", createdAt: now.addingTimeInterval(-86400 * 30), updatedAt: now.addingTimeInterval(-86400 * 15)))
        return projects
    }

    static var codeSessions: [CodeSession] {
        let now = Date()
        var sessions: [CodeSession] = []
        sessions.append(CodeSession(id: "demo-code-rc-running", title: "Refactor login flow", status: "active", statusBucket: nil, workerStatus: "running", connectionStatus: "connected", environmentKind: "bridge", origin: nil, model: "claude-sonnet-4", statusLine: "Running tests…", updatedAt: now.addingTimeInterval(-120), lastEventAt: now.addingTimeInterval(-60), unread: false))
        sessions.append(CodeSession(id: "demo-code-rc-idle", title: "Fix CSS bug", status: "active", statusBucket: nil, workerStatus: "idle", connectionStatus: "disconnected", environmentKind: "bridge", origin: nil, model: "claude-sonnet-4", statusLine: nil, updatedAt: now.addingTimeInterval(-3600), lastEventAt: now.addingTimeInterval(-3600), unread: true))
        sessions.append(CodeSession(id: "demo-code-cloud-1", title: "Add unit tests", status: "archived", statusBucket: "completed", workerStatus: "idle", connectionStatus: "disconnected", environmentKind: "cloud", origin: nil, model: "claude-sonnet-4", statusLine: "All tests passed", updatedAt: now.addingTimeInterval(-86400), lastEventAt: now.addingTimeInterval(-86400), unread: false))
        sessions.append(CodeSession(id: "demo-code-cloud-2", title: "Update README", status: "archived", statusBucket: "completed", workerStatus: "idle", connectionStatus: "disconnected", environmentKind: "cloud", origin: nil, model: "claude-sonnet-4", statusLine: "Done", updatedAt: now.addingTimeInterval(-172800), lastEventAt: now.addingTimeInterval(-172800), unread: false))
        return sessions
    }

    static var codeTranscript: [CodeTranscriptItem] {
        let now = Date()
        return [
            .user(text: "List files in src", isSynthetic: false, date: now.addingTimeInterval(-300)),
            .assistant(text: "Here are the files.", date: now.addingTimeInterval(-290)),
            .thinking(text: "Need to inspect directory."),
            .toolUse(id: "t1", name: "Bash", summary: "ls -la src"),
            .toolResult(toolUseId: "t1", text: "file1.ts\nfile2.ts", isError: false),
            .assistant(text: "Found 2 files. Let's read one.", date: now.addingTimeInterval(-280)),
            .toolUse(id: "t2", name: "Read", summary: "src/file1.ts"),
            .toolResult(toolUseId: "t2", text: "console.log('hi')", isError: false),
            .toolUse(id: "t3", name: "Edit", summary: "src/file1.ts"),
            .toolResult(toolUseId: "t3", text: "Permission denied", isError: true),
            .assistant(text: "**Done.**", date: now.addingTimeInterval(-260))
        ]
    }

    private static func makeImageAttachment() -> Attachment {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 64, height: 64))
        let img = renderer.image { ctx in
            UIColor(red: 0.2, green: 0.4, blue: 0.9, alpha: 1).setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 64, height: 64))
        }
        let data = img.jpegData(compressionQuality: 0.8) ?? Data()
        return Attachment(kind: .image, fileName: "photo.jpg", mediaType: "image/jpeg", base64Data: data.base64EncodedString())
    }
}
