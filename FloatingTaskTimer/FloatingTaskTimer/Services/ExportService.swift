import Foundation
import OSLog

nonisolated struct HistoryExportSnapshot: Sendable {
    let groups: [HistoryExportGroupSnapshot]

    var sessionCount: Int { groups.reduce(0) { $0 + $1.sessions.count } }
}

nonisolated struct HistoryExportGroupSnapshot: Sendable {
    let taskGroupID: UUID
    let name: String
    let lastActivityAt: Date?
    let totalActiveDuration: TimeInterval
    let totalPausedDuration: TimeInterval
    let sessions: [HistoryExportSessionSnapshot]
}

nonisolated struct HistoryExportSessionSnapshot: Sendable {
    let taskGroupID: UUID
    let sessionID: UUID
    let continuedFromSessionID: UUID?
    let name: String
    let firstStartedAt: Date?
    let completedAt: Date?
    let activeDuration: TimeInterval
    let pausedDuration: TimeInterval
}

nonisolated struct ExportService: Sendable {
    private static let logger = Logger(
        subsystem: "whywhy.FloatingTaskTimer",
        category: "HistoryExport"
    )

    enum ExportError: LocalizedError {
        case noSelection
        case archiveTooLarge

        var errorDescription: String? {
            switch self {
            case .noSelection:
                "Select at least one History record to export."
            case .archiveTooLarge:
                "The selected History records are too large to export."
            }
        }
    }

    func exportXLSX(snapshot: HistoryExportSnapshot, to url: URL, startedAt: TimeInterval) throws {
        Self.logger.notice("FTT_EXPORT_REG_07 background export started elapsed_ms=\(Self.elapsedMS(since: startedAt))")
        let data = try makeXLSX(snapshot: snapshot)
        Self.logger.notice("FTT_EXPORT_REG_08 workbook generation finished bytes=\(data.count) elapsed_ms=\(Self.elapsedMS(since: startedAt))")
        try data.write(to: url, options: .atomic)
        Self.logger.notice("FTT_EXPORT_REG_09 file write finished elapsed_ms=\(Self.elapsedMS(since: startedAt))")
    }

    func makeXLSX(snapshot: HistoryExportSnapshot) throws -> Data {
        guard !snapshot.groups.isEmpty else { throw ExportError.noSelection }

        let tasksWorksheet = tasksWorksheetXML(groups: snapshot.groups)
        let sessions = snapshot.groups.flatMap(\.sessions)
        let sessionsWorksheet = sessionsWorksheetXML(sessions: sessions)
        let entries = [
            ZIPEntry(name: "[Content_Types].xml", contents: contentTypesXML),
            ZIPEntry(name: "_rels/.rels", contents: rootRelationshipsXML),
            ZIPEntry(name: "xl/workbook.xml", contents: workbookXML),
            ZIPEntry(name: "xl/_rels/workbook.xml.rels", contents: workbookRelationshipsXML),
            ZIPEntry(name: "xl/styles.xml", contents: stylesXML),
            ZIPEntry(name: "xl/worksheets/sheet1.xml", contents: tasksWorksheet),
            ZIPEntry(name: "xl/worksheets/sheet2.xml", contents: sessionsWorksheet),
        ]
        return try ZIPArchive.make(entries: entries)
    }

    private func tasksWorksheetXML(groups: [HistoryExportGroupSnapshot]) -> String {
        let headers = ["Task Name", "Last Activity Date", "Total Active Duration",
                       "Total Paused Duration", "Session Count", "Task Group ID"]
        let widths = [30, 20, 22, 22, 15, 38]
        let values = groups.map { group in
            [group.name, formattedDate(group.lastActivityAt),
             DurationFormatter.clock(group.totalActiveDuration),
             DurationFormatter.clock(group.totalPausedDuration), "\(group.sessions.count)",
             group.taskGroupID.uuidString]
        }
        return worksheetXML(headers: headers, values: values, widths: widths)
    }

    private func sessionsWorksheetXML(sessions: [HistoryExportSessionSnapshot]) -> String {
        let headers = [
            "Task Name", "Task Group ID", "Session ID", "Continued From Session ID",
            "Date", "Start Time", "End Time", "Active Duration", "Paused Duration",
        ]
        let widths = [30, 38, 38, 38, 14, 22, 22, 18, 18]
        let values = sessions.map { session in
            [session.name, session.taskGroupID.uuidString, session.sessionID.uuidString,
             session.continuedFromSessionID?.uuidString ?? "", formattedDate(session.completedAt),
             formattedDateTime(session.firstStartedAt), formattedDateTime(session.completedAt),
             DurationFormatter.clock(session.activeDuration),
             DurationFormatter.clock(session.pausedDuration)]
        }
        return worksheetXML(headers: headers, values: values, widths: widths)
    }

    private func worksheetXML(headers: [String], values: [[String]], widths: [Int]) -> String {
        var rows = [rowXML(values: headers, row: 1, style: 1)]
        rows += values.enumerated().map { rowXML(values: $0.element, row: $0.offset + 2, style: 0) }

        let columns = widths.enumerated().map { index, width in
            "<col min=\"\(index + 1)\" max=\"\(index + 1)\" width=\"\(width)\" customWidth=\"1\"/>"
        }.joined()

        return """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
          <cols>\(columns)</cols>
          <sheetData>\(rows.joined())</sheetData>
          <autoFilter ref="A1:\(columnName(headers.count))\(values.count + 1)"/>
        </worksheet>
        """
    }

    private func rowXML(values: [String], row: Int, style: Int) -> String {
        let cells = values.enumerated().map { index, value in
            let reference = "\(columnName(index + 1))\(row)"
            return "<c r=\"\(reference)\" t=\"inlineStr\" s=\"\(style)\"><is><t xml:space=\"preserve\">\(xmlEscaped(value))</t></is></c>"
        }.joined()
        return "<row r=\"\(row)\">\(cells)</row>"
    }

    private func columnName(_ number: Int) -> String {
        var value = number
        var result = ""
        while value > 0 {
            value -= 1
            result.insert(Character(UnicodeScalar(65 + value % 26)!), at: result.startIndex)
            value /= 26
        }
        return result
    }

    private func formattedDate(_ date: Date?) -> String {
        guard let date else { return "" }
        return date.formatted(date: .abbreviated, time: .omitted)
    }

    private func formattedDateTime(_ date: Date?) -> String {
        guard let date else { return "" }
        return date.formatted(date: .abbreviated, time: .standard)
    }

    private func xmlEscaped(_ value: String) -> String {
        let validXML = String(value.unicodeScalars.filter {
            $0.value == 0x09 || $0.value == 0x0A || $0.value == 0x0D || $0.value >= 0x20
        })
        return validXML
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }

    private static func elapsedMS(since startedAt: TimeInterval) -> Double {
        (ProcessInfo.processInfo.systemUptime - startedAt) * 1_000
    }

    private var contentTypesXML: String { """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
      <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
      <Default Extension="xml" ContentType="application/xml"/>
      <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
      <Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
      <Override PartName="/xl/worksheets/sheet2.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
      <Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>
    </Types>
    """ }

    private var rootRelationshipsXML: String { """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
      <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
    </Relationships>
    """ }

    private var workbookXML: String { """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
      <sheets><sheet name="Tasks" sheetId="1" r:id="rId1"/><sheet name="Sessions" sheetId="2" r:id="rId2"/></sheets>
    </workbook>
    """ }

    private var workbookRelationshipsXML: String { """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
      <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>
      <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet2.xml"/>
      <Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
    </Relationships>
    """ }

    private var stylesXML: String { """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
      <fonts count="2"><font><sz val="11"/><name val="Aptos"/></font><font><b/><sz val="11"/><name val="Aptos"/></font></fonts>
      <fills count="2"><fill><patternFill patternType="none"/></fill><fill><patternFill patternType="gray125"/></fill></fills>
      <borders count="1"><border><left/><right/><top/><bottom/><diagonal/></border></borders>
      <cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>
      <cellXfs count="2"><xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/><xf numFmtId="0" fontId="1" fillId="0" borderId="0" xfId="0" applyFont="1"/></cellXfs>
      <cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles>
    </styleSheet>
    """ }
}

private nonisolated struct ZIPEntry {
    let name: String
    let data: Data

    init(name: String, contents: String) {
        self.name = name
        data = Data(contents.utf8)
    }
}

private nonisolated enum ZIPArchive {
    static func make(entries: [ZIPEntry]) throws -> Data {
        var archive = Data()
        var centralDirectory = Data()

        for entry in entries {
            guard
                let nameData = entry.name.data(using: .utf8),
                nameData.count <= Int(UInt16.max),
                entry.data.count <= Int(UInt32.max),
                archive.count <= Int(UInt32.max)
            else { throw ExportService.ExportError.archiveTooLarge }

            let crc = crc32(entry.data)
            let offset = UInt32(archive.count)
            let size = UInt32(entry.data.count)

            archive.appendLE(UInt32(0x04034B50))
            archive.appendLE(UInt16(20))
            archive.appendLE(UInt16(0x0800))
            archive.appendLE(UInt16(0))
            archive.appendLE(UInt16(0))
            archive.appendLE(UInt16(0))
            archive.appendLE(crc)
            archive.appendLE(size)
            archive.appendLE(size)
            archive.appendLE(UInt16(nameData.count))
            archive.appendLE(UInt16(0))
            archive.append(nameData)
            archive.append(entry.data)

            centralDirectory.appendLE(UInt32(0x02014B50))
            centralDirectory.appendLE(UInt16(20))
            centralDirectory.appendLE(UInt16(20))
            centralDirectory.appendLE(UInt16(0x0800))
            centralDirectory.appendLE(UInt16(0))
            centralDirectory.appendLE(UInt16(0))
            centralDirectory.appendLE(UInt16(0))
            centralDirectory.appendLE(crc)
            centralDirectory.appendLE(size)
            centralDirectory.appendLE(size)
            centralDirectory.appendLE(UInt16(nameData.count))
            centralDirectory.appendLE(UInt16(0))
            centralDirectory.appendLE(UInt16(0))
            centralDirectory.appendLE(UInt16(0))
            centralDirectory.appendLE(UInt16(0))
            centralDirectory.appendLE(UInt32(0))
            centralDirectory.appendLE(offset)
            centralDirectory.append(nameData)
        }

        guard
            entries.count <= Int(UInt16.max),
            centralDirectory.count <= Int(UInt32.max),
            archive.count <= Int(UInt32.max)
        else { throw ExportService.ExportError.archiveTooLarge }

        let centralOffset = UInt32(archive.count)
        archive.append(centralDirectory)
        archive.appendLE(UInt32(0x06054B50))
        archive.appendLE(UInt16(0))
        archive.appendLE(UInt16(0))
        archive.appendLE(UInt16(entries.count))
        archive.appendLE(UInt16(entries.count))
        archive.appendLE(UInt32(centralDirectory.count))
        archive.appendLE(centralOffset)
        archive.appendLE(UInt16(0))
        return archive
    }

    private static func crc32(_ data: Data) -> UInt32 {
        var crc = UInt32.max
        for byte in data {
            crc ^= UInt32(byte)
            for _ in 0..<8 {
                crc = (crc >> 1) ^ (0xEDB88320 & (0 &- (crc & 1)))
            }
        }
        return ~crc
    }
}

private nonisolated extension Data {
    mutating func appendLE<T: FixedWidthInteger>(_ value: T) {
        var littleEndian = value.littleEndian
        Swift.withUnsafeBytes(of: &littleEndian) { append(contentsOf: $0) }
    }
}
