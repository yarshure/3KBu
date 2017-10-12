//
//  AxHttpProtocol.swift
//  TestQoodApi
//
//  Created by peng(childhood@me.com) on 15/6/19.
//  Copyright (c) 2015年 peng(childhood@me.com). All rights reserved.
//

import Foundation
import SwiftyJSON
import ObjectMapper
import Just
class AxHttpParameter:NSObject{
    
    var baseURL:String?
    var attr:String = "data" //用来parser json
    var path:String=""
    var httpMethod:String=""
    var paras:[String:AnyObject]=[:]
    var headers:[String:String]=[:]
    init(path:String,method:String){
        self.path=path
        self.httpMethod=method
    }
    func addHeaderKey(_ key:String, value:String){
        if (!key.isEmpty) && (!value.isEmpty){
            self.headers[key]=value
        }
    }
    
    func addParaKey<T>(_ key:String, value:T){
        if (!key.isEmpty) {
            self.paras[key] =  value as AnyObject?

        }
    }

    
    override var description: String {
        return "path:\(path),method:\(httpMethod),paras:\(paras),headers:\(headers)"
    }
}
internal extension Dictionary {
    mutating func merge<K, V>(_ dictionaries: Dictionary<K, V>...) {
        for dict in dictionaries {
            for (key, value) in dict {
                self.updateValue(value as! Value, forKey: key as! Key)
            }
        }
    }
}
extension AxHttpParameter{
    func fullPath(_ basestr:String) -> String{
        
        
        if let b = baseURL {
            //let x = b as NSString
            return  b + self.path
        }else {
            let x = basestr as NSString
            return  x.appendingPathComponent(self.path)
            
        }
        
    }
    func fullHeaders(_ systemHeader:[String:String]) ->[String:String]{
        self.headers.merge(systemHeader)
        return self.headers
    }
}
extension String {
    func stringByAddingPercentEncodingForFormUrlencoded() -> String{
        let ssString = self as NSString
        return ssString.addingPercentEncoding(withAllowedCharacters: NSCharacterSet.urlQueryAllowed)!;
        
    }
}
class  AxJust{
    static func processHttpResonse(_ r:HTTPResult,onSuccess:(_ responseString:AnyObject?)->Void, onFail:(_ httpCode:Int?,_ reason:String?,_ responseString:AnyObject?)->Void){
        if r.ok{
            onSuccess(r.json as AnyObject?)
        }else{
            onFail(r.statusCode,r.reason,r.json as AnyObject?)
        }
    }
    static func doJustHttpWithPara(_ url:String,method:String,para:[String:AnyObject],headers:[String:String], onSuccess:@escaping (_ response:AnyObject?)->Void, onFail:@escaping (_ httpCode:Int?,_ reason:String?,_ responseString:AnyObject?)->Void){
        let u = url.stringByAddingPercentEncodingForFormUrlencoded()
        switch method{
        case "get":
            Just.get(u, params:para, headers:headers,timeout:QoodApiConsts.apiTimeoutTime) { r in self.processHttpResonse(r,onSuccess:onSuccess,onFail:onFail) }
        case "post":
            if let jsonString:String = para["json"] as! String?{
                let data = jsonString.data(using: .utf8)
                let jsonD = JSON(data:data!)
                var jsonDict:[String:String] = [:]
                
                for (key,value) in jsonD {
                    jsonDict[key] = value.string
                }
                
                Just.post(u,json:jsonDict, headers:headers,timeout:QoodApiConsts.apiTimeoutTime){ r in self.processHttpResonse(r,onSuccess:onSuccess,onFail:onFail) }
                
            }else {
                Just.post(u,data:para,headers:headers,timeout:QoodApiConsts.apiTimeoutTime){ r in self.processHttpResonse(r,onSuccess:onSuccess,onFail:onFail) }
            }
            
        case "put":
            Just.put(u,data:para,headers:headers,timeout:QoodApiConsts.apiTimeoutTime){ r in self.processHttpResonse(r, onSuccess: onSuccess, onFail: onFail) }
        case "delete":
            Just.delete(u,headers:headers,timeout:QoodApiConsts.apiTimeoutTime){r in self.processHttpResonse(r, onSuccess: onSuccess, onFail: onFail) }
        default:
            NSException(name: NSExceptionName(rawValue: "unsupport method"), reason: "unsupport http method", userInfo: nil).raise()
        }
    }
}
open class AxHttp:NSObject{
    @objc static var baseUrl:String = QoodApiConsts.serverUrl
    @objc static var globalHeaders:[String:String]=[:]
    @objc static var unAuthCb:(() ->Void)?
    @objc static var logCb:((_ msg:String,_ file:String,_ line:Int,_ time:Date)->Void)?
    @objc static var isDebugOn:Bool=false
    
    static func log(_ msg:String,file:String=#file,line:Int=#line,time:Date=Date()){
        if let logcb = self.logCb{
            logcb(msg,file,line,time)
        }
    }
    
    static func setHeaderValue(_ value:String, forKey:String){
        if (!value.isEmpty) && (!forKey.isEmpty){
            self.globalHeaders[forKey]=value
        }
    }
    static func logPara(_ para:AxHttpParameter){
        if self.isDebugOn{
            self.log("http para:\(para)")
        }
    }
    static func logResponse(_ resp:AnyObject?){
        if self.isDebugOn{
            self.log("http response:\(resp)")
        }
    }
    static func callUnAuthCb(){
        if  let unAuthCb = AxHttp.unAuthCb{
            unAuthCb()
        }
    }
    typealias AxHttpFailCbType=(_ httpCode:Int,_ reason:String?,_ response:QoodApiError?,_ para:AxHttpParameter)->Void
    static func processFailWith(_ httpCode:Int?,reason:String?,response:AnyObject?,para:AxHttpParameter,failCb:@escaping AxHttpFailCbType){
        self.log("request[method:\(para.httpMethod) url:\(para.fullPath(baseUrl)) para:\(para.paras) headers:\(para.headers)] response[httpCode:\(httpCode) reason:\(reason) response:\(response)]")
        DispatchQueue.main.async{
            if let httpCode=httpCode ,let response = response {
                if httpCode/100 ==  4 {
                    
                    if let err  = Mapper<QoodApiError>().map(JSON:response as! [String : Any]){
                        if ["AU000001","AU000002","AU000003","AU000004"].contains(err.code) {
                            self.callUnAuthCb()
                        }else{
                            failCb(httpCode, reason, Mapper<QoodApiError>().map(JSON:response as! [String : Any]), para)
                        }
                    }else{
                        failCb(httpCode, reason, Mapper<QoodApiError>().map(JSON:response as! [String : Any]), para)
                    }
                }else{
                    failCb(httpCode, reason, Mapper<QoodApiError>().map(JSON:response as! [String : Any]), para)
                }
                
            }else{
                //Mapper<QoodApiError>().map(JSON:response as! [String : Any])
                let error = QoodApiError()
                error.msg = "no response"
                error.code = "\(httpCode)"
                failCb(-1, reason, error, para)
            }
        }
    }
    
    static func doHttpWithPara<T:Mappable>(_ para:AxHttpParameter, onSuccess:@escaping (_:T?)->Void, onFail:@escaping AxHttpFailCbType){
        //self.logPara(para)
        let url = para.fullPath(baseUrl)
        //        if let turl  = para.url {
        //            url = turl
        //        }else {
        //            //走这里
        //            url = para.fullPath(baseUrl)
        //        }
        print("\(url)")
        AxJust.doJustHttpWithPara(url, method: para.httpMethod, para: para.paras as [String : AnyObject], headers: para.fullHeaders(globalHeaders), onSuccess: {
            responseJson in
            self.logResponse(responseJson)
            guard let responseJson =  responseJson else{
                  DispatchQueue.main.async{onSuccess(nil)}
                return
            }
            
            let attr = para.attr
            if let obj = responseJson[attr], obj != nil {
                if let objJson=responseJson as? [String:AnyObject], let rs=Mapper<T>().map(JSON:objJson[attr] as! [String : Any]){
                    DispatchQueue.main.async{onSuccess(rs)}
                }else{
                    DispatchQueue.main.async{onSuccess(nil)}
                }
            }else {
                if let objJson=responseJson as? [String:AnyObject], let rs=Mapper<T>().map(JSON:objJson){
                    DispatchQueue.main.async{onSuccess(rs)}
                }else{
                    DispatchQueue.main.async{onSuccess(nil)}
                }
            }
            
        }, onFail: {
            httpCode,reason,responseJson in
            self.processFailWith(httpCode, reason: reason, response: responseJson, para:
                para , failCb: onFail)
        })
    }
    static func doHttpWithPara<T:Mappable>(_ para:AxHttpParameter, onSuccess:@escaping (_:[T]?)->Void, onFail:@escaping AxHttpFailCbType){
        self.logPara(para)
        AxJust.doJustHttpWithPara(para.fullPath(baseUrl), method: para.httpMethod, para: para.paras as [String : AnyObject], headers: para.fullHeaders(globalHeaders), onSuccess: {
            responseJson in
            self.logResponse(responseJson)
            let attr = para.attr
            if let objJson=responseJson as? [String:AnyObject], let rs=Mapper<T>().mapArray(JSONObject:objJson[attr]){
                DispatchQueue.main.async{onSuccess(rs)}
            }else{
                DispatchQueue.main.async{onSuccess(nil)}
                //self.processFailWith(httpCode, reason: reason, response: responseJson, para: para, failCb: onFail)
            }
        }, onFail: {
            httpCode,reason,responseJson in
            self.processFailWith(httpCode, reason: reason, response: responseJson, para: para, failCb: onFail)
        })
    }
    static func doHttpWithPara<T:Mappable>(_ para:AxHttpParameter, onSuccess:@escaping (_:[T]?)->Void,objMapper: @escaping (_ json:AnyObject?)->[T]?, onFail:@escaping AxHttpFailCbType){
        self.logPara(para)
        AxJust.doJustHttpWithPara(para.fullPath(baseUrl), method: para.httpMethod, para: para.paras as [String : AnyObject], headers: para.fullHeaders(globalHeaders), onSuccess: {
            responseJson in
            self.logResponse(responseJson)
            let obj = objMapper(responseJson)
            DispatchQueue.main.async{onSuccess(obj)}
        }, onFail: {
            httpCode,reason,responseJson in
            self.processFailWith(httpCode, reason: reason, response: responseJson, para: para, failCb: onFail)
        })
    }
    static func doHttpWithPara<T:Mappable>(_ para:AxHttpParameter, onSuccess:@escaping (_:T?)->Void,objMapper: @escaping (_ json:AnyObject?)->T?, onFail:@escaping AxHttpFailCbType){
        self.logPara(para)
        AxJust.doJustHttpWithPara(para.fullPath(baseUrl), method: para.httpMethod, para: para.paras as [String : AnyObject], headers: para.fullHeaders(globalHeaders), onSuccess: {
            responseJson in
            self.logResponse(responseJson)
            let obj = objMapper(responseJson)
            DispatchQueue.main.async{onSuccess(obj)}
        }, onFail: {
            httpCode,reason,responseJson in
            self.processFailWith(httpCode, reason: reason, response: responseJson, para: para, failCb: onFail)
        })
    }
    static func doHttpWithPara<T:Mappable>(_ para:AxHttpParameter, onSuccess:@escaping (_:[T]?)->Void,objMapper: @escaping (_ json:AnyObject?)->T?, onFail:@escaping AxHttpFailCbType){
        self.logPara(para)
        AxJust.doJustHttpWithPara(para.fullPath(baseUrl), method: para.httpMethod, para: para.paras as [String : AnyObject], headers: para.fullHeaders(globalHeaders), onSuccess: {
            responseJson in
            self.logResponse(responseJson)
            let obj = objMapper(responseJson)
            DispatchQueue.main.async{onSuccess(obj as? [T])}
        }, onFail: {
            httpCode,reason,responseJson in
            self.processFailWith(httpCode, reason: reason, response: responseJson, para: para, failCb: onFail)
        })
    }
    static func doHttpWithPara(_ para:AxHttpParameter, onSuccess:@escaping (_:AnyObject?)->Void, onFail:@escaping AxHttpFailCbType){
        self.logPara(para)
        AxJust.doJustHttpWithPara(para.fullPath(baseUrl), method: para.httpMethod, para: para.paras as [String : AnyObject], headers: para.fullHeaders(globalHeaders), onSuccess: {
            responseJson in
            self.logResponse(responseJson)
            if let objJson=responseJson as? [String:AnyObject]{
                DispatchQueue.main.async{onSuccess(objJson[para.attr])}
            }else{
                DispatchQueue.main.async{onSuccess(nil)}
            }
        }, onFail: {
            httpCode,reason,responseJson in
            self.processFailWith(httpCode, reason: reason, response: responseJson, para: para, failCb: onFail)
        })
    }
    static func downloadFile(_ url:String,toPath:String,timeout:Double = QoodApiConsts.apiTimeoutTime,progress:((Double)->Void)?=nil,complete:@escaping (Bool)->Void){
        
        Just.get(url, timeout: timeout, asyncProgressHandler: {
            p in
            if let progress = progress{
                progress(Double(p.percent))
            }
        }){
            r in
            if r.ok{
                if let content = r.content{
                    //content.writeToFile(toPath, atomically: true)
                    let u = URL.init(fileURLWithPath: toPath)
                    try! content.write(to: u)
                    
                    complete(true)
                }else{
                    self.log("error,empty content,\(r.response)")
                    complete(false)
                }
            }else{
                self.log("download file error:\(r.reason,r.error)")
                complete(false)
            }
        }
    }
    static func uploadFile(_ url:String,filename:String,file:String,headers:[String:String],para:[String:AnyObject],timeout:Double = QoodApiConsts.apiTimeoutTime,progress:((Double)->Void)?=nil,complete:@escaping (Bool)->Void){
        //        if let fileurl = NSURL(fileURLWithPath: file){
        //            Just.post(url, headers: headers,data:para, files: [filename:HTTPFile.URL(fileurl,nil)], timeout: timeout, asyncProgressHandler: {
        //                p in
        //                if let progress = progress{
        //                    progress(Double(p.percent))
        //                }
        //            }){
        //                r in
        //                if r.ok{
        //                    complete(true)
        //                }else{
        //                    self.log("upload file error:\(headers,r.url,r.reason,r.error,r.text)")
        //                    complete(false)
        //                }
        //            }
        //        }
        
        let fileurl = URL(fileURLWithPath: file)
        Just.post(url, data:para,headers: headers, files: [filename:HTTPFile.url(fileurl,"")], timeout: timeout, asyncProgressHandler: {
            p in
            if let progress = progress{
                progress(Double(p.percent))
            }
        }){
            r in
            if r.ok{
                complete(true)
            }else{
                self.log("upload file error:\(headers,r.url,r.reason,r.error,r.text)")
                complete(false)
            }
        }
    }
}
