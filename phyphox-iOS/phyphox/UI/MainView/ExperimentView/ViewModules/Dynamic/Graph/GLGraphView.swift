//
//  GLGraphView.swift
//  phyphox
//
//  Created by Jonas Gessner on 21.03.16.
//  Copyright © 2016 Jonas Gessner. All rights reserved.
//

import UIKit
import GLKit
import OpenGLES

final class GLGraphView: GLKView {
    private let shader: GLGraphShaderProgram
    
    private var vbo: GLuint = 0

    // Values used to transform the input values on the xy Plane into NDCs.
    private var xScale: GLfloat = 1.0
    private var yScale: GLfloat = 1.0
    
    private var min = GraphPoint<Double>.zero
    private var max = GraphPoint<Double>.zero
    
    var lineWidth: [GLfloat] = [2.0] {
        didSet {
            setNeedsDisplay()
        }
    }
    
    var style: [GraphViewDescriptor.GraphStyle] = [.lines] {
        didSet {
            setNeedsDisplay()
        }
    }
    
    var lineColor: [GLcolor] = [GLcolor(r: 1.0, g: 1.0, b: 1.0, a: 1.0)] {
        didSet {
            setNeedsDisplay()
        }
    }
    
    var historyLength: UInt = 0 {
        didSet {
            setNeedsDisplay()
        }
    }
    
    override convenience init(frame: CGRect) {
        self.init(frame: frame, context: EAGLContext(api: .openGLES2)!)
    }
    
    convenience init() {
        self.init(frame: .zero)
    }

    required convenience init?(coder aDecoder: NSCoder) {
        self.init()
    }
    
    override init(frame: CGRect, context: EAGLContext) {
        context.isMultiThreaded = true
        
        EAGLContext.setCurrent(context)
        
        shader = GLGraphShaderProgram()
        
        self.points = []
        
        super.init(frame: frame, context: context)
        
        self.drawableColorFormat = .RGBA8888

        // 2D drawing, no depth information needed
        self.drawableDepthFormat = .formatNone
        self.drawableStencilFormat = .formatNone

        self.drawableMultisample = .multisample4X
        self.isOpaque = false
        self.enableSetNeedsDisplay = true
        
        glClearColor(0.0, 0.0, 0.0, 0.0)
        
        glGenBuffers(1, &vbo)
    }
    
    private var points: [[GraphPoint<GLfloat>]]
    
    func setPoints(_ points: [[GraphPoint<GLfloat>]], min: GraphPoint<Double>, max: GraphPoint<Double>) {
        self.points = points

        xScale = GLfloat(2.0/(max.x-min.x))

        let biasDataY = (max.y-min.y)*0.1
        yScale = GLfloat(2.0/(Float(max.y-min.y+biasDataY)))

        self.max = max
        self.min = min
        
        setNeedsDisplay()
    }
    
    override func draw(_ rect: CGRect) {
        render()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        setNeedsDisplay()
    }
    
    private func render() {
        EAGLContext.setCurrent(context)
        
        glClear(GLbitfield(GL_COLOR_BUFFER_BIT))
        
        let nSets = points.count
        
        if nSets == 0 {
            return
        }
        
        if yScale == 0.0 {
            yScale = 0.1
        }
        
        glBindBuffer(GLenum(GL_ARRAY_BUFFER), vbo)
        
        shader.use()
        
        glEnable(GLenum(GL_BLEND))
        glBlendFunc(GLenum(GL_SRC_ALPHA), GLenum(GL_ONE_MINUS_SRC_ALPHA))
        
        let xTranslation = GLfloat(-min.x-(max.x-min.x)/2.0)
        let yTranslation = GLfloat(-min.y-(max.y-min.y)/2.0)
        
        shader.setScale(xScale, yScale)
        shader.setTranslation(xTranslation, yTranslation)
        
        for i in (0..<points.count).reversed() {
            let p = points[i]
            let length = p.count
            
            if length == 0 {
                continue
            }
            
            glBufferData(GLenum(GL_ARRAY_BUFFER), GLsizeiptr(length * MemoryLayout<GraphPoint<GLfloat>>.size), p, GLenum(GL_DYNAMIC_DRAW))
            
            if historyLength > 1 {
                shader.setPointSize(lineWidth[0])
                glLineWidth(lineWidth[0])
                if (i == nSets-1) {
                    shader.setColor(lineColor[0].r, lineColor[0].g, lineColor[0].b, lineColor[0].a)
                } else {
                    shader.setColor(1.0, 1.0, 1.0, (Float(i)+1.0)*0.6/Float(historyLength))
                }
                let renderMode: Int32
                switch style[0] {
                    case .dots: renderMode = GL_POINTS
                    case .vbars: renderMode = GL_TRIANGLE_STRIP
                    case .hbars: renderMode = GL_TRIANGLE_STRIP
                    default: renderMode = GL_LINE_STRIP
                }
                shader.drawPositions(mode: renderMode, start: 0, count: length, strideFactor: 1)
            } else {
                shader.setPointSize(lineWidth[i])
                glLineWidth(lineWidth[i])
                shader.setColor(lineColor[i].r, lineColor[i].g, lineColor[i].b, lineColor[i].a)
                let renderMode: Int32
                switch style[i] {
                    case .dots: renderMode = GL_POINTS
                    case .vbars: renderMode = GL_TRIANGLES
                    case .hbars: renderMode = GL_TRIANGLES
                    default: renderMode = GL_LINE_STRIP
                }
                shader.drawPositions(mode: renderMode, start: 0, count: length, strideFactor: 1)
            }
        }
    }

    deinit {
        glDeleteBuffers(1, &vbo)
    }
}