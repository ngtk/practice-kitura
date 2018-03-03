import Foundation
import Kitura
import LoggerAPI
import Configuration
import CloudEnvironment
import KituraContracts
import Health
import KituraCORS
import Dispatch

public let projectPath = ConfigurationManager.BasePath.project.path
public let health = Health()

public class App {
    let router = Router()
    let cloudEnv = CloudEnv()
    private var todoStore = [ToDo]()
    private var nextId :Int = 0
    private let workerQueue = DispatchQueue(label: "worker")

    public init() throws {
        // Run the metrics initializer
        initializeMetrics(router: router)
    }

    func postInit() throws {
        // Endpoints
        initializeHealthRoutes(app: self)

        // Cors
        configureCors()

        // Hello world
        router.get("/") {
            request, response, next in
            response.send("Hello, World!")
            next()
        }

        router.post("/", handler: storeHandler)
        router.delete("/", handler: deleteAllHandler)
    }

    func storeHandler(todo: ToDo, completion: (ToDo?, RequestError?) -> Void ) {
        var todo = todo
        if todo.completed == nil {
            todo.completed = false
        }
        todo.id = nextId
        todo.url = "http://localhost:8080/\(nextId)"
        nextId += 1
        execute {
            todoStore.append(todo)
        }
        completion(todo, nil)
    }

    func deleteAllHandler(completion: (RequestError?) -> Void ) {
        execute {
            todoStore = [ToDo]()
        }
        completion(nil)
    }
    
    func configureCors() {
        let options = Options(allowedOrigin: .all)
        let cors = CORS(options: options)
        router.all("/*", middleware: cors)
    }

    public func run() throws {
        try postInit()
        Kitura.addHTTPServer(onPort: cloudEnv.port, with: router)
        Kitura.run()
    }

    func execute(_ block: (() -> Void)) {
        workerQueue.sync {
            block()
        }
    }
}
