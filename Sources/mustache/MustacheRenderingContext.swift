//
//  MustacheRenderingContext.swift
//  Noze.io
//
//  Created by Helge Heß on 6/7/16.
//  Copyright © 2016 ZeeZide GmbH. All rights reserved.
//

public typealias MustacheRenderingFunction =
    ( String, ( String ) -> String ) -> String
public typealias MustacheSimpleRenderingFunction = ( String ) -> String

public protocol MustacheRenderingContext {

    // MARK: - Content Generation

    var string : String { get }
    func append(string s: String)

    // MARK: - Cursor

    var cursor : Any? { get }
    func enter(scope ctx: Any?)
    func leave()

    // MARK: - Value

    func value(forTag tag: String) -> Any?

    // MARK: - Lambda Context (same stack, empty String)

    func newLambdaContext() -> MustacheRenderingContext

    // MARK: - Partials

    func retrievePartial(name n: String, basePath p: String?) -> MustacheNode?
}

public extension MustacheRenderingContext {

    func value(forTag tag: String) -> Any? {
        return KeyValueCoding.value(forKeyPath: tag, inObject: cursor)
    }

    func retrievePartial(name n: String, basePath p: String?) -> MustacheNode? {
        return nil
    }
}

open class MustacheDefaultRenderingContext : MustacheRenderingContext {

    public var string : String = ""
    public var stack  = [ Any? ]() // #linux-public
    public var fileExt = ".mustache"


    public init(_ root: Any?) {
        if let a = root {
            stack.append(a)
        }
    }
    public init(context: MustacheDefaultRenderingContext) {
        stack = context.stack
    }


    // MARK: - Content Generation

    public func append(string s: String) {
        string += s
    }


    // MARK: - Cursor

    public func enter(scope ctx: Any?) {
        stack.append(ctx)
    }
    public func leave() {
        _ = stack.removeLast()
    }

    public var cursor : Any? {
        guard let last = stack.last else { return nil }
        return last
    }


    // MARK: - Value

    open func value(forTag tag: String) -> Any? {
        let check = stack.reversed()
        for c in check {
            if let v = KeyValueCoding.value(forKeyPath: tag, inObject: c) {
                return v
            }
        }

        return nil
    }


    // MARK: - Lambda Context (same stack, empty String)

    open func newLambdaContext() -> MustacheRenderingContext {
        return MustacheDefaultRenderingContext(context: self)
    }


    // MARK: - Partials

    open func retrievePartial(name n: String, basePath p: String?) -> MustacheNode? {
        let ns = n.hasSuffix(fileExt) ? n : n + fileExt
        guard let basePath = p else {
            return nil
        }
        guard let partialPath = lookupPath(for: ns, basePath: basePath) else {
            print("could not locate partial: \(n)")
            return nil
        }

        guard let template = readTemplateSync(partialPath, "utf8") else {
            print("could not load partial: \((n, partialPath))")
            return nil
        }

        let parser = MustacheParser(basePath: p)
        let tree   = parser.parse(string: template)
        return tree
    }

    func lookupPath(for name: String, basePath path: String) -> String? {
        // TODO: proper fsname funcs
        // TODO: it would be nice to recurse upwards, but we need a point where to
        //       stop.
        return path + "/" + name
    }
}

private extension MustacheRenderingContext {
    func readTemplateSync(_ path: String, _ enc: String) -> String? {
        // TODO: enc
        let enc = enc.lowercased()
        guard enc == "utf8" else { return nil }

        #if os(Linux) // Linux 3.0.2 compiles but doesn't have contentsOfFile ...
        let url  = Foundation.URL(fileURLWithPath: path)
        guard var data = try? Data(contentsOf: url) else { return nil }
        data.append(0) // 0 terminator
        return data.withUnsafeBytes { (ptr : UnsafePointer<UInt8>) -> String in
            return String(cString: ptr)
        }
        #else
        guard let s = try? String(contentsOfFile: path) else { return nil }
        return s
        #endif
    }
}
