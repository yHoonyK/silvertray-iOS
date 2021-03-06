//
//  ViewController.swift
//  SilverTray
//
//  Created by childc on 04/16/2020.
//  Copyright (c) 2020 childc. All rights reserved.
//

import UIKit
import AVFoundation

import SilverTray
import RxSwift

class ViewController: UIViewController {
    @IBOutlet weak var playButton: UIButton!
    @IBOutlet weak var seekBar: UISlider!
    
    private let player = try? DataStreamPlayer(decoder: OpusDecoder(sampleRate: 24000, channels: 1))
    private var sliderUpdateDisposable: Disposable?
    private let disposeBag = DisposeBag()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        player?.delegate = self
        try? AVAudioSession.sharedInstance().setCategory(.playAndRecord,
                                                         mode: .default,
                                                         options: [.defaultToSpeaker])
        
        DispatchQueue.main.async { [weak self] in
            guard let opusFileUrl = Bundle.main.url(forResource: "attachment", withExtension: "opus"),
                let opusData = try? Data(contentsOf: opusFileUrl) else {
                    return
            }
            
            for _ in (0..<4) {
                try? SktOpusParser.parse(from: opusData).forEach { (chunk) in
                    try self?.player?.appendData(chunk)
                }
            }
            try? self?.player?.lastDataAppended()
            
            self?.seekBar.minimumValue = 0.0
            self?.seekBar.maximumValue = Float(self?.player?.duration ?? 0)
            self?.seekBar.isEnabled = true
            
            self?.player?.speed = 0.91875
            //        player.volume = 0.1
            //        player?.pitch += 300
            self?.updateSlider()
        }

    }

    @IBAction func btnClick(_ sender: UIButton) {
        guard let player = player else { return }

        if player.isPlaying {
            player.pause()
            return
        }

        player.play()
    }
    
    private func updateSlider() {
        sliderUpdateDisposable?.dispose()
        sliderUpdateDisposable = Observable<Int>.timer(.milliseconds(100), period: .milliseconds(100), scheduler: ConcurrentDispatchQueueScheduler.init(qos: .default))
            .subscribe(onNext: { [weak self] _ in
                DispatchQueue.main.async {
                    self?.seekBar.setValue(Float(self?.player?.offset ?? 0), animated: true)
                }
            })
        sliderUpdateDisposable?.disposed(by: disposeBag)
    }
    
    @IBAction func sliderValueChanging(_ sender: Any) {
        sliderUpdateDisposable?.dispose()
    }
    
    @IBAction func sliderValueChanged(_ sender: UISlider) {
        print("seek to: \(sender.value), (\(sender.minimumValue)..<\(sender.maximumValue)")
        
        player?.seek(to: Int(sender.value), completion: { [weak self] (result) in
            print("result of seek: \(result)")
            
            if case .success = result {
                self?.updateSlider()
            }
        })
    }
}

extension ViewController: DataStreamPlayerDelegate {
    func dataStreamPlayerStateDidChange(_ state: DataStreamPlayerState) {
        print("dataStreamPlayerStateDidChange: \(state)")
        
        DispatchQueue.main.async { [weak self] in
            switch state {
            case .start:
                self?.playButton.setTitle("Pause", for: .normal)
            case .pause:
                self?.playButton.setTitle("Play", for: .normal)
            case .finish:
                self?.playButton.isEnabled = false
                self?.sliderUpdateDisposable?.dispose()
            default:
                break
            }
        }
    }
}
