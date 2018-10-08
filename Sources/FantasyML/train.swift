import CreateML
import Foundation

import CSV

class Trainer {
    struct output_row {
        let name: String
        let predictedScore: Double
        let actualScore: Double
        var predictedRank: Int
        var actualRank: Int
    }

    let position: String
    let year: String
    let week: String
    
    init(position: String, year: String, week: String) {
        self.position = position
        self.year = year
        self.week = week
    }

    func train() throws {
        print("Training...")
        
        var (trainingData, testData) = try partitionData()
        var features: [String] = [String]()
        var columnsToRemove: [String] = [String]()
        for columnName in trainingData.columnNames {
            if columnName.starts(with: "Feat:") {
                features.append(columnName)
            } else if columnName !=  "Fantasy Points" {
                columnsToRemove.append(columnName)
            }
        }

        // There is a bug where MLRegressor crashes when you have extraneous
        // columns. We can just delete them for now...
        for columnName in columnsToRemove {
            trainingData.removeColumn(named: columnName);
        }
        
        let regressor = try MLRegressor(trainingData: trainingData, targetColumn: "Fantasy Points", featureColumns: features)
        let predictions = try regressor.predictions(from: testData)
        testData.addColumn(predictions, named: "Prediction")

        var outputData: [output_row] = [output_row]()
        for row in testData.rows {
            let name = row[row.index(forKey: "Name")!]
            let prediction = row[row.index(forKey: "Prediction")!]
            let actual = row[row.index(forKey: "Fantasy Points")!]
            outputData.append(output_row(name: name.1.stringValue!, predictedScore: prediction.1.doubleValue!, actualScore: actual.1.doubleValue!, predictedRank: -1, actualRank: -1))
        }

        // We want to add the ranks as well (for easy analysis). We simply
        // sort desc by prediction and actual, and add the corresponding
        // index as the rank
        outputData.sort { (o1: output_row, o2: output_row) -> Bool in
            return o2.predictedScore < o1.predictedScore;
        }
        for i in 0..<outputData.count {
            outputData[i].predictedRank = i+1
        }
        outputData.sort { (o1: output_row, o2: output_row) -> Bool in
            return o2.actualScore < o1.actualScore;
        }
        for i in 0..<outputData.count {
            outputData[i].actualRank = i+1
        }

        let fn = "output/results_" + self.year + "_" + formatWeek() + "_" + self.position + ".csv"
        let outputStream = OutputStream(toFileAtPath: fn, append: false)!
        let output = try! CSVWriter(stream: outputStream)
        try output.write(row: ["Name", "Predicted Score", "Predicted Rank", "Actual Score", "Actual Rank"])
        for row in outputData {
            try output.write(row: [
                row.name,
                String(format: "%.01f", row.predictedScore),
                String(row.predictedRank),
                String(format: "%.01f", row.actualScore),
                String(row.actualRank),
            ])
        }
        output.stream.close()
    }

    private func fileName(trainingData: Bool) -> String {
        return
            "output/partitioned_" +
                self.year + "_" + formatWeek() + "_" + self.position +
                (trainingData ? "_training" : "_test") + ".csv"
    }

    private func formatWeek() -> String {
        if self.week.count == 1 {
            return "0" + self.week
        }
        return self.week
    }

    private func partitionData() throws -> (MLDataTable, MLDataTable) {
        let stream = InputStream(fileAtPath: "data/training_data.csv")!
        let reader = try! CSVReader(stream: stream)

        var isHeader = true
        var headerMap = [String: Int]()

        // Instead of creating an MLDataTable directly with dictionaries, we
        // save the partitioned data rows as csvs and load them into MLDataTables
        // (which is more expensive, but easier)
        let testStream = OutputStream(toFileAtPath: self.fileName(trainingData: false), append: false)!
        let testCSV = try! CSVWriter(stream: testStream)
        let trainingStream = OutputStream(toFileAtPath: self.fileName(trainingData: true), append: false)!
        let trainingCSV = try! CSVWriter(stream: trainingStream)

        while let row = reader.next() {
            if isHeader {
                for (index, name) in row.enumerated() {
                    headerMap[name] = index
                }
                try! testCSV.write(row: row)
                try! trainingCSV.write(row: row)
                isHeader = false
                continue
            }

            if row[headerMap["Pos"]!] != self.position {
                continue
            }

            if row[headerMap["Week"]!] == self.week &&
                row[headerMap["Year"]!] == self.year {
                try! testCSV.write(row: row)
            } else {
                try! trainingCSV.write(row: row)
            }
        }

        testCSV.stream.close()
        trainingCSV.stream.close()

        return (
            try MLDataTable(contentsOf: URL(fileURLWithPath: self.fileName(trainingData: true))),
            try MLDataTable(contentsOf: URL(fileURLWithPath: self.fileName(trainingData: false)))
        )
    }
}
