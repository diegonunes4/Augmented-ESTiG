//
//  ViewController.swift
//  Augmented ESTiG
//
//  Created by José Joao Pimenta Oliveira on 17/04/2018.
//  Copyright © 2018 pt.ipb.projeto. All rights reserved.
//

import UIKit
import SpriteKit
import ARKit
import Vision

// Web Service

struct Room : Decodable {
    let id : Int?
    let num : Int?
    //Adicionar Schedules
    var horario = [Schedule]()
    var aviso = [Notice]()
}

struct Schedule : Decodable  {
    let id : Int?
    let hora_ini : Date?
    let hora_fim : Date?
    let descr : String?
    
    private enum CodingKeys: String, CodingKey {
        case id
        case hora_ini
        case hora_fim
        case descr
    }
}

struct Notice : Decodable {
    let id : Int?
    let descr : String?
}

class ViewController: UIViewController, ARSCNViewDelegate {

    @IBOutlet weak var debugLabel: UILabel!
    @IBOutlet weak var debugTextView: UITextView!
    @IBOutlet weak var sceneView: ARSCNView!
    
    let dispatchQueueML = DispatchQueue(label: "com.hw.dispatchqueueml") // A Serial Queue
    var visionRequests = [VNRequest]()
    
    var room: Room?
    
    var lastNum = -2
    var num = -1
    
    //Internet Connection
    let reachability = Reachability()!
    
    var room_array: [[Int]] = [[17, 0], [43, 0], [120,0]]
    var planeAnchors: [ARPlaneAnchor] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        sceneView?.delegate = self
        sceneView?.showsStatistics = true
        let scene = SCNScene()
        sceneView?.scene = scene
        configureLighting()
        
        guard let selectedModel = try? VNCoreMLModel(for: SalasMLv6().model) else {
            fatalError("Could not load model.")
        }
        
        let classificationRequest = VNCoreMLRequest(model: selectedModel, completionHandler: classificationCompleteHandler)
        classificationRequest.imageCropAndScaleOption = VNImageCropAndScaleOption.centerCrop
        visionRequests = [classificationRequest]
        loopCoreMLUpdate()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setUpSceneView()
    }
    
    //Created fot the Internet Connection purpose
    //______
    override func viewDidAppear(_ animated: Bool) {
        
        reachability.whenReachable = { reachability in
            if reachability.connection == .wifi {
                print("Reachable via WiFi")
            } else {
                print("Reachable via Cellular")
            }
        }
        reachability.whenUnreachable = { _ in
            print("Not reachable")
            self.createAlert(title: "Oops!", message: "Your Internet connection is offline. No content will be displayed until you are connected. If problem continues, please restart the application.")
        }
        
        do {
            try reachability.startNotifier()
        } catch {
            print("Unable to start notifier")
        }
        
        NotificationCenter.default.addObserver(self, selector: #selector(reachabilityChanged(note:)), name: .reachabilityChanged, object: reachability)
        do{
            try reachability.startNotifier()
        }catch{
            print("could not start reachability notifier")
        }
    }
    
    @objc func reachabilityChanged(note: Notification) {
        
        let reachability = note.object as! Reachability
        
        switch reachability.connection {
        case .wifi:
            print("Reachable via WiFi")
        case .cellular:
            print("Reachable via Cellular")
        case .none:
            print("Network not reachable")
            createAlert(title: "Oops!", message: "Your Internet connection is offline. No content will be displayed until you are connected. If the problem persists, please restart the application.")
        }
    }
    
    func createAlert(title:String, message:String)
    {
        let alert = UIAlertController(title: title, message: message, preferredStyle: UIAlertControllerStyle.alert)
        alert.addAction(UIAlertAction(title: "Ok", style: UIAlertActionStyle.default, handler: { (action) in alert.dismiss(animated: true, completion: nil)
        } ) )
        self.present(alert, animated: true, completion: nil)
    }
    
    //______
    
    func setUpSceneView()
    {
        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()
        
        // Allow Vertical Plane Detection
        configuration.planeDetection = .vertical
        
        // Run the view's session
        sceneView?.session.run(configuration)
        
        sceneView?.debugOptions = [ARSCNDebugOptions.showFeaturePoints]
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        sceneView?.session.pause()
    }
    
    func configureLighting()
    {
        sceneView?.automaticallyUpdatesLighting = true
        sceneView?.autoenablesDefaultLighting = true
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    // MARK: - ARSCNViewDelegate
    
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        DispatchQueue.main.async {
            // Do any desired updates to SceneKit here.
        }
    }
    
    // MARK: - MACHINE LEARNING
    
    func loopCoreMLUpdate() {
        // Continuously run CoreML whenever it's ready. (Preventing 'hiccups' in Frame Rate)
        dispatchQueueML.async {
            // 1. Run Update.
            self.updateCoreML()
            // 2. Loop this function.
            self.loopCoreMLUpdate()
        }
    }
    
    func updateCoreML() {
        // Get Camera Image as RGB
        let pixbuff : CVPixelBuffer? = (sceneView?.session.currentFrame?.capturedImage)
        if pixbuff == nil { return }
        let ciImage = CIImage(cvPixelBuffer: pixbuff!)
        
        // Prepare CoreML/Vision Request
        let imageRequestHandler = VNImageRequestHandler(ciImage: ciImage, options: [:])
        
        // Run Vision Image Request
        do {
            try imageRequestHandler.perform(self.visionRequests)
        } catch {
            print(error)
        }
    }

    func classificationCompleteHandler(request: VNRequest, error: Error?) {
        // Catch Errors
        if error != nil {
            print("Error: " + (error?.localizedDescription)!)
            return
        }
        guard let observations = request.results else {
            print("No results")
            return
        }
        
        // Get Classifications
        let classifications = observations[0...2] // top 3 results
            .compactMap({ $0 as? VNClassificationObservation })
            .map({ "\($0.identifier) \(String(format:" : %.2f", $0.confidence))" })
            .joined(separator: "\n")
        
        // Render Classifications
        DispatchQueue.main.async {
            
            // Display Debug Text on screen
            self.debugTextView.text = "TOP 3 PROBABILITIES: \n" + classifications
            
            // Display Top Symbol
            var symbol = "❌"
            var gabNum: Int?
            let topPrediction = classifications.components(separatedBy: "\n")[0]
            let topPredictionName = topPrediction.components(separatedBy: ":")[0].trimmingCharacters(in: .whitespaces)
            
            // Only display a prediction if confidence is above 90%
            let topPredictionScore:Float? = Float(topPrediction.components(separatedBy: ":")[1].trimmingCharacters(in: .whitespaces))
            if (topPredictionScore != nil && topPredictionScore! > 0.90) {
                if (topPredictionName == "120") {
                    symbol = "1️⃣2️⃣0️⃣"
                    gabNum = 120
                    self.num = gabNum!
                }
                if (topPredictionName == "43") {
                    symbol = "4️⃣3️⃣"
                    gabNum = 43
                    self.num = gabNum!
                }
                if (topPredictionName == "17") {
                    symbol = "1️⃣7️⃣"
                    gabNum = 17
                    self.num = gabNum!
                }
            }
            
            if let gn = gabNum {
                // get room from REST
                let jsonURL = "http://gate.ipb.pt:8085/v1/room/\(gn)"
                guard let url = URL(string: jsonURL) else {
                    return
                }
                URLSession.shared.dataTask(with: url) { (data, response, error) in
                    
                    if error != nil{
                        print("error)")
                        return
                    }
                    do {
                        self.room = try JSONDecoder().decode(Room.self, from: data!)
                    }catch{
                        print("!!!Erro no Room!!!")
                    }
                    }.resume()
            }
            self.debugLabel.text = symbol
        }
    }
    
    // MARK: - HIDE STATUS BAR
    override var prefersStatusBarHidden : Bool { return true }
    
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor)
    {
        print("Entrei no Renderer")

        guard room != nil else  {
            print("room == nil")
            return
        }
        
        guard let planeAnchor = anchor as? ARPlaneAnchor else{
            return
        }
        
//        let teste = SCNPlane(width: CGFloat(0.50), height: CGFloat(0.50))
//        teste.materials.first?.diffuse.contents = UIColor.red
//        let testeNode = SCNNode(geometry: teste)
        
        planeAnchors.append(planeAnchor)
        let p = planeAnchors.last
        
//        testeNode.eulerAngles.x = -.pi / 2
//        testeNode.position = SCNVector3((p?.center.x)!, (p?.center.y)!,(p?.center.z)!)
//
//        node.addChildNode(testeNode)
        
        let dataformatter = DateFormatter()
        dataformatter.dateFormat = "HH:mm"
        
        let dataformatter_wk = DateFormatter()
        dataformatter_wk.dateFormat = "EEEE"
        
        if( ( num == room_array[0][0] && room_array[0][1] == 1 ) || ( num == room_array[1][0] && room_array[1][1] == 1 ) || ( num == room_array[2][0] && room_array[2][1] == 1 ) ){
            return
        }else{
            var i = 0
            for horario in (self.room?.horario)!{
                
                //Convert Dates
                let comp_inicio: DateComponents = Calendar.current.dateComponents([.hour, .minute], from: (horario.hora_ini)!)
                let comp_fim: DateComponents = Calendar.current.dateComponents([.hour, .minute], from: (horario.hora_fim)!)
                let comp_wk: DateComponents = Calendar.current.dateComponents([.weekday, .day, .month, .year, .hour, .minute], from: (horario.hora_ini)!)
                let data_inicio = Calendar.current.date(from: comp_inicio)
                let data_fim = Calendar.current.date(from: comp_fim)
                let data_wk = Calendar.current.date(from: comp_wk)
                let hora_inicio = dataformatter.string(from: data_inicio!)
                let hora_fim = dataformatter.string(from: data_fim!)
                let horario_final =  (hora_inicio + "-" + hora_fim).uppercased()
                let weekday = dataformatter_wk.string(from: data_wk!).uppercased()
                
                //Plane
                let plane = SCNPlane(width: CGFloat(0.09), height: CGFloat(0.09))
                plane.materials.first?.diffuse.contents = UIColor.planeColor
                let planeNode = SCNNode(geometry: plane)
                
                //Text
                let text_horario = SCNText(string: horario_final, extrusionDepth: 0.1)
                let text_weekday = SCNText(string: weekday, extrusionDepth: 0.1)
                let text_descr = SCNText(string: horario.descr?.uppercased() ?? 0, extrusionDepth: 0.1)
                let material_text = SCNMaterial()
                material_text.diffuse.contents = UIColor.black
                //Atribute the material_text to the text variables
                text_weekday.materials = [material_text]
                text_descr.materials = [material_text]
                text_horario.materials = [material_text]
                //Create the text nodes
                let node_text_weekday = SCNNode(geometry: text_weekday)
                let node_text_horario = SCNNode(geometry: text_horario)
                let node_text_descr = SCNNode(geometry: text_descr)
                
                //Piones
                let piones = SCNCylinder(radius: 0.002, height: 0.005)
                let material_piones = SCNMaterial()
                material_piones.diffuse.contents = UIColor.red
                piones.materials = [material_piones]
                let node_piones = SCNNode(geometry: piones)
                
                //Rotate the nodes
                planeNode.eulerAngles.x = -.pi / 2
                node_text_weekday.eulerAngles.x = -.pi / 2
                node_text_horario.eulerAngles.x = -.pi / 2
                node_text_descr.eulerAngles.x = -.pi / 2
                
                //Scale the nodes
                node_text_weekday.scale = SCNVector3(x: 0.0007, y: 0.0007, z: 0.0007)
                node_text_horario.scale = SCNVector3(x: 0.0009, y: 0.0009, z: 0.0009)
                node_text_descr.scale = SCNVector3(x: 0.0011, y: 0.0011, z: 0.0011)

                // 5 Get the planeAnchor positions
                let x = CGFloat((p?.center.x)!) // Esquerda e direita
                let y = CGFloat((p?.center.y)!) // +y = Mais perto do telemovel
                let z = CGFloat((p?.center.z)!) // -z = Mais alto

                //Position of the Yellow Plane
                planeNode.position = SCNVector3(x + CGFloat(i%3)/10 ,y ,z + CGFloat(i/3)/10)
                node_piones.position = SCNVector3(x + CGFloat(i%3)/10 ,y , z - 0.035 + CGFloat(i/3)/10)
                node_text_horario.position = SCNVector3(x - 0.033 + CGFloat(i%3)/10 ,y ,z + 0.030 + CGFloat(i/3)/10)
                if(weekday == "SEGUNDA-FEIRA"){
                    node_text_weekday.position = SCNVector3(x - 0.035 + CGFloat(i%3)/10 ,y ,z + CGFloat(i/3)/10)
                }else{
                    node_text_weekday.position = SCNVector3(x - 0.030 + CGFloat(i%3)/10 ,y ,z + CGFloat(i/3)/10)
                }
                if((horario.descr) == "Atendimento"){
                    node_text_descr.scale = SCNVector3(x: 0.0009, y: 0.0009, z: 0.0009)
                    node_text_descr.position = SCNVector3(x - 0.036 + CGFloat(i%3)/10 ,y ,z - 0.015 + CGFloat(i/3)/10)
                }
                if((horario.descr) == "Aula"){
                    node_text_descr.position = SCNVector3(x - 0.017 + CGFloat(i%3)/10  ,y ,z - 0.015 + CGFloat(i/3)/10)
                }
                
                // 6 Add the planeNode as the child node onto the newly added SceneKit node.
                node.addChildNode(planeNode)
                node.addChildNode(node_text_weekday)
                node.addChildNode(node_text_horario)
                node.addChildNode(node_text_descr)
                node.addChildNode(node_piones)
                
                i=i+1
            }
            
            for aviso in (self.room?.aviso)!{
                
                //Plane
                let plane = SCNPlane(width: CGFloat(0.09), height: CGFloat(0.09))
                plane.materials.first?.diffuse.contents = UIColor.planeColor
                let planeNode = SCNNode(geometry: plane)
                
                //Text
                let text_aviso = SCNText(string: aviso.descr?.uppercased(), extrusionDepth: 0.1)
                let text_titulo = SCNText(string: "AVISO", extrusionDepth: 0.1)
                let material_text = SCNMaterial()
                material_text.diffuse.contents = UIColor.black
                text_aviso.materials = [material_text]
                text_titulo.materials = [material_text]
                let node_text_aviso = SCNNode(geometry: text_aviso)
                let node_text_titulo = SCNNode(geometry: text_titulo)
                
                //Piones
                let piones = SCNCylinder(radius: 0.002, height: 0.005)
                let material_piones = SCNMaterial()
                material_piones.diffuse.contents = UIColor.red
                piones.materials = [material_piones]
                let node_piones = SCNNode(geometry: piones)
                
                // 5 Get the planeAnchor positions
                let x = CGFloat(planeAnchor.center.x) // Esquerda e direita
                let y = CGFloat(planeAnchor.center.y) // +y = Mais perto do telemovel
                let z = CGFloat(planeAnchor.center.z) // -z = Mais alto
                
                // Rotate and scale the nodes
                planeNode.eulerAngles.x = -.pi / 2
                node_text_aviso.eulerAngles.x = -.pi / 2
                node_text_titulo.eulerAngles.x = -.pi/2
                node_text_aviso.scale = SCNVector3(x: 0.0006, y: 0.0006, z: 0.0006)
                node_text_titulo.scale = SCNVector3(x: 0.0009, y: 0.0009, z: 0.0009)
                
                // Positioning the Nodes
                planeNode.position = SCNVector3(x + CGFloat(i%3)/10 , y , z + CGFloat(i/3)/10)
                node_text_aviso.position = SCNVector3(x - 0.042 + CGFloat(i%3)/10 , y , z + CGFloat(i/3)/10)
                node_text_titulo.position = SCNVector3(x - 0.015 + CGFloat(i%3)/10  ,y , z-0.015 + CGFloat(i/3)/10)
                node_piones.position = SCNVector3(x + CGFloat(i%3)/10 ,y , z - 0.035 + CGFloat(i/3)/10)
                
                // Add the Nodes to ParentNode
                node.addChildNode(planeNode)
                node.addChildNode(node_piones)
                node.addChildNode(node_text_titulo)
                node.addChildNode(node_text_aviso)
                
                i = i+1
            }
            
            switch self.room?.num{
                case 17: room_array[0][1] = 1
                print(room_array)
                lastNum = 17
                case 43: room_array[1][1] = 1
                print(room_array)
                lastNum = 43
                case 120: room_array[2][1] = 1
                print(room_array)
                lastNum = 120
                default: print("Room nao encontrado")
            }
        }
    }
}

// MARK: - Extension UIColor

extension UIColor {
    open class var planeColor: UIColor{
        return UIColor(red: 1, green: 1, blue: 0.6, alpha: 1)
    }
}

// MARK: - Extension Date

extension Date {
    var millisecondsSince1970:Int {
        return Int((self.timeIntervalSince1970 * 1000.0).rounded())
    }
    
    init(milliseconds:Int) {
        self = Date(timeIntervalSince1970: TimeInterval(milliseconds / 1000))
    }
}

// MARK: - Extension Schedule

extension Schedule {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        descr = try container.decode(String.self, forKey: .descr)
        let dateIni = try container.decode(Int.self, forKey: .hora_ini)
        hora_ini = Date(milliseconds: dateIni)
        let dateFim = try container.decode(Int.self, forKey: .hora_fim)
        hora_fim = Date(milliseconds: dateFim)
    }
}
