//
//  Center.swift
//  SkyWalker
//
//  Created by Héctor Del Campo Pando on 16/3/17.
//  Copyright © 2017 Héctor Del Campo Pando. All rights reserved.
//

import Foundation

class Center {
    
    let id: Int
    
    var scale: Double = 40

    
    private(set) var mapNorth: Vector2D
    
    
    static var centers = [Center]()
    
    var receivers: [MapPoint]?
    
    var points: [PointOfInterest]?
    
    init(id: Int) {
        self.id = id
        mapNorth = Vector2D(x: 1, y: 0)
    }
    
    func loadReceivers(successDelegate: (() -> Void)?,
                       errorDelegate: ((PersistenceErrors) -> Void)?) {
        
        let onSuccess: ([MapPoint]) -> Void = {receivers in
            self.receivers = receivers
            self.scale = 128
            successDelegate?()
        }
        
        let onError: (ServerFacade.ErrorType) -> Void = {error in
            
            let realError: PersistenceErrors
            
            switch(error) {
            case .NO_CONNECTION, .TIME_OUT:
                realError = .INTERNET_ERROR
            default:
                realError = .SERVER_ERROR
            }
            
            errorDelegate?(realError)
            
        }
        
        try! ServerFacade.instance.getCenterReceivers(center: self, onSuccess: onSuccess, onError: onError)
    }
    
    func loadTags(successDelegate: (() -> Void)?,
                       errorDelegate: ((PersistenceErrors) -> Void)?) {
        
        let onSuccess: ([PointOfInterest]) -> Void = {points in
            
            self.points = points
            PointOfInterest.points = points
            if let myIndex = points.index(of: PointOfInterest.mySelf) {
                PointOfInterest.points.remove(at: myIndex)
            }
            
            successDelegate?()
            
        }
        
        let onError: (ServerFacade.ErrorType) -> Void = {error in
            
            let realError: PersistenceErrors
            
            switch(error) {
            case .NO_CONNECTION, .TIME_OUT:
                realError = .INTERNET_ERROR
            default:
                realError = .SERVER_ERROR
            }
            
            errorDelegate?(realError)
            
        }
        
        try! ServerFacade.instance.getAvaliableTags(onSuccess: onSuccess, onError: onError)
    }
    
}
