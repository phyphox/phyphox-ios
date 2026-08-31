//
//  XlsxWriter.swift
//  phyphox
//
//  Created by Sebastian Staacks on 08.08.26.
//  Copyright © 2026 RWTH Aachen. All rights reserved.
//

import Foundation
import ZIPFoundation

//Minimal writer for the xlsx format (Office Open XML spreadsheet, ECMA-376), which allows us to
//export to Excel without an external library, mirroring the Android implementation
//(helper/XlsxWriter.java) so both platforms produce the same file layout.
//An xlsx file is a zip archive containing a few XML files: a content type declaration
//([Content_Types].xml), relationship files pointing to the actual content (*.rels), a workbook
//definition listing the sheets (xl/workbook.xml), a style definition (xl/styles.xml, here only
//used to provide a bold font for header cells) and one XML file per worksheet
//(xl/worksheets/sheetN.xml).
//Intentional limitations to keep this minimal: strings are stored inline instead of using a
//shared string table, the optional cell and row references (r attributes) are omitted (cells
//simply fill each row from left to right), and there are no number formats or styles beyond the
//bold header font.
final class XlsxWriter {
    private let archive: Archive
    private var sheetNames: [String] = []
    private var usedSheetNames: Set<String> = [] //lower case, Excel treats sheet names as case-insensitive
    private var sheetData = ""
    private var sheetOpen = false

    init(url: URL) throws {
        archive = try Archive(url: url, accessMode: .create)

        //The package relationship file is static and can be written right away. Everything else
        //depends on the number of sheets and is written in close().
        try addEntry("_rels/.rels",
                "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>" +
                "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\">" +
                "<Relationship Id=\"rId1\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument\" Target=\"xl/workbook.xml\"/>" +
                "</Relationships>")
    }

    private func addEntry(_ path: String, _ content: String) throws {
        let data = Data(content.utf8)
        try archive.addEntry(with: path, type: .file, uncompressedSize: Int64(data.count), compressionMethod: .deflate, provider: { position, size in
            let start = Int(position)
            return data.subdata(in: start..<(start + size))
        })
    }

    func startSheet(_ name: String) throws {
        if sheetOpen {
            try endSheet()
        }
        sheetNames.append(uniqueSheetName(name))
        sheetData = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>" +
                "<worksheet xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\">" +
                "<sheetData>"
        sheetOpen = true
    }

    func endSheet() throws {
        sheetData += "</sheetData></worksheet>"
        try addEntry("xl/worksheets/sheet\(sheetNames.count).xml", sheetData)
        sheetData = ""
        sheetOpen = false
    }

    func startRow() {
        sheetData += "<row>"
    }

    func endRow() {
        sheetData += "</row>"
    }

    func stringCell(_ value: String, bold: Bool = false) {
        sheetData += "<c t=\"inlineStr\"\(bold ? " s=\"1\"" : "")><is><t xml:space=\"preserve\">\(XlsxWriter.escape(value))</t></is></c>"
    }

    func numberCell(_ value: Double) {
        guard value.isFinite else {
            //NaN and infinity are not valid numbers in xlsx, store them as text
            stringCell(value.isNaN ? "NaN" : (value > 0 ? "Infinity" : "-Infinity"))
            return
        }
        sheetData += "<c><v>\(value)</v></c>"
    }

    //Writes the workbook metadata derived from the collected sheet names and completes the file
    func close() throws {
        if sheetOpen {
            try endSheet()
        }

        var contentTypes = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>" +
                "<Types xmlns=\"http://schemas.openxmlformats.org/package/2006/content-types\">" +
                "<Default Extension=\"rels\" ContentType=\"application/vnd.openxmlformats-package.relationships+xml\"/>" +
                "<Default Extension=\"xml\" ContentType=\"application/xml\"/>" +
                "<Override PartName=\"/xl/workbook.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml\"/>"
        for i in 0..<sheetNames.count {
            contentTypes += "<Override PartName=\"/xl/worksheets/sheet\(i+1).xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml\"/>"
        }
        contentTypes += "<Override PartName=\"/xl/styles.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml\"/>" +
                "</Types>"
        try addEntry("[Content_Types].xml", contentTypes)

        var workbook = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>" +
                "<workbook xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\" xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\">" +
                "<sheets>"
        for (i, name) in sheetNames.enumerated() {
            workbook += "<sheet name=\"\(XlsxWriter.escape(name))\" sheetId=\"\(i+1)\" r:id=\"rId\(i+1)\"/>"
        }
        workbook += "</sheets></workbook>"
        try addEntry("xl/workbook.xml", workbook)

        var workbookRels = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>" +
                "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\">"
        for i in 0..<sheetNames.count {
            workbookRels += "<Relationship Id=\"rId\(i+1)\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet\" Target=\"worksheets/sheet\(i+1).xml\"/>"
        }
        workbookRels += "<Relationship Id=\"rId\(sheetNames.count + 1)\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles\" Target=\"styles.xml\"/>" +
                "</Relationships>"
        try addEntry("xl/_rels/workbook.xml.rels", workbookRels)

        //Font 0 is the default font, font 1 is bold. Cell style (cellXfs) 0 is the default, 1
        //uses the bold font and is referenced by bold cells as s="1". The empty fills, border
        //and cellStyleXfs entries are the minimum Excel expects to find in a style sheet.
        try addEntry("xl/styles.xml",
                "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>" +
                "<styleSheet xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\">" +
                "<fonts count=\"2\">" +
                "<font><sz val=\"11\"/><name val=\"Calibri\"/></font>" +
                "<font><b/><sz val=\"11\"/><name val=\"Calibri\"/></font>" +
                "</fonts>" +
                "<fills count=\"2\"><fill><patternFill patternType=\"none\"/></fill><fill><patternFill patternType=\"gray125\"/></fill></fills>" +
                "<borders count=\"1\"><border><left/><right/><top/><bottom/><diagonal/></border></borders>" +
                "<cellStyleXfs count=\"1\"><xf numFmtId=\"0\" fontId=\"0\" fillId=\"0\" borderId=\"0\"/></cellStyleXfs>" +
                "<cellXfs count=\"2\">" +
                "<xf numFmtId=\"0\" fontId=\"0\" fillId=\"0\" borderId=\"0\" xfId=\"0\"/>" +
                "<xf numFmtId=\"0\" fontId=\"1\" fillId=\"0\" borderId=\"0\" xfId=\"0\" applyFont=\"1\"/>" +
                "</cellXfs>" +
                "<cellStyles count=\"1\"><cellStyle name=\"Normal\" xfId=\"0\" builtinId=\"0\"/></cellStyles>" +
                "</styleSheet>")
    }

    //Escape reserved XML characters and remove control characters that may not occur in XML 1.0
    private static func escape(_ s: String) -> String {
        return s.replacingOccurrences(of: "[\\x00-\\x08\\x0B\\x0C\\x0E-\\x1F]", with: "", options: .regularExpression)
                .replacingOccurrences(of: "&", with: "&amp;")
                .replacingOccurrences(of: "<", with: "&lt;")
                .replacingOccurrences(of: ">", with: "&gt;")
                .replacingOccurrences(of: "\"", with: "&quot;")
    }

    //Excel imposes restrictions on sheet names: Certain characters are forbidden, at most 31
    //characters, not empty, no duplicates (case-insensitive) and no apostrophe at either end
    private func uniqueSheetName(_ name: String) -> String {
        var s = name.replacingOccurrences(of: "[\\[\\]:*?/\\\\\\x00-\\x1F]", with: " ", options: .regularExpression).trimmingCharacters(in: .whitespaces)
        while s.hasPrefix("'") {
            s.removeFirst()
        }
        while s.hasSuffix("'") {
            s.removeLast()
        }
        s = s.trimmingCharacters(in: .whitespaces)
        if s.isEmpty {
            s = "Sheet"
        }
        if s.count > 31 {
            s = String(s.prefix(31)).trimmingCharacters(in: .whitespaces)
        }
        let base = s
        var i = 2
        while usedSheetNames.contains(s.lowercased()) {
            let suffix = " (\(i))"
            s = String(base.prefix(max(0, 31 - suffix.count))) + suffix
            i += 1
        }
        usedSheetNames.insert(s.lowercased())
        return s
    }
}
