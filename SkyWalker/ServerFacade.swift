//
//  ServerHandler.swift
//  SkyWalker
//
//  Created by Héctor Del Campo Pando on 20/2/17.
//  Copyright © 2017 Héctor Del Campo Pando. All rights reserved.
//

import Foundation

/**
 XtremeLoc persistence facade
 */
class ServerFacade {
    
    /**
     Possible errors
    */
    public enum ErrorType: Error {
        case NO_CONNECTION,
        TIME_OUT, INVALID_USERNAME_OR_PASSWORD, INVALID_JSON,
        NO_TOKEN_SET, SERVER_ERROR, UNKNOWN
    }
    
    /**
        Singleton instance
    */
    static let instance: ServerFacade! = ServerFacade()
    
    /**
        Treats a connection error.
        - Parameters:
            - error: The connection error to treat.
            - onError: Callback.
    */
    private func treatError (error: Error, onError: @escaping (_: ErrorType) -> Void) {
        if let networkErr = error as? URLError {
            switch networkErr.code {
            case .timedOut:
                onError(.TIME_OUT)
            case .notConnectedToInternet:
                onError(.NO_CONNECTION)
            default:
                onError(.UNKNOWN)
            }
        } else {
            onError(.UNKNOWN)
        }
    }
    
    /**
        Retrieves a new token.
        - Parameters:
            - url: The server url.
            - username: Login username.
            - password: Login password.
            - onSuccess: Success callback.
            - onError: Error callback.
    */
    func getToken (url: String, username: String?, password: String?,
                          onSuccess: @escaping (_: Token) -> Void, onError: @escaping (_: ErrorType) -> Void) {
        
        let realUrl = url.appending("/api/authentication")
        
        guard let URL = URL(string: realUrl) else {
            print ("Error \(url) is invalid")
            return
        }
        
        var request = URLRequest(url: URL)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            let params: [String: Any] = ["login" : username!, "password" : password!]
            request.httpBody =
                try JSONSerialization.data(withJSONObject: params, options: [])
        } catch {
            print("Error: cannot parse JSON")
            return
        }
        
        let session = URLSession.shared
        
        let task = session.dataTask(with: request, completionHandler: {(data, response, error) in
            
                guard error == nil else {
                    self.treatError(error: error!, onError: onError)
                    return;
                }
            
                if let httpResponse = response as? HTTPURLResponse {
            
                    if (httpResponse.statusCode != 200) {
                        onError(ServerFacade.getError(statusCode: httpResponse.statusCode))
                    } else {
                        let data = String(data: data!, encoding: String.Encoding.utf8)
                        let token = Token(URL: url, token: data!)
                        onSuccess(token)
                    }
            
                }
            
        }
            
        )
        
        task.resume()
        
    }
    
    /**
     Retrieves a center's receivers.
     - Parameters:
        - center: The center id
        - onSuccess: Success callback.
        - onError: Error callback.
     */
    func getCenterReceivers (center: Int,
                             onSuccess: @escaping (_: [MapPoint]) -> Void,
                             onError: @escaping (_: ErrorType) -> Void) throws {
        
        if (nil == User.instance.token) {
            throw ErrorType.NO_TOKEN_SET
        }
        
        let realURL = User.instance.token!.URL.appending("/api/centers/\(center)/rdhubs")
        guard let URL = URL(string: realURL) else {
            print ("Error \(realURL) is invalid")
            return
        }
        
        var request = URLRequest(url: URL)
        request.httpMethod = "GET"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(User.instance.token!.token!)", forHTTPHeaderField: "Authorization")
        
        let session = URLSession.shared
        let task = session.dataTask(with: request, completionHandler: {(data, response, error) in
            
            guard error == nil else {
                self.treatError(error: error!, onError: onError)
                return;
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                
                if (httpResponse.statusCode != 200) {
                    onError(ServerFacade.getError(statusCode: httpResponse.statusCode))
                } else {
                    let jsons = try! JSONSerialization.jsonObject(with: data!, options: []) as! NSArray
                    var receivers = [MapPoint]()
                    
                    for json in jsons as! [Dictionary<String, Any>]{
                        let id: Int = json["id"] as! Int
                        let x: Double = json["x"] as! Double
                        let y: Double = json["y"] as! Double
                        let z: Int = json["z"] as! Int
                        let receiver = MapPoint(id: id, x: x, y: y, z: z)
                        receivers.append(receiver)
                    }
                    
                    onSuccess(receivers)
                }
                
            }
            
        }
            
        )
        
        task.resume()
        
    }

    
    /**
        Retrieves the avaliable tags for the token in use.
        - Parameters:
            - onSuccess: Success callback.
            - onError: Error callback.
    */
    func getAvaliableTags (onSuccess: @escaping (_: [PointOfInterest]) -> Void,
                           onError: @escaping (_: ErrorType) -> Void) throws {
    
        if (nil == User.instance.token) {
            throw ErrorType.NO_TOKEN_SET
        }
        
        let realURL = User.instance.token!.URL.appending("/api/centers/\(User.instance.center!.id)/tags")
        guard let URL = URL(string: realURL) else {
            print ("Error \(realURL) is invalid")
            return
        }
        
        var request = URLRequest(url: URL)
        request.httpMethod = "GET"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(User.instance.token!.token!)", forHTTPHeaderField: "Authorization")
                
        let session = URLSession.shared
        let task = session.dataTask(with: request, completionHandler: {(data, response, error) in
            
            guard error == nil else {
                self.treatError(error: error!, onError: onError)
                return;
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                
                if (httpResponse.statusCode != 200) {
                    onError(ServerFacade.getError(statusCode: httpResponse.statusCode))
                } else {
                    let jsons = try! JSONSerialization.jsonObject(with: data!, options: []) as! NSArray
                    var points = [PointOfInterest]()
                    
                    for json in jsons as! [Dictionary<String, Any>]{
                        let id: Int = json["id"] as! Int
                        let name: String = json["name"] as? String ?? "Unknown"
                        let point = PointOfInterest(id: id, name: name)
                        points.append(point)
                    }
                    
                    onSuccess(points)
                }
                
            }
            
        }
            
        )
        
        task.resume()

    }
    
    /**
        Registers this device as an iBeacon transmitter
        - Parameters:
            - username: User to register.
            - onSuccess: Success callback.
            - onError: Error callback.
     */
    func registerAsBeacon (username: String,
                           onSuccess: @escaping (_: IBeaconFrame) -> Void,
                           onError: @escaping (_: ErrorType) -> Void) throws {
        
        if (nil == User.instance.token) {
            throw ErrorType.NO_TOKEN_SET
        }
        
        let realURL = User.instance.token!.URL.appending("/api/centers/\(User.instance.center!.id)/tags")
        guard let URL = URL(string: realURL) else {
            print ("Error \(realURL) is invalid")
            return
        }
        
        var request = URLRequest(url: URL)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(User.instance.token!.token!)", forHTTPHeaderField: "Authorization")
        
        do {
            let params: [String: String] = ["name" : username]
            request.httpBody =
                try JSONSerialization.data(withJSONObject: params, options: [])
        } catch {
            print("Error: cannot parse JSON")
            return
        }
        
        let session = URLSession.shared
        let task = session.dataTask(with: request, completionHandler: {(data, response, error) in
            
            guard error == nil else {
                self.treatError(error: error!, onError: onError)
                return;
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                
                if (httpResponse.statusCode != 200) {
                    onError(ServerFacade.getError(statusCode: httpResponse.statusCode))
                } else {
                    let json = try! JSONSerialization.jsonObject(with: data!, options: []) as! Dictionary<String, Any>
                    
                    let uuid: UUID = UUID(uuidString: "3E8C0296-168B-4940-ADB0-B3088F7EE30E")!
                    let major: Int = json["major"] as! Int
                    let minor: Int = json["minor"] as! Int
                    
                    let frame = IBeaconFrame(uuid: uuid, major: major, minor: minor)
                    
                    onSuccess(frame)
                }
                
            }
            
        }
            
        )
        
        task.resume()
        
    }
    
    /*
        Retrieves a point of interest last position.
        - Parameters:
            - tag: Tag to retrieve.
            - onSuccess: Success callback.
            - onError: Error callback.
    */
    func getLastPosition(tag: Int,
                         onSuccess: @escaping (_: MapPoint) -> Void,
                         onError: @escaping (_: ErrorType) -> Void) throws {
        
        if (nil == User.instance.token) {
            throw ErrorType.NO_TOKEN_SET
        }
        
        let realURL = User.instance.token!.URL.appending("/api/centers/\(User.instance.center!.id)/tags/\(tag)")
        guard let URL = URL(string: realURL) else {
            print ("Error \(realURL) is invalid")
            return
        }
        
        var request = URLRequest(url: URL)
        request.httpMethod = "GET"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(User.instance.token!.token!)", forHTTPHeaderField: "Authorization")
        
        let session = URLSession.shared
        let task = session.dataTask(with: request, completionHandler: {(data, response, error) in
            
            guard error == nil else {
                self.treatError(error: error!, onError: onError)
                return;
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                
                if (httpResponse.statusCode != 200) {
                    onError(ServerFacade.getError(statusCode: httpResponse.statusCode))
                } else {
                    guard let json = try! JSONSerialization.jsonObject(with: data!, options: []) as? Dictionary<String, Any> else {
                        onError(.INVALID_JSON)
                        return
                    }
                    
                    if let receiverId = json["nearest_rdhub"] as? Int {
                        
                        let receivers = User.instance.center!.receivers!
                        
                        var receiver: MapPoint!
                        
                        for element in receivers {
                            if element.id == receiverId {
                                receiver = element
                                break
                            }
                        }
                        
                        let newPosition = MapPoint(id: receiverId,
                                                   x: receiver.x,
                                                   y: receiver.y,
                                                   z: receiver.z)
                        
                        onSuccess(newPosition)
                        
                    }
                    
                }
                
            }
            
        }
            
        )
        
        task.resume()
        
    }
    
    /**
        Retrieves actual server error
        - Parameters:
            - statusCode: http status code
        - Returns: The actual error
    */
    static func getError (statusCode : Int) -> ErrorType {
        
        switch statusCode {
            case 401:
                return .INVALID_USERNAME_OR_PASSWORD
            case 500:
                return .SERVER_ERROR
            default:
                return .UNKNOWN
        }
        
    }
    
}
