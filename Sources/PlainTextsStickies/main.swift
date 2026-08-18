import AppKit

private let appName = "plain texts stickies"
private let defaultsKey = "plain-texts-stickies.notes.v1"
private let defaultFontSize = NSFont.systemFontSize
private let minFontSize: CGFloat = 9
private let maxFontSize: CGFloat = 48

struct NoteState: Codable {
    var id: UUID
    var text: String
    var x: CGFloat
    var y: CGFloat
    var width: CGFloat
    var height: CGFloat
    var fontSize: CGFloat?
}

final class PlainTextView: NSTextView {
    var onChange: ((String) -> Void)?
    var onFontSizeChange: ((CGFloat) -> Void)?

    override var acceptsFirstResponder: Bool {
        true
    }

    override func paste(_ sender: Any?) {
        guard let text = plainText(from: NSPasteboard.general) else { return }
        insertText(text, replacementRange: selectedRange())
        onChange?(string)
    }

    override func keyDown(with event: NSEvent) {
        if event.modifierFlags.intersection(.deviceIndependentFlagsMask).contains(.command),
           let key = event.charactersIgnoringModifiers {
            if key == "+" || key == "=" {
                increaseFontSize(nil)
                return
            }
            if key == "-" {
                decreaseFontSize(nil)
                return
            }
        }
        super.keyDown(with: event)
    }

    @objc func increaseFontSize(_ sender: Any?) {
        changeFontSize(by: 1)
    }

    @objc func decreaseFontSize(_ sender: Any?) {
        changeFontSize(by: -1)
    }

    func applyFontSize(_ size: CGFloat) {
        let clamped = min(max(size, minFontSize), maxFontSize)
        let systemFont = NSFont.systemFont(ofSize: clamped)
        font = systemFont
        typingAttributes[.font] = systemFont
        textStorage?.addAttribute(.font, value: systemFont, range: NSRange(location: 0, length: string.utf16.count))
    }

    override func concludeDragOperation(_ sender: NSDraggingInfo?) {
        if let pasteboard = sender?.draggingPasteboard, let text = plainText(from: pasteboard) {
            insertText(text, replacementRange: selectedRange())
            onChange?(string)
            return
        }
        super.concludeDragOperation(sender)
    }

    private func plainText(from pasteboard: NSPasteboard) -> String? {
        if let text = pasteboard.string(forType: .string) {
            return text
        }

        if let data = pasteboard.data(forType: .rtf),
           let attributed = NSAttributedString(rtf: data, documentAttributes: nil) {
            return attributed.string
        }

        if let data = pasteboard.data(forType: .html),
           let attributed = NSAttributedString(html: data, documentAttributes: nil) {
            return attributed.string
        }

        return nil
    }

    private func changeFontSize(by delta: CGFloat) {
        let nextSize = min(max((font?.pointSize ?? defaultFontSize) + delta, minFontSize), maxFontSize)
        applyFontSize(nextSize)
        onFontSizeChange?(nextSize)
    }
}

final class NoteWindow: NSWindow, NSWindowDelegate {
    let id: UUID
    private let textView: PlainTextView
    private let onUpdate: (UUID, String, NSRect, CGFloat) -> Void
    private let onClose: (UUID) -> Void

    init(state: NoteState, onUpdate: @escaping (UUID, String, NSRect, CGFloat) -> Void, onClose: @escaping (UUID) -> Void) {
        self.id = state.id
        self.onUpdate = onUpdate
        self.onClose = onClose
        self.textView = PlainTextView()

        let rect = NSRect(x: state.x, y: state.y, width: state.width, height: state.height)
        super.init(
            contentRect: rect,
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        title = ""
        minSize = NSSize(width: 220, height: 160)
        isOpaque = false
        backgroundColor = .clear
        titlebarAppearsTransparent = true
        titleVisibility = .hidden
        isMovableByWindowBackground = true
        isReleasedWhenClosed = false
        collectionBehavior = [.managed, .participatesInCycle]
        delegate = self

        let glassView = NSVisualEffectView()
        glassView.frame = contentView?.bounds ?? rect
        glassView.autoresizingMask = [.width, .height]
        glassView.blendingMode = .behindWindow
        glassView.material = .sidebar
        glassView.state = .active

        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.autoresizingMask = [.width, .height]
        scrollView.frame = glassView.bounds
        scrollView.contentView.drawsBackground = false

        textView.string = state.text
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        textView.isRichText = false
        textView.importsGraphics = false
        textView.allowsUndo = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.textContainerInset = NSSize(width: 14, height: 18)
        textView.applyFontSize(state.fontSize ?? defaultFontSize)
        textView.textColor = NSColor(calibratedWhite: 0.11, alpha: 1)
        textView.autoresizingMask = [.width, .height]
        textView.onChange = { [weak self] text in
            guard let self else { return }
            self.onUpdate(self.id, text, self.frame, self.textView.font?.pointSize ?? defaultFontSize)
        }
        textView.onFontSizeChange = { [weak self] fontSize in
            guard let self else { return }
            self.onUpdate(self.id, self.textView.string, self.frame, fontSize)
        }

        scrollView.documentView = textView
        glassView.addSubview(scrollView)
        contentView = glassView

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(textDidChange),
            name: NSText.didChangeNotification,
            object: textView
        )
    }

    @objc private func textDidChange() {
        onUpdate(id, textView.string, frame, textView.font?.pointSize ?? defaultFontSize)
    }

    func windowDidMove(_ notification: Notification) {
        onUpdate(id, textView.string, frame, textView.font?.pointSize ?? defaultFontSize)
    }

    func windowDidResize(_ notification: Notification) {
        onUpdate(id, textView.string, frame, textView.font?.pointSize ?? defaultFontSize)
    }

    func windowWillClose(_ notification: Notification) {
        delegate = nil
        NotificationCenter.default.removeObserver(self)
        onClose(id)
    }

    func focusText() {
        makeKeyAndOrderFront(nil)
        makeFirstResponder(textView)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var states: [NoteState] = []
    private var windows: [UUID: NoteWindow] = [:]
    private var isTerminating = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.mainMenu = makeMenu()
        states = loadStates()

        if states.isEmpty {
            states = [newState()]
        }

        for state in states {
            _ = openWindow(state)
        }
        showNotes()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        isTerminating = true
        return .terminateNow
    }

    func applicationWillTerminate(_ notification: Notification) {
        isTerminating = true
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        newNote()
        return true
    }

    @objc private func newNote() {
        let state = newState(offset: CGFloat(states.count * 24))
        states.append(state)
        saveStates()
        openWindow(state).focusText()
    }

    @objc private func deleteNote() {
        guard let window = NSApp.keyWindow as? NoteWindow else { return }
        removeNote(window.id)
    }

    private func openWindow(_ state: NoteState) -> NoteWindow {
        if let window = windows[state.id] {
            window.focusText()
            return window
        }

        let window = NoteWindow(
            state: state,
            onUpdate: { [weak self] id, text, frame, fontSize in
                self?.updateState(id: id, text: text, frame: frame, fontSize: fontSize)
            },
            onClose: { [weak self] id in
                self?.handleWindowClose(id)
            }
        )
        windows[state.id] = window
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        return window
    }

    private func showNotes() {
        if windows.isEmpty {
            newNote()
            return
        }

        NSApp.activate(ignoringOtherApps: true)
        windows.values.forEach { $0.makeKeyAndOrderFront(nil) }
    }

    private func updateState(id: UUID, text: String, frame: NSRect, fontSize: CGFloat) {
        guard let index = states.firstIndex(where: { $0.id == id }) else { return }
        states[index].text = text
        states[index].x = frame.origin.x
        states[index].y = frame.origin.y
        states[index].width = frame.width
        states[index].height = frame.height
        states[index].fontSize = fontSize
        saveStates()
    }

    private func removeNote(_ id: UUID) {
        windows[id]?.close()
    }

    private func handleWindowClose(_ id: UUID) {
        DispatchQueue.main.async { [weak self] in
            self?.windows[id] = nil
        }
        guard !isTerminating else { return }

        states.removeAll { $0.id == id }
        saveStates()
    }

    private func newState(offset: CGFloat = 0) -> NoteState {
        let screen = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1200, height: 800)
        return NoteState(
            id: UUID(),
            text: "",
            x: screen.minX + 70 + offset,
            y: screen.maxY - 340 - offset,
            width: 330,
            height: 260,
            fontSize: defaultFontSize
        )
    }

    private func loadStates() -> [NoteState] {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey) else { return [] }
        return (try? JSONDecoder().decode([NoteState].self, from: data)) ?? []
    }

    private func saveStates() {
        guard let data = try? JSONEncoder().encode(states) else { return }
        UserDefaults.standard.set(data, forKey: defaultsKey)
    }

    private func makeMenu() -> NSMenu {
        let main = NSMenu()
        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(NSMenuItem(title: "Quit \(appName)", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        appMenuItem.submenu = appMenu
        main.addItem(appMenuItem)

        let fileMenuItem = NSMenuItem()
        let fileMenu = NSMenu(title: "File")
        fileMenu.addItem(NSMenuItem(title: "New Note", action: #selector(newNote), keyEquivalent: "n"))
        fileMenu.addItem(NSMenuItem(title: "Delete Note", action: #selector(deleteNote), keyEquivalent: "\u{8}"))
        fileMenuItem.submenu = fileMenu
        main.addItem(fileMenuItem)

        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(NSMenuItem(title: "Undo", action: Selector(("undo:")), keyEquivalent: "z"))
        editMenu.addItem(NSMenuItem(title: "Redo", action: Selector(("redo:")), keyEquivalent: "Z"))
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(NSMenuItem(title: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x"))
        editMenu.addItem(NSMenuItem(title: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c"))
        editMenu.addItem(NSMenuItem(title: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v"))
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(NSMenuItem(title: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"))
        editMenuItem.submenu = editMenu
        main.addItem(editMenuItem)

        let formatMenuItem = NSMenuItem()
        let formatMenu = NSMenu(title: "Format")
        formatMenu.addItem(NSMenuItem(title: "Bigger", action: #selector(PlainTextView.increaseFontSize(_:)), keyEquivalent: "+"))
        formatMenu.addItem(NSMenuItem(title: "Smaller", action: #selector(PlainTextView.decreaseFontSize(_:)), keyEquivalent: "-"))
        formatMenuItem.submenu = formatMenu
        main.addItem(formatMenuItem)
        return main
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
