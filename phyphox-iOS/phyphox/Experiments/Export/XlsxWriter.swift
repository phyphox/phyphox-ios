//
//  XlsxWriter.swift
//  phyphox
//
//  Created by Sebastian Staacks on 08.08.26.
//  Copyright © 2026 RWTH Aachen. All rights reserved.
//

import Foundation
import ZIPFoundation

//Minimal xlsx (ECMA-376) writer mirroring Android's helper/XlsxWriter.java, so both platforms produce the same layout.
//Kept minimal: inline strings instead of a shared string table, no cell/row r attributes, only a bold header style.
final class XlsxWriter {
    private let archive: Archive
    private var sheetNames: [String] = []
    private var usedSheetNames: Set<String> = [] //lower case, Excel treats sheet names as case-insensitive
    private var sheetData = ""
    private var sheetOpen = false

    init(url: URL) throws {
        archive = try Archive(url: url, accessMode: .create)

        //Static; everything else depends on the number of sheets and is written in close()
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

        //Font 1 is bold, style 1 uses it (s="1"); empty fills, borders and cellStyleXfs are the minimum Excel expects
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
        return s.replacingOccurrences(of: "[\\x00-\\x08\\x0B\\x0C\\x0E-\\x1F]", with: "", options: .regularExpression).xmlEscaped
    }

    //Excel sheet names: no reserved chars, at most 31, not empty, unique case-insensitively, no apostrophe at either end
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
