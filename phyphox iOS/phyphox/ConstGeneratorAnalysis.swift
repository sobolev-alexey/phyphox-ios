//
//  ConstGeneratorAnalysis.swift
//  phyphox
//
//  Created by Jonas Gessner on 06.12.15.
//  Copyright © 2015 RWTH Aachen. All rights reserved.
//

import Foundation

final class ConstGeneratorAnalysis: ExperimentAnalysisModule {
    
    override func update() {
        var value: Double = 0
        var length: Int = 0
        
        for input in inputs {
            if input.asString == "value" {
                if let v = input.getSingleValue() {
                    value = v
                }
                else {
                    return
                }
            }
            else if input.asString == "length" {
                if let v = input.getSingleValue() {
                    length = Int(v)
                }
                else {
                    return
                }
            }
            else {
                print("Error: Invalid analysis input: \(input.asString)")
            }
        }
        
        let outBuffer = outputs.first!.buffer!
        
        if length == 0 {
            length = outBuffer.size
        }
        
        #if DEBUG_ANALYSIS
            debug_noteInputs(["value" : value, "length" : length])
        #endif
        
        let append = [Double](count: length, repeatedValue: value)
        
        #if DEBUG_ANALYSIS
            debug_noteOutputs(append)
        #endif
        
        outBuffer.replaceValues(append)
    }
}