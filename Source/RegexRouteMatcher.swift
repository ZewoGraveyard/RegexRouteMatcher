// RegexRouteMatcher.swift
//
// The MIT License (MIT)
//
// Copyright (c) 2015 Zewo
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

@_exported import HTTP
@_exported import POSIXRegex

public struct RegexRouteMatcher: RouteMatcherType {
    public let routes: [RouteType]

    public init(routes: [RouteType]) {
        self.routes = routes.map(Route.init)
    }

    public func match(request: Request) -> RouteType? {
        for route in routes  {
            let regexRoute = route as! Route
            if regexRoute.matches(request) {
                return route
            }
        }
        return nil
    }
}

struct Route: RouteType {
    let path: String
    let actions: [Method: Action]
    let fallback: Action

    private let regex: Regex

    init(route: RouteType) {
        let parameterRegularExpression = try! Regex(pattern: ":([[:alnum:]]+)")
        let pattern = parameterRegularExpression.replace(route.path, withTemplate: "([[:alnum:]_-]+)")

        let parameterKeys = parameterRegularExpression.groups(route.path)
        let regex = try! Regex(pattern: "^" + pattern + "$")

        self.path = route.path
        self.actions = route.actions.mapValues { action in
            Action(
                middleware: action.middleware,
                responder: Responder { request in
                    var request = request

                    guard let path = request.path else {
                        return Response(status: .BadRequest)
                    }

                    let values = regex.groups(path)
                    request.pathParameters = [:]

                    for (index, key) in parameterKeys.enumerate() {
                        request.pathParameters[key] = values[index]
                    }

                    return try action.responder.respond(request)
                }
            )
        }
        self.fallback = route.fallback
        self.regex = regex
    }
    
    func matches(request: Request) -> Bool {
        guard let path = request.uri.path else {
            return false
        }
        return regex.matches(path)
    }
}

extension Dictionary {
    init<S: SequenceType where S.Generator.Element == Element>(_ sequence: S) {
        self.init()
        for (key, value) in sequence {
            self[key] = value
        }
    }

    func mapValues<T>(transform: Value -> T) -> Dictionary<Key, T> {
        return Dictionary<Key, T>(zip(keys, values.map(transform)))
    }
}