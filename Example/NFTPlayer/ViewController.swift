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
        
//    http://vt1.doubanio.com/202001022001/7264e07afc6d8347c15f61c247c36f0e/view/movie/M/302100358.mp4
        PlayerManager.shared.play(media: "http://vt1.doubanio.com/202001022001/7264e07afc6d8347c15f61c247c36f0e/view/movie/M/302100358.mp4", to: v)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

}

