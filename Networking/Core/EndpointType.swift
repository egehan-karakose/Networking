//
//  EndpointType.swift
//  Network
//
//  Created by Egehan KARAKÖSE (Dijital Kanallar Uygulama Geliştirme Müdürlüğü) on 27.03.2022.
//
import Foundation
import PKHUD
import UIKit
import Comp
import Common

public struct Query {
    let key: String
    let value: String
    
    public init(key: String, value: String) {
        self.key = key
        self.value = value
    }
}

public class Endpoint {
    var baseURL: URL
    var path: String
    var parameters: Parameters
    var httpMethod: HTTPMethod
    var httpTask: HTTPTask
    var httpHeaders: HTTPHeaders
    var queries: [Query]
    
    public init(baseURL: URL = Environment.shared.current.url,
                path: String,
                parameters: Parameters = [:],
                httpMethod: HTTPMethod,
                httpTask: HTTPTask,
                httpHeaders: HTTPHeaders = .json,
                queries: [Query] = []) {
        self.baseURL = baseURL
        self.path = path
        self.parameters = parameters
        self.httpMethod = httpMethod
        self.httpTask = httpTask
        self.httpHeaders = httpHeaders
        self.queries = queries
    }
}

public protocol Retrieve {
    func retrieve<T: Codable>(_ success: @escaping (T?) -> Void, failure: ((ErrorPair?) -> Void)?)
    func retrieveWithProgress<T: Codable>(_ success: @escaping (T?) -> Void, failure: ((ErrorPair?) -> Void)?)
    func retrieveWithCleanResponse<T: Codable>(_ success: @escaping (T?) -> Void)
    var getMessage: StringHandler? { get set }
}

public protocol EndpointType: Retrieve {
    var baseURL: URL { get }
    var path: String { get }
    var parameters: Parameters { get }
    var httpMethod: HTTPMethod { get }
    var httpTask: HTTPTask { get }
    var httpHeaders: HTTPHeaders { get }
    var endpoint: Endpoint { get }
    func requestCompleted()
}

public extension EndpointType {
    
    func requestCompleted() {}
    
    var endpoint: Endpoint {
        return Endpoint(baseURL: baseURL, path: path, parameters: parameters, httpMethod: httpMethod, httpTask: httpTask, httpHeaders: httpHeaders, queries: queries)
    }
    
    var baseURL: URL {
        return Environment.shared.current.url
    }
    
    var path: String {
        return ""
    }
    
    var parameters: Parameters {
        return [:]
    }
    
    var httpMethod: HTTPMethod {
        return .post
    }
    
    var httpTask: HTTPTask {
        return .request
    }
    
    var queries: [Query] {
        return []
    }
    
    // Default HTTPHeader value is json. If you wanna change,
    // please add "var httpHeaders: HTTPHeaders" to your enum which was implemented EndpointType
    var httpHeaders: HTTPHeaders {
        return .json
    }
    
    func buildRequest() throws -> URLRequest {
        var url = URLComponents(url: endpoint.baseURL.appendingPathComponent(endpoint.path), resolvingAgainstBaseURL: false)
        if !endpoint.queries.isEmpty {
            url?.queryItems = endpoint.queries.compactMap({ item in
                return URLQueryItem(name: item.key, value: item.value)
            })
        }
        
        var request = URLRequest(url: (url?.url) ?? endpoint.baseURL.appendingPathComponent(endpoint.path),
                                 cachePolicy: .reloadIgnoringLocalAndRemoteCacheData,
                                 timeoutInterval: 60.0)
        
        request.allHTTPHeaderFields = endpoint.httpHeaders.value
        request.httpMethod = endpoint.httpMethod.rawValue
        
        do {
            switch endpoint.httpTask {
            case .request: break
            case .requestParameters(let parameters,
                                    let encoding):
                
                try configureParameters(parameters: parameters,
                                        encoding: encoding,
                                        request: &request)
            }
            return request
        } catch {
            throw error
        }
    }
    
    private func configureParameters(parameters: Parameters?, encoding: ParameterEncoding, request: inout URLRequest) throws {
        try encoding.encode(urlRequest: &request, parameters: parameters)
    }
    
    // MARK: - Base Request Trigger!!
    
    func retreiveWithoutCallback() {
        let router = Router<Self>()
        router.request(self)
    }
    
    func retrieveWithProgress<T: Codable>(_ success: @escaping (T?) -> Void, failure: ((ErrorPair?) -> Void)? = nil) {
        HUD.show(.progress)
        retrieve({ (response: T?) in
            HUD.hide(animated: false)
            success(response)
        }) { (error) in
            HUD.hide(animated: false)
            if let failure = failure {
                failure(error)
            } else {
                showAlert(withTitle: "Hata".localized,
                          message: error?.message,
                          showCloseIcon: true,
                          shouldDismissWhenTappedAround: true)
            }
        }
    }
    
    func retrieve<T: Codable>(_ success: @escaping (T?) -> Void, failure: ((ErrorPair?) -> Void)? = nil) {
        let router = Router<Self>()

        router.request(self) { (response: Result<ResponseData<T>, BError>) in
            self.requestCompleted()
            
            switch response {
            case .success(let successModel):
                if (successModel.success)~ {
                    success(successModel.data)
                } else {
                    let message = successModel.errors?.joined(separator: "\n")
                    if let failure = failure {
                        failure(ErrorPair(code: successModel.code, message: message))
                    } else {
                        handleFailure(error: successModel.errors)
                    }
                }
                
                if let message = successModel.message {
                    getMessage?(message)
                }
                    
            case .failure(let error):
                self.handleFailure(error: error, failure: failure)
            }
        }
    }
    
    func retrieveWithCleanResponse<T: Codable>(_ success: @escaping (T?) -> Void) {
        let router = Router<Self>()

        router.request(self) { (response: Result<T, BError>) in
            self.requestCompleted()
            
            switch response {
            case .success(let successModel):
                success(successModel)
            case .failure(_):
                break
            }
        }
    }

    private func handleFailure(error: [String]?, failure: ((ErrorPair?) -> Void)? = nil) {
        guard let error = error else { return }
        let message = error.joined(separator: "\n")
            showAlert(withTitle: "Hata".localized,
                      message: message,
                      showCloseIcon: true,
                      shouldDismissWhenTappedAround: true)
            return
    }
    
    private func handleFailure(error: BError, failure: ((ErrorPair?) -> Void)? = nil) {
        if case BError.authentication = error {
            let doneAction = DesignatedAlertActions.doneActionWithHandler {
                NetworkCommunicationManager.shared.logout?()
            }.action
            showAlert(withTitle: "Hata".localized,
                      message: "Uzun süredir işlem yapmadığınız için oturumunuz sonlandırılmıştır.".localized,
                      actions: [doneAction])
            return
        }
        if let failure = failure {
            failure(ErrorPair.messaged(with: error.localizedDescription))
        } else {
            let doneAction = DesignatedAlertActions.doneAction.action
            showAlert(withTitle: "Hata".localized, message: error.errorDescription, actions: [doneAction])
        }
    }
    
}
