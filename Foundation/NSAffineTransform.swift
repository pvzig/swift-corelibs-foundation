// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2016 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See http://swift.org/LICENSE.txt for license information
// See http://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//

#if os(OSX) || os(iOS)
    import Darwin
#elseif os(Linux) || CYGWIN
    import Glibc
#endif

private let ε: CGFloat = CGFloat(2.22045e-16)


/**
 AffineTransform represents an affine transformation matrix of the following form:

 [ m11  m12  0 ]
 [ m21  m22  0 ]
 [  tX   tY  1 ]
 */
public struct AffineTransform : ReferenceConvertible, Hashable, CustomStringConvertible {
    public typealias ReferenceType = NSAffineTransform

    public var m11: CGFloat
    public var m12: CGFloat
    public var m21: CGFloat
    public var m22: CGFloat
    public var tX: CGFloat
    public var tY: CGFloat
    
    public init() {
        self.init(m11: CGFloat(), m12: CGFloat(), m21: CGFloat(), m22: CGFloat(), tX: CGFloat(), tY: CGFloat())
    }
    public init(m11: CGFloat, m12: CGFloat, m21: CGFloat, m22: CGFloat, tX: CGFloat, tY: CGFloat) {
        (self.m11, self.m12, self.m21, self.m22) = (m11, m12, m21, m22)
        (self.tX, self.tY) = (tX, tY)
    }

    private init(reference: NSAffineTransform) {
        self = reference.transformStruct
    }

    private var reference : NSAffineTransform {
        let ref = NSAffineTransform()
        ref.transformStruct = self
        return ref
    }

    /**
     Creates an affine transformation matrix from translation values.
     The matrix takes the following form:

     [ 1  0  0 ]
     [ 0  1  0 ]
     [ x  y  1 ]
     */
    public init(translationByX x: CGFloat, byY y: CGFloat) {
        self.init(m11: CGFloat(1.0), m12: CGFloat(0.0),
                  m21: CGFloat(0.0), m22: CGFloat(1.0),
                  tX: x,             tY: y)
    }

    /**
     Creates an affine transformation matrix from scaling values.
     The matrix takes the following form:

     [ x  0  0 ]
     [ 0  y  0 ]
     [ 0  0  1 ]
     */
    public init(scaleByX x: CGFloat, byY y: CGFloat) {
        self.init(m11: x,            m12: CGFloat(0.0),
                  m21: CGFloat(0.0), m22: y,
                  tX: CGFloat(0.0),  tY: CGFloat(0.0))
    }

    /**
     Creates an affine transformation matrix from scaling a single value.
     The matrix takes the following form:

     [ f  0  0 ]
     [ 0  f  0 ]
     [ 0  0  1 ]
     */
    public init(scale factor: CGFloat) {
        self.init(scaleByX: factor, byY: factor)
    }

    /**
     Creates an affine transformation matrix from rotation value (angle in radians).
     The matrix takes the following form:

     [  cos α   sin α  0 ]
     [ -sin α   cos α  0 ]
     [    0       0    1 ]
     */
    public init(rotationByRadians angle: CGFloat) {
        let sine = sin(angle)
        let cosine = cos(angle)

        self.init(m11: cosine, m12: sine, m21: -sine, m22: cosine, tX: CGFloat(0.0), tY: CGFloat(0.0))
    }

    /**
     Creates an affine transformation matrix from a rotation value (angle in degrees).
     The matrix takes the following form:

     [  cos α   sin α  0 ]
     [ -sin α   cos α  0 ]
     [    0       0    1 ]
     */
    public init(rotationByDegrees angle: CGFloat) {
        let α = angle * .pi / 180.0
        self.init(rotationByRadians: α)
    }

    /**
     An identity affine transformation matrix

     [ 1  0  0 ]
     [ 0  1  0 ]
     [ 0  0  1 ]
     */
    public static let identity = AffineTransform(m11: CGFloat(1.0), m12: CGFloat(0.0), m21: CGFloat(0.0), m22: CGFloat(1.0), tX: CGFloat(0.0), tY: CGFloat(0.0))

    // Translating
    public mutating func translate(x: CGFloat, y: CGFloat) {
        tX += m11 * x + m21 * y
        tY += m12 * x + m22 * y
    }

    /**
     Mutates an affine transformation matrix from a rotation value (angle α in degrees).
     The matrix takes the following form:

     [  cos α   sin α  0 ]
     [ -sin α   cos α  0 ]
     [    0       0    1 ]
     */
    public mutating func rotate(byDegrees angle: CGFloat) {
        let α = angle * .pi / 180.0
        return rotate(byRadians: α)
    }

    /**
     Mutates an affine transformation matrix from a rotation value (angle α in radians).
     The matrix takes the following form:

     [  cos α   sin α  0 ]
     [ -sin α   cos α  0 ]
     [    0       0    1 ]
     */
    public mutating func rotate(byRadians angle: CGFloat) {
        let sine = sin(angle)
        let cosine = cos(angle)

        m11 = cosine
        m12 = sine
        m21 = -sine
        m22 = cosine
    }

    /**
     Creates an affine transformation matrix by combining the receiver with `transformStruct`.
     That is, it computes `T * M` and returns the result, where `T` is the receiver's and `M` is
     the `transformStruct`'s affine transformation matrix.
     The resulting matrix takes the following form:

     [ m11_T  m12_T  0 ] [ m11_M  m12_M  0 ]
     T * M = [ m21_T  m22_T  0 ] [ m21_M  m22_M  0 ]
     [  tX_T   tY_T  1 ] [  tX_M   tY_M  1 ]
     
     [    (m11_T*m11_M + m12_T*m21_M)       (m11_T*m12_M + m12_T*m22_M)    0 ]
     = [    (m21_T*m11_M + m22_T*m21_M)       (m21_T*m12_M + m22_T*m22_M)    0 ]
     [ (tX_T*m11_M + tY_T*m21_M + tX_M)  (tX_T*m12_M + tY_T*m22_M + tY_M)  1 ]
     */
    internal func concatenated(_ other: AffineTransform) -> AffineTransform {
        let (t, m) = (self, other)
        
        // this could be optimized with a vector version
        return AffineTransform(
            m11: (t.m11 * m.m11) + (t.m12 * m.m21), m12: (t.m11 * m.m12) + (t.m12 * m.m22),
            m21: (t.m21 * m.m11) + (t.m22 * m.m21), m22: (t.m21 * m.m12) + (t.m22 * m.m22),
            tX: (t.tX * m.m11) + (t.tY * m.m21) + m.tX,
            tY: (t.tX * m.m12) + (t.tY * m.m22) + m.tY
        )
    }

    // Scaling
    public mutating func scale(_ scale: CGFloat) {
        self.scale(x: scale, y: scale)
    }

    public mutating func scale(x: CGFloat, y: CGFloat) {
        m11 = CGFloat(m11.native * x.native)
        m12 = CGFloat(m12.native * x.native)
        m21 = CGFloat(m21.native * y.native)
        m22 = CGFloat(m22.native * y.native)
    }

    /**
     Inverts the transformation matrix if possible. Matrices with a determinant that is less than
     the smallest valid representation of a double value greater than zero are considered to be
     invalid for representing as an inverse. If the input AffineTransform can potentially fall into
     this case then the inverted() method is suggested to be used instead since that will return
     an optional value that will be nil in the case that the matrix cannot be inverted.

     D = (m11 * m22) - (m12 * m21)

     D < ε the inverse is undefined and will be nil
     */
    public mutating func invert() {
        guard let inverse = inverted() else {
            fatalError("Transform has no inverse")
        }
        self = inverse
    }

    public func inverted() -> AffineTransform? {
        let determinant = (m11 * m22) - (m12 * m21)
        if fabs(determinant.native) <= ε.native {
            return nil
        }
        var inverse = AffineTransform()
        inverse.m11 = m22 / determinant
        inverse.m12 = -m12 / determinant
        inverse.m21 = -m21 / determinant
        inverse.m22 = m11 / determinant
        inverse.tX = (m21 * tY - m22 * tX) / determinant
        inverse.tY = (m12 * tX - m11 * tY) / determinant
        return inverse
    }

    // Transforming with transform
    public mutating func append(_ transform: AffineTransform) {
        self = concatenated(transform)
    }

    public mutating func prepend(_ transform: AffineTransform) {
        self = transform.concatenated(self)
    }

    // Transforming points and sizes
    public func transform(_ point: NSPoint) -> NSPoint {
        var newPoint = NSPoint()
        newPoint.x = (m11 * point.x) + (m21 * point.y) + tX
        newPoint.y = (m12 * point.x) + (m22 * point.y) + tY
        return newPoint
    }

    public func transform(_ size: NSSize) -> NSSize {
        var newSize = NSSize()
        newSize.width = (m11 * size.width) + (m21 * size.height)
        newSize.height = (m12 * size.width) + (m22 * size.height)
        return newSize
    }

    public var hashValue : Int {
        return Int((m11 + m12 + m21 + m22 + tX + tY).native)
    }

    public var description: String {
        return "{m11:\(m11), m12:\(m12), m21:\(m21), m22:\(m22), tX:\(tX), tY:\(tY)}"
    }

    public var debugDescription: String {
        return description
    }

    public static func ==(lhs: AffineTransform, rhs: AffineTransform) -> Bool {
        return lhs.m11 == rhs.m11 && lhs.m12 == rhs.m12 &&
            lhs.m21 == rhs.m21 && lhs.m22 == rhs.m22 &&
            lhs.tX == rhs.tX && lhs.tY == rhs.tY
    }
}

open class NSAffineTransform : NSObject, NSCopying, NSSecureCoding {
    
    open func encode(with aCoder: NSCoder) {
        NSUnimplemented()
    }
    open func copy(with zone: NSZone? = nil) -> Any {
        return NSAffineTransform(transform: self)
    }
    // Necessary because `NSObject.copy()` returns `self`.
    open override func copy() -> Any {
        return copy(with: nil)
    }
    public required init?(coder aDecoder: NSCoder) {
        NSUnimplemented()
    }
    public static var supportsSecureCoding: Bool {
        return true
    }
    
    // Initialization
    public convenience init(transform: NSAffineTransform) {
        self.init()
        transformStruct = transform.transformStruct
    }
    
    public override init() {
        transformStruct = AffineTransform(
            m11: CGFloat(1.0), m12: CGFloat(),
            m21: CGFloat(), m22: CGFloat(1.0),
            tX: CGFloat(), tY: CGFloat()
        )
    }
    
    // Translating
    open func translateX(by deltaX: CGFloat, yBy deltaY: CGFloat) {
        let translation = AffineTransform(translationByX: deltaX, byY: deltaY)
        transformStruct = translation.concatenated(transformStruct)
    }
    
    // Rotating
    open func rotate(byDegrees angle: CGFloat) {
        let rotation = AffineTransform(rotationByDegrees: angle)
        transformStruct = rotation.concatenated(transformStruct)
    }
    open func rotate(byRadians angle: CGFloat) {
        let rotation = AffineTransform(rotationByRadians: angle)
        transformStruct = rotation.concatenated(transformStruct)
    }
    
    // Scaling
    open func scale(by scale: CGFloat) {
        scaleX(by: scale, yBy: scale)
    }

    open func scaleX(by scaleX: CGFloat, yBy scaleY: CGFloat) {
        let scale = AffineTransform(scaleByX: scaleX, byY: scaleY)
        transformStruct = scale.concatenated(transformStruct)
    }
    
    // Inverting
    open func invert() {
        if let inverse = transformStruct.inverted() {
            transformStruct = inverse
        }
        else {
            preconditionFailure("NSAffineTransform: Transform has no inverse")
        }
    }
    
    // Transforming with transform
    open func append(_ transform: NSAffineTransform) {
        transformStruct = transformStruct.concatenated(transform.transformStruct)
    }
    open func prepend(_ transform: NSAffineTransform) {
        transformStruct = transform.transformStruct.concatenated(transformStruct)
    }
    
    // Transforming points and sizes
    open func transform(_ aPoint: NSPoint) -> NSPoint {
        return transformStruct.transform(aPoint)
    }

    open func transform(_ aSize: NSSize) -> NSSize {
        return transformStruct.transform(aSize)
    }

    // Transform Struct
    open var transformStruct: AffineTransform
}

extension AffineTransform : _ObjectTypeBridgeable {
    public static func _isBridgedToObjectiveC() -> Bool {
        return true
    }

    public static func _getObjectiveCType() -> Any.Type {
        return NSAffineTransform.self
    }

    @_semantics("convertToObjectiveC")
    public func _bridgeToObjectiveC() -> NSAffineTransform {
        let t = NSAffineTransform()
        t.transformStruct = self
        return t
    }

    public static func _forceBridgeFromObjectiveC(_ x: NSAffineTransform, result: inout AffineTransform?) {
        if !_conditionallyBridgeFromObjectiveC(x, result: &result) {
            fatalError("Unable to bridge type")
        }
    }

    public static func _conditionallyBridgeFromObjectiveC(_ x: NSAffineTransform, result: inout AffineTransform?) -> Bool {
        result = x.transformStruct
        return true // Can't fail
    }

    public static func _unconditionallyBridgeFromObjectiveC(_ x: NSAffineTransform?) -> AffineTransform {
        var result: AffineTransform?
        _forceBridgeFromObjectiveC(x!, result: &result)
        return result!
    }
}

extension NSAffineTransform : _StructTypeBridgeable {
    public typealias _StructType = AffineTransform
    
    public func _bridgeToSwift() -> AffineTransform {
        return AffineTransform._unconditionallyBridgeFromObjectiveC(self)
    }
}
