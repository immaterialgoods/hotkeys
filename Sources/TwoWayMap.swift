//
//  TwoWayMap.swift
//  Hotkeys
//
//  Created by Andreas Schwarz on 12/30/19.
//  Two-way map code thanks to Jose Canepa // CanTheAlmighty
//  https://gist.github.com/CanTheAlmighty
//

import Foundation

internal struct TwoWayMap<S:Hashable,T:Hashable> : ExpressibleByDictionaryLiteral {
    // Literal convertible
    typealias Key   = S
    typealias Value = T
    
    // Real storage
    private var st : [S : T] = [:]
    private var ts : [T : S] = [:]
    
    init(leftRight st : [S:T]) {
        var ts : [T:S] = [:]
        
        for (key,value) in st {
            ts[value] = key
        }
        
        self.st = st
        self.ts = ts
    }
    
    init(rightLeft ts : [T:S]) {
        var st : [S:T] = [:]
        
        for (key,value) in ts {
            st[value] = key
        }
        
        self.st = st
        self.ts = ts
    }
    
    init(dictionaryLiteral elements: (Key, Value)...) {
        for element in elements {
            st[element.0] = element.1
            ts[element.1] = element.0
        }
    }
    
    init() { }
    
    subscript(key : S) -> T? {
        get {
            return st[key]
        }
        set(val) {
            if let val = val {
                st[key] = val
                ts[val] = key
            }
        }
    }
    
    subscript(key : T) -> S? {
        get {
            return ts[key]
        }
        set(val) {
            if let val = val {
                ts[key] = val
                st[val] = key
            }
        }
    }
}
