//
//  ViewController.swift
//  NFTPlayer
//
//  Created by pengdong on 08/25/2023.
//  Copyright (c) 2023 pengdong. All rights reserved.
//

import UIKit
import NFTPlayer

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        let v = UIView()
        v.frame = CGRect(x: 0, y: 120, width: view.bounds.width, height: 300)
        view.addSubview(v)
        
        PlayerManager.shared.play(media: "http://txzuiyou.izuiyou.com/zyvdorigine/9f/1c/0e28-8903-4a85-9aa1-7c2d17173ddf", to: v)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

}

