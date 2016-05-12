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
@_exported import PathParameterMiddleware

public struct RegexRouteMatcher: RouteMatcher {
    public let routes: [Route]
    let regexRoutes: [RegexRoute]

    public init(routes: [Route]) {
        self.routes = routes
        self.regexRoutes = routes.map(RegexRoute.init)
    }

    public func match(_ request: Request) -> Route? {
        for regexRoute in regexRoutes  {
            if regexRoute.matches(request) {
                let parameters = regexRoute.parameters(request)
                let parametersMiddleware = PathParameterMiddleware(parameters)

                return BasicRoute(
                    path: regexRoute.route.path,
                    actions: regexRoute.route.actions.mapValues({parametersMiddleware.chain(to: $0)}),
                    fallback: regexRoute.route.fallback
                )
            }
        }
        return nil
    }
}

struct RegexRoute {
    let regex: Regex
    let parameterKeys: [String]
    let route: Route

    init(route: Route) {
        let parameterRegularExpression = try! Regex(pattern: ":([[:alnum:]]+)")
        let pattern = parameterRegularExpression.replace(route.path, withTemplate: "([[:alnum:]_-]+)")

        self.regex = try! Regex(pattern: "^" + pattern + "$")
        self.parameterKeys = parameterRegularExpression.groups(route.path)
        self.route = route
    }

    func matches(_ request: Request) -> Bool {
        guard let path = request.path else {
            return false
        }
        return regex.matches(path)
    }

    func parameters(_ request: Request) -> [String: String] {
        guard let path = request.path else {
            return [:]
        }

        var parameters: [String: String] = [:]

        let values = regex.groups(path)

        for (index, key) in parameterKeys.enumerated() {
            parameters[key] = values[index]
        }

        return parameters
    }
}

extension Dictionary {
    func mapValues<T>(_ transform: (Value) -> T) -> [Key: T] {
        var dictionary: [Key: T] = [:]

        for (key, value) in self {
            dictionary[key] = transform(value)
        }

        return dictionary
    }
}