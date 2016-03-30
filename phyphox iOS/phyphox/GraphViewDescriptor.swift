//
//  GraphViewDescriptor.swift
//  phyphox
//
//  Created by Jonas Gessner on 12.12.15.
//  Copyright © 2015 RWTH Aachen. All rights reserved.
//

import Foundation


public final class GraphViewDescriptor: ViewDescriptor {
    private let xLabel: String
    private let yLabel: String
    
    var localizedXLabel: String {
        return translation?.localize(xLabel) ?? xLabel
    }
    
    var localizedYLabel: String {
        return translation?.localize(yLabel) ?? yLabel
    }
    
    let logX: Bool
    let logY: Bool
    
    var xInputBuffer: DataBuffer?
    var yInputBuffer: DataBuffer
    
    let aspectRatio: CGFloat
    let partialUpdate: Bool
    let drawDots: Bool
    let forceFullDataset: Bool
    let history: UInt
    
    init(label: String, translation: ExperimentTranslationCollection?, xLabel: String, yLabel: String, xInputBuffer: DataBuffer?, yInputBuffer: DataBuffer, logX: Bool, logY: Bool, aspectRatio: CGFloat, drawDots: Bool, partialUpdate: Bool, forceFullDataset: Bool, history: UInt) {
        self.xLabel = xLabel
        self.yLabel = yLabel
        
        self.logX = logX
        self.logY = logY
        
        self.xInputBuffer = xInputBuffer
        self.yInputBuffer = yInputBuffer
        
        self.aspectRatio = aspectRatio
        self.partialUpdate = partialUpdate
        self.drawDots = drawDots
        self.forceFullDataset = forceFullDataset
        self.history = history
        
        super.init(label: label, translation: translation)
    }
}