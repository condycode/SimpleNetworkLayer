import PlaygroundSupport
import UIKit

PlaygroundPage.current.needsIndefiniteExecution = true

extension Dictionary where Key == String {
    func read<T>(key: Key, defaultValue: T) -> T {
        if let value: T = read(key: key) {
            return value
        }
        return defaultValue
    }
    
    func read<T>(key: Key) -> T? {
        if keys.contains(key) {
            if let value = self[key] as? T {
                return value
            }
        }
        return nil
    }
}


enum Result<A> {
    case success(A)
    case fail(Error)
}

struct Resource<A> {
    
    let method: String
    let url: URL
    let para: [String: Any]
    let header: [String: String]
    
    let parse: ([String: Any]) -> Result<A>
}

extension HTTPURLResponse {
    func isSuccess() -> Bool {
        return statusCode >= 200 && statusCode < 300
    }
}


extension URLSession {
    
    func load<A>(resource: Resource<A>, completion: @escaping (Result<A>) -> ()) {
        
        var request = URLRequest(url: resource.url)
        request.httpMethod = resource.method
        for (key, value) in resource.header {
            request.addValue(value, forHTTPHeaderField: key)
        }
        
        let session = URLSession.shared
        let task = session.dataTask(with: request) { (data, response, error) in
            
            if let response = response as? HTTPURLResponse, response.isSuccess(), let data = data {
                do {
                    let object = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String: Any] ?? [:]
                    completion(resource.parse(object))
                } catch {
                    completion(.fail(ParseError()))
                }
            } else if let e = error {
                completion(.fail(e))
            }
        }
        task.resume()
    }
}

class Stock: NSObject {
    var object: [String: Any] = [:]
    
    init(dic: [String: Any]) {
        self.object = dic
    }
}

enum ServerError: Error {
    case unknowError
    case sessionExpired
    case noAccess
}

struct ParseError: Error {}


func checkForError<T>(dic: [String: Any], success:((_ dataContent: [String: Any]) -> (Result<T>))) -> Result<T> {
    let code = dic.read(key: "code", defaultValue: -1)
    let content = dic.read(key: "data", defaultValue: [String: Any]())
    switch code {
    case 0:
        return success(content)
    case -2:
        return .fail(ServerError.sessionExpired)
    case -3:
        return .fail(ServerError.noAccess)
    default:
        return .fail(ServerError.unknowError)
    }
}


let url = URL(string: "")!
let header = ["clientType": "0",
              "version": "8.4",
              "deviceId": "",
              "deviceType": "iPhone 5S",
              "lon": "0",
              "lat": "0",
              "requestid": ""]

let resource = Resource<Stock>(method: "GET", url: url, para: ["width" : "640", "height": "1136"], header: header) { (object) -> Result<Stock> in
    
    return checkForError(dic: object) { (content) -> (Result<Stock>) in
        return .success(Stock(dic: content))
    }
}

URLSession.shared.load(resource: resource) { (result) in
    switch result {
    case .success(let r):
        print(r.object)
    case .fail(let e):
        
        switch e {
        case let serverError as ServerError:
            switch serverError {
            case .noAccess:
                print("用户没有权限")
            case .sessionExpired:
                print("会话失效")
            default:
                print("未知错误")
            }
        case _ as ParseError:
            print("解析错误")
        default:
            print(e.localizedDescription)
        }
    }
}

