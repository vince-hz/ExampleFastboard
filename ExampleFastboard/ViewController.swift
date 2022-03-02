//
//  ViewController.swift
//  ExampleFastboard
//
//  Created by xuyunshi on 2022/3/1.
//

import UIKit
import Fastboard
import Whiteboard

class ViewController: UIViewController {

    var fastboard: Fastboard!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        let config = FastConfiguration(appIdentifier: "*",
                                       roomUUID: "*",
                                       roomToken: "*",
                                       region: .CN,
                                       userUID: "example-uid")
        let fastboard = Fastboard(configuration: config)
        view.addSubview(fastboard.view)
        fastboard.joinRoom()
        self.fastboard = fastboard
        
        let pptButton = UIButton(type: .system)
        pptButton.setTitle("ppt", for: .normal)
        pptButton.backgroundColor = .black
        pptButton.addTarget(self, action: #selector(insertPpt), for: .touchUpInside)
        view.addSubview(pptButton)
        pptButton.frame = .init(origin: .init(x: 0, y: 44), size: .init(width: 44, height: 44))
        
        let docButton = UIButton(type: .system)
        docButton.setTitle("doc", for: .normal)
        docButton.backgroundColor = .black
        docButton.addTarget(self, action: #selector(insertDoc), for: .touchUpInside)
        view.addSubview(docButton)
        docButton.frame = .init(origin: .init(x: 44, y: 44), size: .init(width: 44, height: 44))
        
        let pdfButton = UIButton(type: .system)
        pdfButton.setTitle("pdf", for: .normal)
        pdfButton.backgroundColor = .black
        pdfButton.addTarget(self, action: #selector(insertPdf), for: .touchUpInside)
        view.addSubview(pdfButton)
        pdfButton.frame = .init(origin: .init(x: 88, y: 44), size: .init(width: 44, height: 44))
        
        let mp4Button = UIButton(type: .system)
        mp4Button.setTitle("mp4", for: .normal)
        mp4Button.backgroundColor = .black
        mp4Button.addTarget(self, action: #selector(insertMP4), for: .touchUpInside)
        view.addSubview(mp4Button)
        mp4Button.frame = .init(origin: .init(x: 132, y: 44), size: .init(width: 44, height: 44))
        
        let mp3Button = UIButton(type: .system)
        mp3Button.setTitle("mp3", for: .normal)
        mp3Button.backgroundColor = .black
        mp3Button.addTarget(self, action: #selector(insertMP3), for: .touchUpInside)
        view.addSubview(mp3Button)
        mp3Button.frame = .init(origin: .init(x: 176, y: 44), size: .init(width: 44, height: 44))
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        fastboard.view.frame = view.bounds
    }
    
    @objc func insertPpt() {
        WhiteConverterV5.checkProgress(withTaskUUID: "3ce728e0954f11ec997c6580ac31fd96",
                                       token: "NETLESSTASK_YWs9c21nRzh3RzdLNk1kTkF5WCZub25jZT0zY2Y0OTY2MC05NTRmLTExZWMtYjFkNS0yMWI2YmJhMTYyNTAmcm9sZT0yJnNpZz01Nzc3NDlhMjYyODViMjc5MzhjMTMxYTlkZGE0YTJlYzA2MzZkMTdmNTcyMTZlMGM1MzVlZGJjNzg4YWQzZTE0JnV1aWQ9M2NlNzI4ZTA5NTRmMTFlYzk5N2M2NTgwYWMzMWZkOTY",
                                       region: .CN,
                                       taskType: .dynamic) { [weak self] info, error in
            guard let pages = info?.progress?.convertedFileList else { return }
            self?.fastboard.insertPptx(pages, title: "Get Started with Flat.pptx", completionHandler: nil)
        }
    }
    
    @objc func insertDoc() {
        WhiteConverterV5.checkProgress(withTaskUUID: "7e86ef10954f11ec9bc1733c998ef9d1",
                                       token: "NETLESSTASK_YWs9c21nRzh3RzdLNk1kTkF5WCZub25jZT03ZTkzOTk0MC05NTRmLTExZWMtYTYzZi02ZDIwNmVhNjI4YTgmcm9sZT0yJnNpZz1lMGZkOGI4MGZlMmFhNjJlMTc5OWUzOWU1YTA0YzU1Mzk5ZTk5MTE5OGMxNTAzZDJjZDY1ODdkMzZmNmQ5MzAzJnV1aWQ9N2U4NmVmMTA5NTRmMTFlYzliYzE3MzNjOTk4ZWY5ZDE",
                                       region: .CN,
                                       taskType: .static) { [weak self] info, error in
            guard let pages = info?.progress?.convertedFileList else { return }
            self?.fastboard.insertPptx(pages, title: "SDL2-API手册-1.doc", completionHandler: nil)
        }
    }
    
    @objc func insertPdf() {
        WhiteConverterV5.checkProgress(withTaskUUID: "bc1e0dc095dd11ecb954e907f43a0c2c",
                                       token: "NETLESSTASK_YWs9c21nRzh3RzdLNk1kTkF5WCZub25jZT1iYzNkY2FjMC05NWRkLTExZWMtYjFkNS0yMWI2YmJhMTYyNTAmcm9sZT0yJnNpZz0wMDE0NTE2MDY0OTVlZTc3ZDE3MDJlNzBmNTU3NzY5OTY0MDE0NmYwMzhjODcwOGY2ODQzMzZiZDZmZmE5YmZkJnV1aWQ9YmMxZTBkYzA5NWRkMTFlY2I5NTRlOTA3ZjQzYTBjMmM",
                                       region: .CN,
                                       taskType: .static) { [weak self] info, error in
            guard let pages = info?.progress?.convertedFileList else { return }
            self?.fastboard.insertPptx(pages, title: "aac-iso-13818-7.pdf", completionHandler: nil)
        }
    }
    
    @objc func insertMP4() {
        fastboard.insertMedia(URL(string: "https://flat-storage.oss-accelerate.aliyuncs.com/cloud-storage/2022-02/24/0638c040-f0d8-4828-9c51-eca794af13fc/0638c040-f0d8-4828-9c51-eca794af13fc.mp4")!,
                              title: "IMG_0005.mov.mp4",
                              completionHandler: nil)
    }
    
    @objc func insertMP3() {
        fastboard.insertMedia(URL(string: "https://flat-storage.oss-accelerate.aliyuncs.com/cloud-storage/2022-02/24/5a642aa3-1d43-4c90-878a-e476bbc56c2e/5a642aa3-1d43-4c90-878a-e476bbc56c2e.mp3")!,
                              title: "AUDIO_2819-1.mp3",
                              completionHandler: nil)
    }
}

