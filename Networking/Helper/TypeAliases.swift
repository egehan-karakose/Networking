//
//  TypeAliases.swift
//  Networking
//
//  Created by Egehan Karaköse on 17.04.2023.
//

import Foundation
import Common

public typealias VoidHandler = (() -> Void)
public typealias Parameters = [String: Any]
public typealias StringHandler = ((String) -> Void)


public var token: String {
    (System.shared.getToken())~
}
