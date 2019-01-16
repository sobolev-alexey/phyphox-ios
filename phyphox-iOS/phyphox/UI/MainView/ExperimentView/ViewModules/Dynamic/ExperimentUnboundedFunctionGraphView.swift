//
//  ExperimentUnboundedFunctionGraphView.swift
//  phyphox
//
//  Created by Jonas Gessner on 07.03.18.
//  Copyright © 2018 RWTH Aachen. All rights reserved.
//

import UIKit

private let maxPoints = 3000

/**
 Graph view used to display functions (where each x value is is related to exactly one y value) where the stream of incoming x values is in ascending order (descriptor.partialUpdate = true on the view descriptor) and no values are deleted (inputBuffer sizes are 0). The displayed history also has to be 1 (descriptor.history = 1).
 */
final class ExperimentUnboundedFunctionGraphView: UIView, DynamicViewModule, ResizableViewModule, DescriptorBoundViewModule, GraphViewModule {
    let descriptor: GraphViewDescriptor
    
    var layoutDelegate: ModuleExclusiveLayoutDelegate? = nil
    var resizableState: ResizableViewModuleState = .normal

    private let displayLink = DisplayLink(refreshRate: 0)

    var active = false {
        didSet {
            if active {
                setNeedsUpdate()
            }
        }
    }

    private let queue = DispatchQueue(label: "de.rwth-aachen.phyphox.graphview", qos: .userInitiated, attributes: [], autoreleaseFrequency: .inherit, target: nil)

    private let xLabel: UILabel
    private let yLabel: UILabel

    private let glGraph: GLRangedPointGraphView
    private let gridView: GraphGridView

    private let label = UILabel()

    required init?(descriptor: GraphViewDescriptor) {
        guard descriptor.partialUpdate && descriptor.history == 1 && descriptor.yInputBuffer.size == 0 && (descriptor.xInputBuffer?.size ?? 0) == 0 else { return nil }

        self.descriptor = descriptor
        
        var r: CGFloat = 0.0, g: CGFloat = 0.0, b: CGFloat = 0.0, a: CGFloat = 0.0

        descriptor.color.getRed(&r, green: &g, blue: &b, alpha: &a)
        let lineColor = GLcolor(r: Float(r), g: Float(g), b: Float(b), a: Float(a))

        glGraph = GLRangedPointGraphView(drawDots: descriptor.drawDots, lineWidth: GLfloat(descriptor.lineWidth * (descriptor.drawDots ? 4.0 : 2.0)), lineColor: lineColor, maximumPointCount: maxPoints)
        glGraph.singlePointMode = true

        gridView = GraphGridView(descriptor: descriptor)
        gridView.gridInset = CGPoint(x: 2.0, y: 2.0)
        gridView.gridOffset = CGPoint(x: 0.0, y: 0.0)

        mainPointCollection = PointCollection(logX: descriptor.logX, logY: descriptor.logY)

        func makeLabel(_ text: String?) -> UILabel {
            let l = UILabel()
            l.text = text

            let defaultFont = UIFont.preferredFont(forTextStyle: .body)
            l.font = defaultFont.withSize(defaultFont.pointSize * 0.8)

            return l
        }

        label.numberOfLines = 0
        label.text = descriptor.localizedLabel
        label.font = UIFont.preferredFont(forTextStyle: .body)
        label.textColor = kTextColor

        xLabel = makeLabel(descriptor.localizedXLabel)
        yLabel = makeLabel(descriptor.localizedYLabel)
        xLabel.textColor = kTextColor
        yLabel.textColor = kTextColor

        yLabel.transform = CGAffineTransform(rotationAngle: -.pi/2.0)

        super.init(frame: .zero)

        displayLink.active = true
        
        gridView.delegate = self

        addSubview(label)
        addSubview(gridView)
        addSubview(glGraph)
        addSubview(xLabel)
        addSubview(yLabel)

        registerForUpdatesFromBuffer(descriptor.yInputBuffer)
        if let xBuffer = descriptor.xInputBuffer {
            registerForUpdatesFromBuffer(xBuffer)
        }

        attachDisplayLink(displayLink)
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(ExperimentGraphView.tapped(_:)))
        self.addGestureRecognizer(tapGesture)
    }
    
    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc func tapped(_ sender: UITapGestureRecognizer) {
        if resizableState == .normal {
            layoutDelegate?.presentExclusiveLayout(self)
        } else {
            layoutDelegate?.restoreLayout()
        }
    }

    func registerForUpdatesFromBuffer(_ buffer: DataBuffer) {
        buffer.addObserver(self, alwaysNotify: true)
    }

    private var mainPointCollection: PointCollection

    private func runUpdate() {
        let previousCount = mainPointCollection.representedPointCount

        var xValues: [Double]
        let yValues = descriptor.yInputBuffer.toArray()

        var xCount: Int
        let yCount = descriptor.yInputBuffer.count

        var count = yCount

        if let xBuffer = descriptor.xInputBuffer {
            xValues = xBuffer.toArray()
            xCount = xBuffer.count

            count = Swift.min(xCount, count)
        }
        else {
            // FIXME: Reuse x values
            xValues = stride(from: 0, to: count, by: 1).map(Double.init)
            xCount = count
        }

        guard count > 0 else {
            mainThread {
                self.clearData()
            }
            return
        }

        let addedCount = count - previousCount

        guard addedCount != 0 else { return }

        if addedCount < 0 {
            guard count <= descriptor.yInputBuffer.memoryCount else {
                print("Attempted to update unbounded function graph with added count > inout buffer memory size. Stopping plotting.")
                return
            }

            mainPointCollection.removeAll()
        }

        guard addedCount <= descriptor.yInputBuffer.memoryCount else {
            print("Attempted to update unbounded function graph with added count > inout buffer memory size. Stopping plotting.")
            return

        }

        if let xBuffer = descriptor.xInputBuffer {
            guard addedCount <= xBuffer.memoryCount else {
                print("Attempted to update unbounded function graph with added count > inout buffer memory size. Stopping plotting.")
                return
            }
        }

        // FIXME: negative addedCount
        let xStartIndex = xValues.count - addedCount - (xCount - count)
        let addedXValues = xValues[xStartIndex..<(xStartIndex + addedCount)]

        let yStartIndex = yValues.count - addedCount - (yCount - count)
        let addedYValues = yValues[yStartIndex..<(yStartIndex + addedCount)]

        let zipped = zip(addedXValues, addedYValues)

        let before = mainPointCollection.representedPointCount
        let (replacedPointCount, addedPointCount) = mainPointCollection.append(zipped)
        assert(before + addedCount == mainPointCollection.representedPointCount)

        let logX = descriptor.logX
        let logY = descriptor.logY

        let strideIncreaseFactor = mainPointCollection.count / (maxPoints / 2)

        let replacedAll: Bool

        if strideIncreaseFactor > 1 {
            replacedAll = true

            let before = mainPointCollection.representedPointCount
            mainPointCollection.factorStride(by: strideIncreaseFactor)
            assert(before == mainPointCollection.representedPointCount)

            self.glGraph.singlePointMode = false
        }
        else {
            replacedAll = false
        }

        let min = GraphPoint(x: Double(mainPointCollection.minX), y: Double(mainPointCollection.minY))
        let max = GraphPoint(x: Double(mainPointCollection.maxX), y: Double(mainPointCollection.maxY))

        if replacedAll {
            glGraph.setPoints(mainPointCollection.points, min: min, max: max)
        }
        else {
            let appendingPoints = mainPointCollection.points.suffix(addedPointCount + replacedPointCount)
            glGraph.appendPoints(appendingPoints, replace: replacedPointCount, min: min, max: max)
        }

        guard active else { return }

        self.glGraph.display()

        let grid = generateGrid(logX: logX, logY: logY)

        mainThread {
            self.gridView.grid = grid
        }
    }

    private func generateGrid(logX: Bool, logY: Bool) -> GraphGrid {
        let min = GraphPoint(x: Double(mainPointCollection.minX), y: Double(mainPointCollection.minY))
        let max = GraphPoint(x: Double(mainPointCollection.maxX), y: Double(mainPointCollection.maxY))

        let rangeX = max.x - min.x
        let rangeY = max.y - min.y

        let xTicks = ExperimentGraphUtilities.getTicks(min.x, max: max.x, maxTicks: 6, log: logX)
        let yTicks = ExperimentGraphUtilities.getTicks(min.y, max: max.y, maxTicks: 6, log: logY)

        let mappedXTicks = xTicks.map({ (val) -> GraphGridLine in
            return GraphGridLine(absoluteValue: val, relativeValue: CGFloat(((logX ? log(val) : val) - min.x) / rangeX))
        })

        let mappedYTicks = yTicks.map({ (val) -> GraphGridLine in
            return GraphGridLine(absoluteValue: val, relativeValue: CGFloat(((logY ? log(val) : val) - min.y) / rangeY))
        })

        return GraphGrid(xGridLines: mappedXTicks, yGridLines: mappedYTicks)
    }

    private var wantsUpdate = false

    func setNeedsUpdate() {
        wantsUpdate = true
    }

    private var busy = false

    private func update() {
        guard !busy else { return }
        busy = true
        wantsUpdate = false
        
        queue.async { [weak self] in
            autoreleasepool {
                self?.runUpdate()
                self?.busy = false
            }
        }
    }

    func clearData() {
        mainPointCollection.removeAll()

        gridView.grid = nil

        glGraph.setPoints([], min: .zero, max: .zero)
        glGraph.display()
    }

    //Mark - General UI

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        switch resizableState {
        case .exclusive:
            return size
        case .hidden:
            return CGSize.init(width: 0, height: 0)
        default:
            let s1 = label.sizeThatFits(bounds.size)

            return CGSize(width: size.width, height: Swift.min(size.width/descriptor.aspectRatio + s1.height + 1.0, size.height))
        }
    }

    private var graphFrame: CGRect {
        return gridView.insetRect.offsetBy(dx: gridView.frame.origin.x, dy: gridView.frame.origin.y).integral
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        label.isHidden = resizableState == .hidden
        xLabel.isHidden = resizableState == .hidden
        yLabel.isHidden = resizableState == .hidden
        gridView.isHidden = resizableState == .hidden
        glGraph.isHidden = resizableState == .hidden
        
        if (resizableState == .hidden) {
            return
        }
        
        let spacing: CGFloat = 1.0

        let s1 = label.sizeThatFits(bounds.size)
        label.frame = CGRect(x: (bounds.size.width-s1.width)/2.0, y: spacing, width: s1.width, height: s1.height)

        let s2 = xLabel.sizeThatFits(bounds.size)
        xLabel.frame = CGRect(x: (bounds.size.width-s2.width)/2.0, y: bounds.size.height-s2.height-spacing, width: s2.width, height: s2.height)

        let s3 = yLabel.sizeThatFits(bounds.size).applying(yLabel.transform)

        gridView.frame = CGRect(x: s3.width + spacing, y: s1.height+spacing, width: bounds.size.width - s3.width - 2*spacing, height: bounds.size.height - s1.height - s2.height - 2*spacing)

        yLabel.frame = CGRect(x: spacing, y: graphFrame.origin.y+(graphFrame.size.height-s3.height)/2.0, width: s3.width, height: s3.height)
        
        updatePlotArea()
    }
}

extension ExperimentUnboundedFunctionGraphView: GraphGridDelegate {
    func updatePlotArea() {
        if (glGraph.frame != graphFrame) {
            glGraph.frame = graphFrame
            glGraph.setNeedsLayout()
        }
    }
}

extension ExperimentUnboundedFunctionGraphView: DisplayLinkListener {
    func display(_ displayLink: DisplayLink) {
        if wantsUpdate {
            update()
        }
    }
}
