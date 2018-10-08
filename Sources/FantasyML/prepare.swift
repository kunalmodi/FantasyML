import Foundation

import CSV

class Preparer {
    
    struct rolling_window {
        let name: String
        let window: Int
    }
    let ROLLING_WINDOWS = [
        rolling_window(name: "Prev", window: 1),
        rolling_window(name: "Prev4", window: 4),
        rolling_window(name: "Prev8", window: 8),
    ]
    
    class strucutred_row: CustomStringConvertible {
        var row: [String]
        var rowMap: [String: Int]
        var features: [Double]
        var featureMap: [String: Int]
        
        public var description: String { return "strucutred_row: \(row) \(rowMap) \(features) \(featureMap)" }

        init(row: [String], rowMap: [String: Int]) {
            self.row = row
            self.rowMap = rowMap
            self.features = []
            self.featureMap = [String: Int]()
        }

        func get(name: String) -> String {
            return row[rowMap[name]!]
        }
        
        func add(name: String, value: String) {
            let i = row.count
            rowMap[name] = i
            row.append(value)
        }

        func addFeature(name: String, boolValue: Bool) {
            addFeature(name: name, doubleValue: boolValue ? 1.0 : 0.0)
        }
        
        func addFeature(name: String, doubleValue: Double) {
            let i = features.count
            featureMap[name] = i
            features.append(doubleValue)
        }
        
        func getCSVRow() -> [String] {
            let strFeatures = features.map{ String($0) }
            return row + strFeatures
        }
        
        func getCSVHeader() -> [String] {
            var header = [String](repeating: "", count: row.count + features.count)
            for (r, i) in rowMap {
                header[i] = r
            }
            for (r, i) in featureMap {
                header[i + rowMap.count] = "Feat:" + r
            }
            return header
        }
    }
    
    func prepare() throws {
        print("Prepare")
        var allRawData = [strucutred_row]()

        let weeklyFileNames = try getFileNames(prefix: "player_stats_")
        for fileName in weeklyFileNames.sorted() {
            try readCSV(fileName: fileName, eval: { (r: strucutred_row) in
                allRawData.append(r)
            })
        }
                
        try addDerivedData(rows: allRawData)
        addTeam(rows: allRawData)
        addStats(rows: allRawData)

        try writeCSV(rows: allRawData)
    }

    private func addStats(rows: [strucutred_row]) {
        let stats = [
            "Passing Cmp",
            "Passing Att",
            "Passing Yards",
            "Passing TD",
            "Passing Int",
            "Passing Sack",
            "Rushing Att",
            "Rushing Yards",
            "Rushing TD",
            "Recv Rec",
            "Recv Yards",
            "Recv TD",
            "Fumb",
            "Extra Points",
            "Extra Points Att",
        ]
        var byPlayer = [String: [Int: [Int: [String: Int]]]]()
        var byOpp = [String: [Int: [Int: [String: Int]]]]()
        rows.forEach { (r: strucutred_row) in
            let name = r.get(name: "Name")
            let opp = r.get(name: "Opp")
            let year = Int(r.get(name: "Year"))!
            let week = Int(r.get(name: "Week"))!

            initWindow(values: &byPlayer, key: name, year: year, week: week)
            for stat in stats {
                byPlayer[name]![year]![week]![stat] = Int(r.get(name: stat))!
            }

            initWindow(values: &byOpp, key: opp, year: year, week: week)
            for stat in stats {
                let v = byOpp[opp]![year]![week]![stat] ?? 0
                byOpp[opp]![year]![week]![stat] = v + Int(r.get(name: stat))!
            }
        }

        rows.forEach { (r: strucutred_row) in
            for stat in stats {
                for period in ROLLING_WINDOWS {
                    let val = getRollingStat(values: byPlayer, key: r.get(name: "Name"), yearStr: r.get(name: "Year"), weekStr: r.get(name: "Week"), stat: stat, rollingWindow: period.window)
                    r.addFeature(name: period.name + "_" + stat, doubleValue: val)

                    let defVal = getRollingStat(values: byOpp, key: r.get(name: "Opp"), yearStr: r.get(name: "Year"), weekStr: r.get(name: "Week"), stat: stat, rollingWindow: period.window)
                    r.addFeature(name: "Def_" + period.name + "_" + stat, doubleValue: defVal)
                }
            }
        }
    }

    private func initWindow(values: inout [String: [Int: [Int: [String: Int]]]], key: String, year: Int, week: Int) {
        if values[key] == nil {
            values[key] = [Int: [Int: [String: Int]]]()
        }
        if values[key]![year] == nil {
            values[key]![year] = [Int: [String: Int]]()
        }
        if values[key]![year]![week] == nil {
            values[key]![year]![week] = [String: Int]()
        }
    }
    
    private func getRollingStat(values: [String: [Int: [Int: [String: Int]]]], key: String, yearStr: String, weekStr: String, stat: String, rollingWindow: Int) -> Double {
        var week = Int(weekStr)!
        var year = Int(yearStr)!
        var samples = 0
        var total = 0
        var cur = rollingWindow
        while cur > 0 {
            cur = cur - 1
            week = week - 1
            if week < 1 {
                year = year - 1
                week = 16
            }
            let v = values[key]?[year]?[week]?[stat]
            if v != nil {
                total += v!
                samples = samples + 1
            }
        }
        if samples == 0 {
            return 0.0
        }
        return Double(total) / Double(samples)
    }

    // Add Team Features, by adding a dummy column for every team and opponent with 1 or 0
    private func addTeam(rows: [strucutred_row]) {
        var teams = Set<String>()
        rows.forEach { (r: strucutred_row) in
            teams.insert(r.get(name: "Team"))
            teams.insert(r.get(name: "Opp"))
        }

        let sortedTeams = teams.sorted()
        rows.forEach { (r: strucutred_row) in
            for team in sortedTeams {
                r.addFeature(name: "Team_" + team, boolValue: team == r.get(name: "Team"))
                r.addFeature(name: "Opp_" + team, boolValue: team == r.get(name: "Opp"))
            }
            r.addFeature(name: "Is_Home_Game", boolValue: r.get(name: "At") != "@")
            r.addFeature(name: "Is_Sunday_Game", boolValue: r.get(name: "Day") == "Sun")
        }
    }

    private func addDerivedData(rows: [strucutred_row]) throws {
        var posMap = [String: String]()

        // The weekly records don't have position, so lets try to set them here.
        // We go in reverse lexicographic order (so 2018 is evaluated before 2017)
        let yearlyFileNames = try getFileNames(prefix: "yearly_stats_")
        for fileName in yearlyFileNames.sorted().reversed() {
            try readCSV(fileName: fileName, eval: { (r: strucutred_row) in
                let sanitizedName = r.get(name: "Name").components(separatedBy: "\\")[0]
                let pos = r.get(name: "FantPos")
                if pos.count > 0 && posMap[sanitizedName] == nil {
                    posMap[sanitizedName] = pos
                }
            })
        }

        rows.forEach { (r: strucutred_row) in
            let pos = posMap[r.get(name: "Name")]
            r.add(name: "Pos", value: pos ?? "Unknown")
            r.add(name: "Year", value: r.get(name: "Date").components(separatedBy: "-")[0])
        }
    }

    private func getFileNames(prefix: String) throws -> [String] {
        let fm = FileManager.default
        let fileNames = try fm.contentsOfDirectory(atPath: "data/")
        return fileNames.filter({ (fileName: String) -> Bool in
            return fileName.hasPrefix(prefix)
        })
    }

    private func getReader(fileName: String) throws -> CSVReader {
        let stream = InputStream(fileAtPath: "data/" + fileName)!
        return try! CSVReader(stream: stream)
    }

    private func readCSV(fileName: String, eval: (strucutred_row) -> ()) throws {
        let stream = InputStream(fileAtPath: "data/" + fileName)!
        let reader = try! CSVReader(stream: stream)

        var isHeader = true
        var headerMap = [String: Int]()

        while let row = reader.next() {
            if isHeader {
                for (index, name) in row.enumerated() {
                    headerMap[name] = index
                }
                isHeader = false
                continue
            }
            
            let r = strucutred_row(row: row, rowMap: headerMap)
            eval(r)
        }
    }

    private func writeCSV(rows: [strucutred_row]) throws {
        let fileName = "data/training_data.csv"
        let stream = OutputStream(toFileAtPath: fileName, append: false)!
        let csv = try! CSVWriter(stream: stream)
        
        if rows.count == 0 {
            print("No data!")
            return
        }
        
        let firstRow = rows.first!
        try! csv.write(row: firstRow.getCSVHeader())
        for row in rows {
            try! csv.write(row: row.getCSVRow())
        }
        
        csv.stream.close()
    }
}
