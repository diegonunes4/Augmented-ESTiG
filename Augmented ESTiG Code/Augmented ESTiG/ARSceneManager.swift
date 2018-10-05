//
//  ARSceneManager.swift
//  Augmented ESTiG
//
//  Created by José Joao Pimenta Oliveira on 05/05/2018.
//  Copyright © 2018 pt.ipb.projeto. All rights reserved.
//

//https://collectiveidea.com/blog/archives/2018/04/30/part-1-arkit-wall-and-plane-detection-for-ios-11.3

import Foundation
import ARKit
class ARSceneManager: NSObject {
    
    weak var sceneView: ARSCNView?
    
    func attach(to sceneView: ARSCNView) {
        self.sceneView = sceneView
        
        self.sceneView!.delegate = self
        
        configureSceneView(self.sceneView!)
    }
    
    private func configureSceneView(_ sceneView: ARSCNView) {
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal, .vertical]
        configuration.isLightEstimationEnabled = true
        
        sceneView.session.run(configuration)
    }
    
    func displayDebugInfo() {
        sceneView?.showsStatistics = true
        sceneView?.debugOptions = [ARSCNDebugOptions.showFeaturePoints, ARSCNDebugOptions.showWorldOrigin]
    }
    
}

extension ARSceneManager: ARSCNViewDelegate {
    
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        // we only care about planes
        guard let planeAnchor = anchor as? ARPlaneAnchor else { return }
        
        print("Found plane: \(planeAnchor)")
    }
    
}
