#!/usr/bin/swift

import Foundation

@discardableResult func shell(_ args: String...) -> (Int32, String) {
    let process = Process()
    process.launchPath = "/usr/bin/env"
    process.arguments = args
    
    let pipe = Pipe()
    process.standardOutput = pipe
    
    process.launch()
    process.waitUntilExit()
    
    
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    let output: String = String(data: data, encoding: .utf8)!
    
    return (process.terminationStatus, output)
}
func writeToFile(text: String, filename: String) {
    let fileName = "_posts/\(filename).md" //this is the file. we will write to and read from it
    shell("touch", fileName)
    let fileUrl = URL(fileURLWithPath: fileName)
    //writing
    do {
        try text.write(to: fileUrl, atomically: false, encoding: .utf8)
    } catch {
        print(error.localizedDescription)
    }
}


print("请输入title")
if let title = readLine(strippingNewline: true), title != "" {
    print("请输入tag")
    let tag = readLine(strippingNewline: true)
    print("请输入category")
    let category = readLine(strippingNewline: true)
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    let dateString = formatter.string(from: Date())
    let string = """
    ---
    layout: post
    title: \(title)
    date: \(dateString)
    tags: \(tag ?? "")
    category: \(category ?? "")
    ---
    """
    writeToFile(text:string, filename:"\(dateString)-\(title)")
} else {
    print("title不能为空")
}


