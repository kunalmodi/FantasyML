import Foundation

import CSV
import SwiftSoup

class Fetcher {
    private typealias `Self` = Fetcher

    struct pfr_column {
        let columnNum: Int
        let name: String
        let def: String?
    }

    let PFR_URL = "https://www.pro-football-reference.com/play-index/pgl_finder.cgi?request=1&match=game&year_min={year}&year_max={year}&season_start=1&season_end=-1&pos=0&career_game_num_min=1&career_game_num_max=400&game_num_min=0&game_num_max=99&week_num_min={week}&week_num_max={week}&c1stat=pass_att&c1comp=gt&c5val=1.0&order_by=fantasy_points_ppr&offset={offset}"
    static let PFR_COLUMNS = [
        pfr_column(columnNum: 1, name: "Name", def: nil),
        pfr_column(columnNum: 2, name: "Age", def: nil),
        pfr_column(columnNum: 3, name: "Date", def: nil),
        pfr_column(columnNum: 5, name: "Team", def: nil),
        pfr_column(columnNum: 6, name: "At", def: nil),
        pfr_column(columnNum: 7, name: "Opp", def: nil),
        pfr_column(columnNum: 8, name: "Result", def: nil),
        pfr_column(columnNum: 9, name: "Game Number", def: nil),
        pfr_column(columnNum: 10, name: "Week", def: nil),
        pfr_column(columnNum: 11, name: "Day", def: nil),
        pfr_column(columnNum: 12, name: "Passing Cmp", def: "0"),
        pfr_column(columnNum: 13, name: "Passing Att", def: "0"),
        pfr_column(columnNum: 14, name: "Passing Completion Percentage", def: "0"),
        pfr_column(columnNum: 15, name: "Passing Yards", def: "0"),
        pfr_column(columnNum: 16, name: "Passing TD", def: "0"),
        pfr_column(columnNum: 17, name: "Passing Int", def: "0"),
        pfr_column(columnNum: 19, name: "Passing Sack", def: "0"),
        pfr_column(columnNum: 24, name: "Fantasy Points", def: "0"),
        pfr_column(columnNum: 27, name: "Rushing Att", def: "0"),
        pfr_column(columnNum: 28, name: "Rushing Yards", def: "0"),
        pfr_column(columnNum: 29, name: "Rushing TD", def: "0"),
        pfr_column(columnNum: 30, name: "Recv Rec", def: "0"),
        pfr_column(columnNum: 31, name: "Recv Yards", def: "0"),
        pfr_column(columnNum: 32, name: "Recv TD", def: "0"),
        pfr_column(columnNum: 33, name: "Fumb", def: "0"),
        pfr_column(columnNum: 36, name: "Extra Points", def: "0"),
        pfr_column(columnNum: 37, name: "Extra Points Att", def: "0"),
    ]

    let year: String
    let week: String
    
    init(year: String, week: String) {
        self.year = year
        self.week = week
    }
    
    func fetch() throws {
        print("Fetching \(self.year) \(self.week)")

        var rows = [[String]]()
        for offset in [0, 100, 200, 300, 400] {
            try fetchWithOffset(rows: &rows, offset: offset)
        }

        writeCSV(rows: rows)
    }

    private func writeCSV(rows: [[String]]) {
        var week = self.week
        if week.count == 1 {
            week = "0" + week
        }
        let fileName = "data/player_stats_\(self.year)_\(week).csv"
        let stream = OutputStream(toFileAtPath: fileName, append: false)!
        let csv = try! CSVWriter(stream: stream)

        let headerRow = Self.PFR_COLUMNS.map { (c: Fetcher.pfr_column) -> String in
            return c.name
        }
        try! csv.write(row: headerRow)
        for row in rows {
            try! csv.write(row: row)
        }

        csv.stream.close()
    }

    private func fetchWithOffset(rows: inout [[String]], offset: Int) throws {
        let doc = try fetchPFR(offset: offset)
        let statsTable = try doc.select("table.stats_table").first()!
        let statsRows = try statsTable.select("tbody").first()!.children()
        for row in statsRows {
            let columns = try! row.select("th,td")

            if try columns.get(0).text() == "Rk" {
                continue
            }

            var columnsToKeep = [String]()
            for c in Self.PFR_COLUMNS {
                var val = try columns.get(c.columnNum).text()
                if val == "" && c.def != nil {
                    val = c.def!
                }
                columnsToKeep.append(val)
            }
            rows.append(columnsToKeep)
        }
    }

    private func fetchPFR(offset: Int) throws -> Document {
        let pfr_url = PFR_URL
            .replacingOccurrences(of: "{year}", with: self.year)
            .replacingOccurrences(of: "{week}", with: self.week)
            .replacingOccurrences(of: "{offset}", with: String(offset))
        let url = URL(string: pfr_url)
        let html = try String(contentsOf: url!)

        return try SwiftSoup.parse(html)
    }
}
