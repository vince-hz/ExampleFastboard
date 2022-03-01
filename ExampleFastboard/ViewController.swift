//
//  ViewController.swift
//  ExampleFastboard
//
//  Created by xuyunshi on 2022/3/1.
//

import UIKit
import Fastboard

class ViewController: UIViewController {

    var fastboard: Fastboard!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let config = FastConfiguration(appIdentifier: "",
                                       roomUUID: "",
                                       roomToken: "",
                                       region: .CN,
                                       userUID: "example-uid")
        let fastboard = Fastboard(configuration: config)
        fastboard.joinRoom()
        self.fastboard = fastboard
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        fastboard.view.frame = view.bounds
    }
}

