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
    public let routes: [Route]
    public let regexRoutes: [(Route, RegexRoute)]

    public init(routes: [Route]) {
        self.regexRoutes = routes.map {
            let regexRoute = RegexRoute(route: $0)
            let route = Route(
                methods: regexRoute.route.methods,
                path: regexRoute.route.path,
                middleware: regexRoute.route.middleware,
                responder: regexRoute
            )
            return (route, regexRoute)
        }
        self.routes = regexRoutes.map({$0.0})
    }

    public func match(request: Request) -> Route? {
        for (route, regexRoute) in regexRoutes where regexRoute.matches(request) {
            return route
        }
        return nil
    }
}

public struct RegexRoute: ResponderType {
    public let route: Route
    private let parameterKeys: [String]
    private let regularExpression: Regex

    public init(route: Route) {
        self.route = route

        let parameterRegularExpression = try! Regex(pattern: ":([[:alnum:]]+)")
        let pattern = parameterRegularExpression.replace(route.path, withTemplate: "([[:alnum:]_-]+)")

        self.parameterKeys = parameterRegularExpression.groups(route.path)
        self.regularExpression = try! Regex(pattern: "^" + pattern + "$")
    }

    public func matches(request: Request) -> Bool {
        return regularExpression.matches(request.uri.path!) && route.methods.contains(request.method)
    }

    public func respond(request: Request) throws -> Response {
        var request = request

        guard let path = request.path else {
            return Response(status: .BadRequest)
        }

        let values = regularExpression.groups(path)

        request.pathParameters = [:]

        for (index, key) in parameterKeys.enumerate() {
            request.pathParameters[key] = values[index]
        }

        return try route.responder.respond(request)
    }
}
