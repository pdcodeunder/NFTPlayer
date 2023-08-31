//
//  SafeLock.swift
//  NFTPlayer
//
//  Created by 彭懂 on 2023/8/31.
//

import Foundation
fileprivate protocol Protector {
    func readLock()
    func readUnlock()
    
    func writeLock()
    func writeUnlock()
}

extension Protector {
    func arroundToWrite<T>(_ closure: () throws -> T) rethrows -> T {
        writeLock(); defer { writeUnlock() };
        return try closure()
    }
    
    func arroundToWrite(_ closure: () throws -> ()) rethrows {
        writeLock(); defer { writeUnlock() };
        try closure()
    }

    func arroundToRead<T>(_ closure: () throws -> T) rethrows -> T {
        readLock(); defer { readUnlock() };
        return try closure()
    }
    
    func arroundToRead(_ closure: () throws -> ()) rethrows {
        readLock(); defer { readUnlock() };
        try closure()
    }
}

fileprivate final class UnfairLock: Protector {
    private let unfairLock: os_unfair_lock_t
    
    init() {
        self.unfairLock = .allocate(capacity: 1)
        self.unfairLock.initialize(to: os_unfair_lock())
    }
    
    deinit {
        self.unfairLock.deinitialize(count: 1)
        self.unfairLock.deallocate()
    }
    
    @inline(__always)
    private func generalLock() {
        os_unfair_lock_lock(self.unfairLock)
    }
    
    @inline(__always)
    private func generalUnlock() {
        os_unfair_lock_unlock(self.unfairLock)
    }
    
    fileprivate func readLock() { self.generalLock() }
    fileprivate func writeLock() { self.generalLock() }
    
    fileprivate func readUnlock() { self.generalUnlock() }
    fileprivate func writeUnlock() { self.generalUnlock() }
}

@propertyWrapper
@dynamicMemberLookup
class SafeLock<T> {
    private let lock = UnfairLock()
    
    private var value: T
    
    public
    init(_ value: T) {
        self.value = value
    }
    
    public
    init(wrappedValue: T) {
        self.value = wrappedValue
    }
    
    public
    var wrappedValue: T {
        get { lock.arroundToRead { self.value } }
        set { lock.arroundToWrite { self.value = newValue } }
    }
    
    public
    var projectedValue: SafeLock<T> { self }
    
    public
    func read<U>(_ closure: (T) throws -> U) rethrows -> U {
        try lock.arroundToRead { try closure(self.value) }
    }
    
    @discardableResult
    public
    func write<U>(_ closure: (inout T) throws -> U) rethrows -> U {
        try lock.arroundToWrite { try closure(&self.value) }
    }
    
    public
    subscript<Prop>(dynamicMember keyPath: WritableKeyPath<T, Prop>) -> Prop {
        get { lock.arroundToRead { self.value[keyPath: keyPath] } }
        set { lock.arroundToWrite { self.value[keyPath: keyPath] = newValue } }
    }
}
