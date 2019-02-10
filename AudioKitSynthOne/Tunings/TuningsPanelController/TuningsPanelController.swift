//
//  TuningsPanelController.swift
//  AudioKitSynthOne
//
//  Created by Marcus Hobbs on 5/6/18.
//  Copyright © 2018 AudioKit. All rights reserved.
//

import UIKit
import CloudKit
import MobileCoreServices

public protocol TuningsPitchWheelViewTuningDidChange {
    func tuningDidChange()
}

/// View controller for the Tunings Panel
///
/// Erv Wilson is the man [website](http://anaphoria.com/wilson.html)
class TuningsPanelController: PanelController {

    @IBOutlet weak var tuningTableView: UITableView!
    @IBOutlet weak var tuningBankTableView: UITableView!
    @IBOutlet weak var tuningsPitchWheelView: TuningsPitchWheelView!
    @IBOutlet weak var masterTuningKnob: MIDIKnob!
    @IBOutlet weak var resetTuningsButton: SynthButton!
    @IBOutlet weak var diceButton: UIButton!
    @IBOutlet weak var importButton: SynthButton!
    @IBOutlet weak var tuneUpBackButtonButton: SynthButton!

    ///Model
    let tuningModel = Tunings()
    var getStoreTuningWithPresetValue = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.accessibilityElements = [
            tuningBankTableView,
            tuningTableView,
            masterTuningKnob,
            diceButton,
            resetTuningsButton,
            importButton,
            leftNavButton,
            rightNavButton
        ]

        currentPanel = .tunings

        tuningTableView.backgroundColor = UIColor.clear
        tuningTableView.isOpaque = true
        tuningTableView.allowsSelection = true
        tuningTableView.allowsMultipleSelection = false
        tuningTableView.dataSource = self
        tuningTableView.delegate = self
        tuningTableView.accessibilityLabel = "Tunings Table"
        tuningTableView.separatorColor = #colorLiteral(red: 0.368627451, green: 0.368627451, blue: 0.3882352941, alpha: 1)

        tuningBankTableView.backgroundColor = UIColor.clear
        tuningBankTableView.isOpaque = true
        tuningBankTableView.allowsSelection = true
        tuningBankTableView.allowsMultipleSelection = false
        tuningBankTableView.dataSource = self
        tuningBankTableView.delegate = self
        tuningBankTableView.accessibilityLabel = "Tuning Banks Table"
        tuningBankTableView.separatorColor = #colorLiteral(red: 0.368627451, green: 0.368627451, blue: 0.3882352941, alpha: 1)

        if let synth = Conductor.sharedInstance.synth {
            masterTuningKnob.range = synth.getRange(.frequencyA4)
            masterTuningKnob.value = synth.getSynthParameter(.frequencyA4)
            Conductor.sharedInstance.bind(masterTuningKnob, to: .frequencyA4)

            resetTuningsButton.callback = { value in
                if value == 1 {
                    self.tuningModel.resetTuning()
                    self.masterTuningKnob.value = synth.getSynthParameter(.frequencyA4)
                    self.selectRow()
                    self.resetTuningsButton.value = 0
                    self.conductor.updateDisplayLabel("Tuning Reset: 12ET/440")
                }
            }

            //TODO: implement sharing of tuning banks
            importButton.callback = { _ in
                let documentPicker = UIDocumentPickerViewController(documentTypes: [(kUTTypeText as String)], in: .import)
                documentPicker.delegate = self
                self.present(documentPicker, animated: true, completion: nil)
            }
            importButton.isHidden = true

        } else {
            AKLog("race condition: synth not yet created")
        }

        // model
        tuningModel.pitchWheelDelegate = self
        tuningModel.tuneUpDelegate = self
        tuningModel.loadTunings {
            // callback called on main thread
            self.tuningBankTableView.reloadData()
            self.tuningTableView.reloadData()
            self.selectRow()
            self.setTuneUpBackButton(enabled: false)
            self.setTuneUpBackButtonLabel(text: self.tuningModel.tuneUpBackButtonDefaultText)

            // If application was launched by url process it on next main thread cycle
            DispatchQueue.main.async {
                if let appDelegate = UIApplication.shared.delegate as? AppDelegate {
                    if let url = appDelegate.applicationLaunchedWithURL() {
                        AKLog("launched with url:\(url)")
                        _ = self.openUrl(url: url)
                        appDelegate.clearLaunchOptions()
                    }
                }
            }
        }

        // tuneUpBackButton
        tuneUpBackButtonButton.callback = { value in
            self.tuningModel.tuneUpBackButton()
            self.tuneUpBackButtonButton.value = 0
        }
    }

    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }

    func dependentParameterDidChange(_ parameter: DependentParameter) {}

    /// Notification of a change in notes played
    ///
    /// - Parameter playingNotes: An array of playing notes
    func playingNotesDidChange(_ playingNotes: PlayingNotes) {
        tuningsPitchWheelView.playingNotesDidChange(playingNotes)
    }

    @IBAction func randomPressed(_ sender: UIButton) {
        guard tuningModel.isTuningReady else { return }
        tuningModel.randomTuning()
        selectRow()
        UIView.animate(withDuration: 0.4, animations: {
            for _ in 0 ... 1 {
                self.diceButton.transform = self.diceButton.transform.rotated(by: CGFloat(Double.pi))
            }
        })
    }

    internal func selectRow() {
        guard tuningModel.isTuningReady else { return }

        let bankPath = IndexPath(row: tuningModel.selectedBankIndex, section: 0)
        tableView(tuningBankTableView, didSelectRowAt: bankPath)

        let tuningPath = IndexPath(row: tuningModel.selectedTuningIndex, section: 0)
        tableView(tuningTableView, didSelectRowAt: tuningPath)
    }

    public func setTuning(name: String?, masterArray master: [Double]?) {
        guard tuningModel.isTuningReady else { return }
        let reload = tuningModel.setTuning(name: name, masterArray: master)
        if reload {
            tuningTableView.reloadData()
        }
        selectRow()
    }

    public func setDefaultTuning() {
        guard tuningModel.isTuningReady else { return }
        tuningModel.resetTuning()
        selectRow()
    }

    public func getTuning() -> (String, [Double]) {
        guard tuningModel.isTuningReady else { return ("", [1]) }
        return tuningModel.getTuning()
    }

    /// redirect to redirectURL provided by last TuneUp ( "back button" )
    func tuneUpBackButton() {
        tuningModel.tuneUpBackButton()
    }

    /// openURL
    public func openUrl(url: URL) -> Bool {
        return tuningModel.openUrl(url: url)
    }
}


// MARK: - TuningsPitchWheelViewTuningDidChange

extension TuningsPanelController: TuningsPitchWheelViewTuningDidChange {
    
    func tuningDidChange() {
        tuningsPitchWheelView.updateFromGlobalTuningTable()
    }
}



extension TuningsPanelController {

    // MARK: - launch D1
    public func launchD1() {
        tuningModel.launchD1()
    }
}

// MARK: import/export preset banks, tuning banks
extension TuningsPanelController: UIDocumentPickerDelegate {
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentAt url: URL) {
        AKLog("**** url: \(url) ")
        
        let fileName = String(describing: url.lastPathComponent)

        //TODO: Add import/saving/sharing of TuningBanks
        // Marcus: Run load procedure with "fileName" here
        
        // OR, add the logic right here
//        do {
//            //
//
//        } catch {
//            AKLog("*** error loading")
//        }
        
    }
    
}
