import Foundation

let args = CommandLine.arguments

struct operation {
    let name: String
    let eval: () throws -> ()
}

let operations = [
    operation(name: "fetch", eval: {
        if args.count != 4 {
            print("Need to provide year and week")
            exit(1)
        }
        let fetcher = Fetcher(year: args[2], week: args[3])
        try fetcher.fetch()
    }),
    operation(name: "prepare", eval: {
        let preparer = Preparer()
        try preparer.prepare()
    }),
    operation(name: "train", eval: {
        if args.count != 5 {
            print("Need to provide position, year, and week to predict for!")
            exit(1)
        }
        let trainer = Trainer(position: args[2], year: args[3], week: args[4])
        try trainer.train()
    }),
]

let operation_names = operations.map({ $0.name }).joined(separator: ", ")

func run() throws {
    if args.count <= 1 {
        print("Need operation in [\(operation_names)]")
        exit(1)
    }
    
    for op in operations {
        if op.name == args[1] {
            try op.eval()
            exit(0)
        }
    }
    
    print("Unknown operation - must be in [\(operation_names)]")
    exit(1)
}

try run()
