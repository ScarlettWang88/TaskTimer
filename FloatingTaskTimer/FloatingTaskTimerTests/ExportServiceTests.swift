import Foundation
import Testing
@testable import FloatingTaskTimer

@Suite("History Excel export")
struct ExportServiceTests {
    @Test("Empty selection is rejected")
    func rejectsEmptySelection() {
        #expect(throws: ExportService.ExportError.self) {
            try ExportService().makeXLSX(snapshot: HistoryExportSnapshot(groups: []))
        }
    }

    @Test("Only selected records are included in a valid XLSX package")
    func exportsSelectedRecordsOnly() throws {
        let first = completed(name: "First & Selected", category: "Work")
        let second = completed(name: "Second Selected", category: nil)
        let excluded = completed(name: "Excluded", category: "Private")
        let groups = [HistoryGroup(taskGroupID: first.taskGroupID, sessions: [first]),
                      HistoryGroup(taskGroupID: second.taskGroupID, sessions: [second])]

        let workbook = try ExportService().makeXLSX(snapshot: exportSnapshot(groups))
        let entries = try unzipStoredEntries(workbook)
        let tasksData = try #require(entries["xl/worksheets/sheet1.xml"])
        let sessionsData = try #require(entries["xl/worksheets/sheet2.xml"])
        let tasks = try #require(String(data: tasksData, encoding: .utf8))
        let sessions = try #require(String(data: sessionsData, encoding: .utf8))

        #expect(entries.keys.contains("[Content_Types].xml"))
        #expect(entries.keys.contains("xl/workbook.xml"))
        #expect(entries.keys.contains("xl/styles.xml"))
        #expect(tasks.contains("First &amp; Selected"))
        #expect(tasks.contains("Second Selected"))
        #expect(!tasks.contains("Excluded"))
        #expect(tasks.contains(first.taskGroupID.uuidString))
        #expect(sessions.contains(first.id.uuidString))
        #expect(sessions.contains(second.id.uuidString))
        #expect(!sessions.contains(excluded.id.uuidString))
        #expect(tasks.components(separatedBy: "<row ").count - 1 == 3)
        #expect(sessions.components(separatedBy: "<row ").count - 1 == 3)
    }

    @Test("Multiple rows and missing optional fields export safely")
    func exportsMissingOptionalFields() throws {
        let originID = UUID()
        var continued = completed(name: "Continued", category: nil)
        continued.continuedFromSessionID = originID
        let missing = TaskSession(
            name: "No Start",
            status: .completed,
            createdAt: referenceDate,
            completedAt: referenceDate.addingTimeInterval(60),
            accumulatedActiveDuration: 60
        )

        let entries = try unzipStoredEntries(
            ExportService().makeXLSX(snapshot: exportSnapshot([
                HistoryGroup(taskGroupID: continued.taskGroupID, sessions: [continued]),
                HistoryGroup(taskGroupID: missing.taskGroupID, sessions: [missing]),
            ]))
        )
        let worksheetData = try #require(entries["xl/worksheets/sheet2.xml"])
        let worksheet = try #require(String(data: worksheetData, encoding: .utf8))

        #expect(worksheet.contains(originID.uuidString))
        #expect(worksheet.contains("No Start"))
        #expect(worksheet.contains("Continued From Session ID"))
        #expect(worksheet.components(separatedBy: "<row ").count - 1 == 3)
    }

    @Test("Exported file passes the system ZIP integrity check")
    func exportedArchiveIntegrity() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("xlsx")
        defer { try? FileManager.default.removeItem(at: url) }
        let session = completed(name: "Integrity", category: nil)
        try ExportService().exportXLSX(
            snapshot: exportSnapshot([HistoryGroup(taskGroupID: session.taskGroupID, sessions: [session])]),
            to: url,
            startedAt: ProcessInfo.processInfo.systemUptime
        )

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-t", url.path]
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        try process.run()
        process.waitUntilExit()

        #expect(process.terminationStatus == 0)
    }

    private var referenceDate: Date { Date(timeIntervalSince1970: 1_700_000_000) }

    private func completed(name: String, category: String?) -> TaskSession {
        TaskSession(
            name: name,
            category: category,
            status: .completed,
            createdAt: referenceDate,
            firstStartedAt: referenceDate,
            completedAt: referenceDate.addingTimeInterval(90),
            accumulatedActiveDuration: 80,
            accumulatedPausedDuration: 10
        )
    }

    private func exportSnapshot(_ groups: [HistoryGroup]) -> HistoryExportSnapshot {
        HistoryExportSnapshot(groups: groups.map { group in
            HistoryExportGroupSnapshot(
                taskGroupID: group.taskGroupID,
                name: group.name,
                lastActivityAt: group.lastActivityAt,
                totalActiveDuration: group.totalActiveDuration,
                totalPausedDuration: group.totalPausedDuration,
                sessions: group.sessions.map {
                    HistoryExportSessionSnapshot(
                        taskGroupID: $0.taskGroupID,
                        sessionID: $0.id,
                        continuedFromSessionID: $0.continuedFromSessionID,
                        name: $0.name,
                        firstStartedAt: $0.firstStartedAt,
                        completedAt: $0.completedAt,
                        activeDuration: $0.accumulatedActiveDuration,
                        pausedDuration: $0.accumulatedPausedDuration
                    )
                }
            )
        })
    }

    private func unzipStoredEntries(_ data: Data) throws -> [String: Data] {
        var entries: [String: Data] = [:]
        var offset = 0

        while offset + 30 <= data.count, readUInt32(data, offset) == 0x04034B50 {
            let size = Int(readUInt32(data, offset + 18))
            let nameLength = Int(readUInt16(data, offset + 26))
            let extraLength = Int(readUInt16(data, offset + 28))
            let nameStart = offset + 30
            let contentsStart = nameStart + nameLength + extraLength
            let contentsEnd = contentsStart + size
            guard contentsEnd <= data.count else { throw TestArchiveError.invalidArchive }

            let nameData = data.subdata(in: nameStart..<(nameStart + nameLength))
            guard let name = String(data: nameData, encoding: .utf8) else {
                throw TestArchiveError.invalidArchive
            }
            entries[name] = data.subdata(in: contentsStart..<contentsEnd)
            offset = contentsEnd
        }

        guard !entries.isEmpty else { throw TestArchiveError.invalidArchive }
        return entries
    }

    private func readUInt16(_ data: Data, _ offset: Int) -> UInt16 {
        UInt16(data[offset]) | UInt16(data[offset + 1]) << 8
    }

    private func readUInt32(_ data: Data, _ offset: Int) -> UInt32 {
        UInt32(data[offset])
            | UInt32(data[offset + 1]) << 8
            | UInt32(data[offset + 2]) << 16
            | UInt32(data[offset + 3]) << 24
    }
}

private enum TestArchiveError: Error {
    case invalidArchive
}
