//  ViewController.swift
//
//  Copyright 2016, 2017 Devin Glover
//
//  This file is part of Glyph Keyboard.
//
//    Glyph Keyboard is free software: you can redistribute it and/or modify
//    it under the terms of the GNU General Public License as published by
//    the Free Software Foundation, either version 3 of the License, or
//    (at your option) any later version.
//
//    Glyph Keyboard is distributed in the hope that it will be useful,
//    but WITHOUT ANY WARRANTY; without even the implied warranty of
//    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//    GNU General Public License for more details.
//
//    You should have received a copy of the GNU General Public License
//    along with Glyph Keyboard.  If not, see <http://www.gnu.org/licenses/>.

import UIKit
import MessageUI

@IBDesignable
class ViewController: UIViewController, MFMailComposeViewControllerDelegate {
    
    @IBOutlet weak var instructionsButton: UIButton!
    @IBOutlet weak var feedbackButton: UIButton!
    @IBOutlet weak var controlBackground: UIView!
    @IBOutlet weak var themeSwitch: UISwitch!
    
    let defaults = UserDefaults(suiteName: "group.devinglover.glyph")!
    let preferenceForTheme = "DarkThemeEnabled"
    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    
    @IBAction func unwind(_ segue: UIStoryboardSegue) {}
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        for layer in [instructionsButton.layer, feedbackButton.layer, controlBackground.layer] {
            layer.cornerRadius = 24.0
            layer.shadowOffset = CGSize(width: 0.0, height: 3.0)
            layer.shadowOpacity = 0.2
        }
        controlBackground.layer.cornerRadius = 12.0
        
        themeSwitch.isOn = defaults.bool(forKey: preferenceForTheme)
    }
    
    @IBAction func feedbackButtonPressed(_ sender: AnyObject) {
        if MFMailComposeViewController.canSendMail() {
            let feedback = MFMailComposeViewController()
            feedback.mailComposeDelegate = self
            feedback.setToRecipients(["zokunei@icloud.com"])
            feedback.setSubject("Glyph Keyboard \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString")!)")
            
            present(feedback, animated: true, completion: nil)
            appDelegate.restrictRotation = false
        } else {
            let warning = UIAlertController(title: "Unable to Send Email", message: "You can use Settings to set up email.", preferredStyle: .alert)
            let dismiss = UIAlertAction(title: "Ok", style: .default, handler: nil)
            warning.addAction(dismiss)
            
            present(warning, animated: true, completion: nil)
        }
    }
    
    @IBAction func themeSwitchChanged(_ sender: AnyObject) {
        defaults.set(themeSwitch.isOn, forKey: preferenceForTheme)
    }
    
    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        appDelegate.restrictRotation = true
        controller.dismiss(animated: true, completion: nil)
    }
}

