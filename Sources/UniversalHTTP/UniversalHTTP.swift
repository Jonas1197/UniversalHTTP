//
//  UniversalHTTP.swift
//  UniversalHTTP
//
//  Created by Yonatan Gamburg on 22/05/2022.
//

import Foundation

//MARK: - HTTPServiceDelegate
public protocol HTTPServiceDelegate: AnyObject {
    func errorDidOccur()
}

public enum HttpMethod { case POST, GET }

//MARK: - UniversalHTTP
public struct UniversalHTTP<Model : Codable> {
    
    public typealias SuccessComplitionHandler = (_ response: Model?, _ statusCode: Int?) -> Void
    
    
    /**
     Create and send out a POST request using a path, a url and a delegate to inform about errors.
     - Parameter delegate: Provided a delegate to inform the view about any errors occuring
     - Parameter url: The URL provided as a String as to where to send the POST request.
     - Parameter complition: A complition provided to return the parsed data.
     */
    public static func performRequest<BodyModel: Codable>(_ delegate: HTTPServiceDelegate? = nil,
                                                   url: String,
                                                   body: [String : Any]?  = nil,
                                                   httpMethod: HttpMethod = .GET,
                                                   bodyModel: BodyModel?  = nil,
                                                   httpValueForHeaderField values: [String : String]? = nil,
                                                   debugPrintsEnabled: Bool = false,
                                                   _ complition: SuccessComplitionHandler? = nil) {
        
        guard let urlComponent = URLComponents(string: url),
              let usableUrl    = urlComponent.url else {
                  delegate?.errorDidOccur()
                  return
              }
        
        var request        = URLRequest(url: usableUrl)
        request.httpMethod = httpMethod == .POST ? "POST" : "GET"
        
        
        //MARK: Body parameters
        if let body     = body,
           let bodyData = try? JSONSerialization.data(withJSONObject: body) {
            request.httpBody = bodyData
            
        } else if let bodyModel = bodyModel,
                  httpMethod != .GET,
                  let bodyData  = try? JSONEncoder().encode(bodyModel) {
            request.httpBody = bodyData
        }
        
        
        //MARK: Header values
        if let headerValues = values {
            for value in headerValues {
                request.addValue(value.value, forHTTPHeaderField: value.key)
            }
        }
        
        
        //MARK: Data task
        URLSession.shared.dataTask(with: request) { data, response, error in
            var responseCode: Int = 0
            if let response = response as? HTTPURLResponse {
                
                if debugPrintsEnabled {
                    print("\n~~> [UniversalHTTP] Response came back with code: \(response.statusCode)")
                }
                
                responseCode = response.statusCode
            }
            
            if let error = error {
                
                if debugPrintsEnabled {
                    print("\n~~> POST request met with an error:\n\(error)")
                }
                
                delegate?.errorDidOccur()
                
            } else if let data = data {
                
                if debugPrintsEnabled {
                    print("\n~~> [UniversalHTTP] Decoded data as [String: Any]:\n\(String(data: data, encoding: .utf8) ?? "-")\n")
                }
                
                guard let model = parseModel(withData: data) else {
                    delegate?.errorDidOccur()
                    complition?(nil, responseCode)
                    return
                }
                
                complition?(model, responseCode)
                return
                
            } else {
                complition?(nil, responseCode)
                return
            }
        }.resume()
    }
    
    
    
    
    @available(iOS 15, *)
    public static func performRequest<BodyModel: Codable>(_ delegate: HTTPServiceDelegate? = nil,
                                                   url: String,
                                                   body: [String : Any]?  = nil,
                                                   httpMethod: HttpMethod = .GET,
                                                   bodyModel: BodyModel?  = nil,
                                                   httpValueForHeaderField values: [String : String]? = nil,
                                                   debugPrintsEnabled: Bool = false) async -> (response: Model?, statusCode: Int?)? {
        
        guard let urlComponent = URLComponents(string: url),
              let usableUrl    = urlComponent.url else {
                  delegate?.errorDidOccur()
                  return nil
              }
        
        var request        = URLRequest(url: usableUrl)
        request.httpMethod = httpMethod == .POST ? "POST" : "GET"
        
        
        //MARK: Body parameters
        if let body     = body,
           let bodyData = try? JSONSerialization.data(withJSONObject: body) {
            request.httpBody = bodyData
            
        } else if let bodyModel = bodyModel,
                  httpMethod != .GET,
                  let bodyData  = try? JSONEncoder().encode(bodyModel) {
            request.httpBody = bodyData
        }
        
        
        //MARK: Header values
        if let headerValues = values {
            for value in headerValues {
                request.addValue(value.value, forHTTPHeaderField: value.key)
            }
        }
        
        
        //MARK: Data task
        if let retrievedData = try? await URLSession.shared.data(for: request) {
            var responseCode: Int = 0
            
            if let response = retrievedData.1 as? HTTPURLResponse {
                if debugPrintsEnabled {
                    print("\n~~> [UniversalHTTP] Response came back with code: \(response.statusCode)")
                }
                
                responseCode = response.statusCode
            }
            
            if debugPrintsEnabled {
                print("\n~~> [UniversalHTTP] Decoded data as [String: Any]:\n\(String(data: retrievedData.0, encoding: .utf8) ?? "-")\n")
            }
            
            guard let model = parseModel(withData: retrievedData.0) else {
                delegate?.errorDidOccur()
                return (nil, responseCode)
            }
            
            return (model, responseCode)
            
        } else {
            return nil
        }
    }
    
    
    /**
     Parse the jsonData according to the provided data model and return the model itself.
     - Parameter data: The data received as part of the session to be parsed and decoded.
     */
    static func parseModel(withData data: Data) -> Model? {
        do { return try JSONDecoder().decode(Model.self, from: data) }
        
        catch {
            print("\n~~> Error caught while parsing model: \(error)")
            return nil
        }
    }
}
