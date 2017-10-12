//
//  QoodApiError.swift
//  TestQoodApi
//
//  Created by peng(childhood@me.com) on 15/6/19.
//  Copyright (c) 2015年 peng(childhood@me.com). All rights reserved.
//

import Foundation
import ObjectMapper
open class QoodApiError:CommonModel{
//    var code:String=""
//    var msg:String=""
    var errorMsg:String=""

    var timestamp:Date=defaultDate as Date
    func copyWithZone(_ zone: NSZone?) -> AnyObject! {
        return QoodApiError()
    }
    open override func mapping(map: Map){
        code <- map["code"]
        errorMsg <- map["msg"]
        timestamp <- (map["timestamp"],self.dateTransform)
    }
}
extension QoodApiError{
    
}
