import UIKit
import Foundation
import zlib

@UIApplicationMain
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        let w = UIWindow(frame: UIScreen.main.bounds)
        w.rootViewController = UINavigationController(rootViewController: FileBrowserController())
        w.makeKeyAndVisible()
        window = w
        return true
    }
}

struct FileItem {
    let url: URL
    let directory: Bool
    let size: Int64
    static func list(_ url: URL) -> [FileItem] {
        let keys: [URLResourceKey] = [.isDirectoryKey, .fileSizeKey]
        return ((try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: keys)) ?? []).map {
            let v = try? $0.resourceValues(forKeys: Set(keys))
            return FileItem(url: $0, directory: v?.isDirectory ?? false, size: Int64(v?.fileSize ?? 0))
        }.sorted { $0.directory == $1.directory ? $0.url.lastPathComponent.localizedCaseInsensitiveCompare($1.url.lastPathComponent) == .orderedAscending : $0.directory }
    }
}

final class FileBrowserController: UIViewController, UITableViewDataSource, UITableViewDelegate, UIDocumentPickerDelegate {
    private var leftURL: URL!
    private var rightURL: URL!
    private var leftItems: [FileItem] = []
    private var rightItems: [FileItem] = []
    private let leftTable = UITableView()
    private let rightTable = UITableView()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "MT 管理器"
        view.backgroundColor = .systemBackground
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        leftURL = docs; rightURL = docs
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "导入", style: .plain, target: self, action: #selector(importFiles))
        let stack = UIStackView(arrangedSubviews: [pane(leftTable, tag: 0), pane(rightTable, tag: 1)])
        stack.axis = .horizontal; stack.distribution = .fillEqually; stack.spacing = 1
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            stack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        refresh()
    }

    private func pane(_ table: UITableView, tag: Int) -> UIView {
        let box = UIView()
        let heading = UILabel()
        heading.text = tag == 0 ? "窗口 1" : "窗口 2"
        heading.font = .systemFont(ofSize: 12, weight: .semibold)
        heading.textColor = .secondaryLabel
        heading.tag = 20 + tag
        heading.translatesAutoresizingMaskIntoConstraints = false
        table.tag = tag; table.dataSource = self; table.delegate = self
        table.register(UITableViewCell.self, forCellReuseIdentifier: "file")
        table.rowHeight = 42; table.translatesAutoresizingMaskIntoConstraints = false
        box.addSubview(heading); box.addSubview(table)
        NSLayoutConstraint.activate([
            heading.topAnchor.constraint(equalTo: box.topAnchor, constant: 7),
            heading.leadingAnchor.constraint(equalTo: box.leadingAnchor, constant: 7),
            heading.trailingAnchor.constraint(equalTo: box.trailingAnchor, constant: -7),
            heading.heightAnchor.constraint(equalToConstant: 22),
            table.topAnchor.constraint(equalTo: heading.bottomAnchor),
            table.leadingAnchor.constraint(equalTo: box.leadingAnchor),
            table.trailingAnchor.constraint(equalTo: box.trailingAnchor),
            table.bottomAnchor.constraint(equalTo: box.bottomAnchor)
        ])
        return box
    }

    private func refresh() {
        leftItems = FileItem.list(leftURL); rightItems = FileItem.list(rightURL)
        leftTable.reloadData(); rightTable.reloadData()
        for child in view.subviews {
            guard let stack = child as? UIStackView else { continue }
            for (i, pane) in stack.arrangedSubviews.enumerated() {
                (pane.viewWithTag(20 + i) as? UILabel)?.text = (i == 0 ? leftURL : rightURL).lastPathComponent
            }
        }
    }

    @objc private func importFiles() {
        let picker: UIDocumentPickerViewController
        if #available(iOS 14.0, *) {
            picker = UIDocumentPickerViewController(forOpeningContentTypes: [.item], asCopy: true)
        } else {
            picker = UIDocumentPickerViewController(documentTypes: ["public.data"], in: .import)
        }
        picker.delegate = self; picker.allowsMultipleSelection = true
        present(picker, animated: true)
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        for source in urls {
            let access = source.startAccessingSecurityScopedResource()
            defer { if access { source.stopAccessingSecurityScopedResource() } }
            let dest = rightURL.appendingPathComponent(source.lastPathComponent)
            try? FileManager.default.removeItem(at: dest)
            try? FileManager.default.copyItem(at: source, to: dest)
        }
        refresh()
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        (tableView.tag == 0 ? leftItems : rightItems).count + 1
    }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let c = tableView.dequeueReusableCell(withIdentifier: "file", for: indexPath)
        let items = tableView.tag == 0 ? leftItems : rightItems
        if indexPath.row == 0 { c.textLabel?.text = "⬆︎  .."; c.imageView?.image = nil; return c }
        let item = items[indexPath.row - 1]
        c.textLabel?.text = item.url.lastPathComponent
        c.textLabel?.font = .systemFont(ofSize: 12)
        let icon = item.directory ? "folder.fill" : (item.url.pathExtension.lowercased() == "ipa" ? "app.gift.fill" : "doc")
        c.imageView?.image = UIImage(systemName: icon)
        c.imageView?.tintColor = item.directory ? .systemBlue : .secondaryLabel
        return c
    }
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let pane = tableView.tag
        let current = pane == 0 ? leftURL! : rightURL!
        if indexPath.row == 0 {
            let parent = current.deletingLastPathComponent()
            if current.path != parent.path { if pane == 0 { leftURL = parent } else { rightURL = parent }; refresh() }
            return
        }
        let item = (pane == 0 ? leftItems : rightItems)[indexPath.row - 1]
        if item.directory {
            if pane == 0 { leftURL = item.url } else { rightURL = item.url }
            refresh()
        } else if item.url.pathExtension.lowercased() == "ipa" {
            navigationController?.pushViewController(IPADetailController(url: item.url), animated: true)
        } else if ["txt","json","xml","plist","md","log"].contains(item.url.pathExtension.lowercased()) {
            navigationController?.pushViewController(TextController(url: item.url), animated: true)
        } else {
            let a = UIAlertController(title: item.url.lastPathComponent, message: ByteCountFormatter.string(fromByteCount: item.size, countStyle: .file), preferredStyle: .alert)
            a.addAction(UIAlertAction(title: "好", style: .default)); present(a, animated: true)
        }
    }
}

final class IPADetailController: UITableViewController {
    private let url: URL
    private var values: [(String,String)] = []
    init(url: URL) { self.url = url; super.init(style: .insetGrouped); title = url.lastPathComponent }
    required init?(coder: NSCoder) { fatalError() }
    override func viewDidLoad() {
        super.viewDidLoad()
        values = [("文件",url.lastPathComponent),("格式","iOS App Archive")]
        if let info = IPAInfo.read(url) {
            for key in ["CFBundleDisplayName","CFBundleName","CFBundleIdentifier","CFBundleShortVersionString","CFBundleVersion","MinimumOSVersion","CFBundleExecutable"] {
                if let v = info[key] as? String { values.append((key,v)) }
            }
        } else { values.append(("解析","未能读取 Payload 内的 Info.plist")) }
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "v")
    }
    override func tableView(_ t: UITableView, numberOfRowsInSection s: Int) -> Int { values.count }
    override func tableView(_ t: UITableView, cellForRowAt i: IndexPath) -> UITableViewCell {
        let c = t.dequeueReusableCell(withIdentifier: "v", for: i)
        var v = c.defaultContentConfiguration(); v.text = values[i.row].0; v.secondaryText = values[i.row].1; v.secondaryTextProperties.numberOfLines = 0
        c.contentConfiguration = v; return c
    }
}

enum IPAInfo {
    static func read(_ url: URL) -> [String:Any]? {
        guard let d = try? Data(contentsOf: url, options: .mappedIfSafe), let p = locatePlist(d),
              let obj = try? PropertyListSerialization.propertyList(from: p, options: [], format: nil) as? [String:Any] else { return nil }
        return obj
    }
    private struct Entry { let method: UInt16; let compressed: Int; let size: Int; let offset: Int }
    private static func locatePlist(_ data: Data) -> Data? {
        let b = [UInt8](data); guard b.count > 22 else { return nil }
        func u16(_ i:Int)->UInt16 { guard i+1 < b.count else{return 0}; return UInt16(b[i]) | UInt16(b[i+1]) << 8 }
        func u32(_ i:Int)->UInt32 { guard i+3 < b.count else{return 0}; return UInt32(b[i]) | UInt32(b[i+1]) << 8 | UInt32(b[i+2]) << 16 | UInt32(b[i+3]) << 24 }
        var eocd:Int?; let lower = max(0,b.count-65557)
        if b.count >= 22 { for i in stride(from:b.count-22, through:lower, by:-1) where u32(i) == 0x06054b50 { eocd=i; break } }
        guard let end=eocd else{return nil}
        let count=Int(u16(end+10)); var cur=Int(u32(end+16)); var found:Entry?
        for _ in 0..<count {
            guard cur+46 <= b.count, u32(cur)==0x02014b50 else{return nil}
            let nl=Int(u16(cur+28)), el=Int(u16(cur+30)), cl=Int(u16(cur+32))
            let name=String(bytes:b[(cur+46)..<(cur+46+nl)],encoding:.utf8) ?? ""
            if name.hasPrefix("Payload/"), name.hasSuffix(".app/Info.plist") {
                found=Entry(method:u16(cur+10),compressed:Int(u32(cur+20)),size:Int(u32(cur+24)),offset:Int(u32(cur+42))); break
            }
            cur += 46+nl+el+cl
        }
        guard let e=found, e.offset+30 <= b.count, u32(e.offset)==0x04034b50 else{return nil}
        let start=e.offset+30+Int(u16(e.offset+26))+Int(u16(e.offset+28)), finish=start+e.compressed
        guard finish <= b.count else{return nil}
        let compressed=Data(b[start..<finish])
        if e.method == 0 { return compressed }
        guard e.method == 8 else{return nil}
        var output=Data(count:e.size); var stream=z_stream()
        guard inflateInit2_(&stream,-MAX_WBITS,ZLIB_VERSION,Int32(MemoryLayout<z_stream>.size)) == Z_OK else{return nil}
        let status:Int32=compressed.withUnsafeBytes { input in output.withUnsafeMutableBytes { out in
            stream.next_in=UnsafeMutablePointer<Bytef>(mutating:input.bindMemory(to:Bytef.self).baseAddress!)
            stream.avail_in=uInt(compressed.count); stream.next_out=out.bindMemory(to:Bytef.self).baseAddress!
            stream.avail_out=uInt(output.count); return inflate(&stream,Z_FINISH)
        }}
        inflateEnd(&stream); return status == Z_STREAM_END ? output : nil
    }
}

final class TextController: UIViewController {
    private let url: URL
    init(url: URL) { self.url=url; super.init(nibName:nil,bundle:nil); title=url.lastPathComponent }
    required init?(coder: NSCoder) { fatalError() }
    override func viewDidLoad() {
        super.viewDidLoad(); view.backgroundColor = .systemBackground
        let text=UITextView(); text.font = .monospacedSystemFont(ofSize:13,weight:.regular); text.isEditable=false
        text.text=(try? String(contentsOf:url,encoding:.utf8)) ?? "无法按 UTF-8 文本读取"
        text.translatesAutoresizingMaskIntoConstraints=false; view.addSubview(text)
        NSLayoutConstraint.activate([text.topAnchor.constraint(equalTo:view.safeAreaLayoutGuide.topAnchor),text.bottomAnchor.constraint(equalTo:view.bottomAnchor),text.leadingAnchor.constraint(equalTo:view.leadingAnchor),text.trailingAnchor.constraint(equalTo:view.trailingAnchor)])
    }
}
