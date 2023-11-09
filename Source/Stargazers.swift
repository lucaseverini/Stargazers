//
//  Stargazers.swift
//  Stargazers
//
//  Created by Luca Severini on 14-Aug-2021.
//  lucaseverini@mac.com
//

import UIKit


class Stargazer: CustomStringConvertible // Or use NSObject
{
    let name: String!
    let avatarUrl: URL!
    var avatarError: Bool!
    var avatarImage: UIImage?

    init(_ user: String!, avatar: String)
    {
        name = user
        avatarUrl = URL(string: avatar) ?? nil
        avatarError = false
        avatarImage = nil
    }

    var description: String
    {
        return "\(name!) \((avatarUrl ?? nil)!) \(printPtr(obj: avatarImage))"
    }
}

extension DefaultStringInterpolation
{
    mutating func appendInterpolation<T>(_ optional: T?)
    {
        appendInterpolation(String(describing: optional))
    }
}

func printPtr<T : AnyObject>(obj : T?) -> String
{
    if obj != nil
    {
        return "\(UnsafeRawPointer(Unmanaged.passUnretained(obj!).toOpaque()))"
    }
    else
    {
        return "(nil)"
    }
}
