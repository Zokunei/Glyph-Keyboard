//  KeyboardViewController.swift
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

class GlyphScrollView: UIScrollView {
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        let viewController = delegate as! KeyboardViewController
        if viewController.sectionMenuIsDisplayed {
            viewController.dismissSectionMenu()
        }
    }
}

class KeyboardViewController: UIInputViewController, UIScrollViewDelegate {
    
    let nextKeyboardButton = UIButton(type: .system), sectionsButton = UIButton(type: .system), spaceBar = UIButton(type: .system), backspace = UIButton(type: .system), returnKey = UIButton(type: .system)
    var keys: [UIButton]!
    var keyTimer = Timer()
    var sectionsButtonTimer, spaceBarTimer, backspaceTimer: Timer!
    
    let buttonRadius: CGFloat = 10.0
    let buttonBorderColor = UIColor(white: 0.35, alpha: 0.4).cgColor
    let glyphFontSize: CGFloat = 21.0
    
    let groupDefaults = UserDefaults(suiteName: "group.devinglover.glyph")!
    let extensionDefaults = UserDefaults.standard
    let preferenceForTheme = "DarkThemeEnabled"
    let preferenceForFavorites = "Favorites"
    var userPreferenceDark: Bool!
    
    let glyphScroll = GlyphScrollView()
    let contentView = UIView()
    let scrollPositionState = "ScrollPosition"
    var fonts: [CTFontDescriptor]!
    var columns = 0
    
    struct Block {
        let name: String
        let range: CountableClosedRange<Int>
    }
    let blocks = [
        Block(name: "Letterlike Symbols", range: 0x2100...0x214f),
        Block(name: "Mathematical Operators", range: 0x21ff...0x22ff), // trick: start 1 number lower to add ± later
        Block(name: "Miscellaneous Technical", range: 0x2300...0x243f),
        Block(name: "Geometric Shapes", range: 0x2500...0x25ff),
        Block(name: "Miscellaneous Symbols", range: 0x2600...0x26ff),
        Block(name: "Dingbats", range: 0x2700...0x27bf),
        Block(name: "Arrows", range: 0x2190...0x21ff)
    ]
    var blockNumber = 0
    let blockState = "BlockNumber"
    var favorites: [String]!
    var isFavorites = true
    let isFavoritesState = "IsFavorites"
    var defaultDictionary: [String: NSObject]!
    
    let sectionMenuBackground = UIView()
    var sectionMenuButtons: [UIButton] = []
    var sectionMenuIsDisplayed = false
    
    var floating = false
    var floatingGlyph: UIButton!
    var floatingGlyphIsFavorite = false
    var floatingGlyphTimer = Timer()
    var floatingIndex = 0, previousIndex = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // preferences and state restoration
        defaultDictionary = [
            isFavoritesState: true as NSObject,
            preferenceForFavorites: ["☻", "★", "☆", "❛", "❜", "☥", "☩", "≠", "☐", "☒", "☜", "♱", "⚚", "♚", "☭", "∞", "‽", "✭","☤", "⚘", "❀", "❃", "☙", "➢", "➠", "➳", "♟", "♞", "♝", ""] as NSObject
        ]
        extensionDefaults.register(defaults: defaultDictionary)
        
        isFavorites = extensionDefaults.bool(forKey: isFavoritesState)
        blockNumber = extensionDefaults.integer(forKey: blockState)
        favorites = extensionDefaults.array(forKey: preferenceForFavorites) as? [String]
        userPreferenceDark = groupDefaults.bool(forKey: preferenceForTheme)
        
        // bottom keys
        nextKeyboardButton.setImage(UIImage(named: "Globe"), for: UIControlState())
        nextKeyboardButton.layer.cornerRadius = buttonRadius
        nextKeyboardButton.layer.borderColor = buttonBorderColor
        nextKeyboardButton.layer.borderWidth = 1.0
        if #available(iOSApplicationExtension 10.0, *) {
            nextKeyboardButton.addTarget(self, action: #selector(handleInputModeList(from:with:)), for: .allTouchEvents)
        } else {
            // Fallback on earlier versions
            nextKeyboardButton.addTarget(self, action: #selector(advanceToNextInputMode), for: .touchUpInside)
        }
        self.view.addSubview(nextKeyboardButton)
        
        sectionsButton.setTitle("≣", for: UIControlState())
        sectionsButton.titleLabel?.font = UIFont.systemFont(ofSize: 25.0)
        sectionsButton.layer.cornerRadius = buttonRadius
        sectionsButton.layer.borderColor = buttonBorderColor
        sectionsButton.layer.borderWidth = 1.0
        sectionsButton.addTarget(self, action: #selector(setGlyphs), for: .touchUpInside)
        sectionsButton.addTarget(self, action: #selector(startSectionsButtonTimer), for: .touchDown)
        sectionsButton.addTarget(self, action: #selector(cancelSectionsButtonTimer), for: [.touchUpInside, .touchUpOutside, .touchCancel, .touchDragExit])
        self.view.addSubview(sectionsButton)
        
        spaceBar.layer.cornerRadius = buttonRadius
        spaceBar.layer.borderWidth = 1.0
        spaceBar.addTarget(self, action: #selector(insertSpace), for: .touchUpInside)
        self.view.addSubview(spaceBar)
        
        backspace.setTitle("⌫", for: UIControlState())
        backspace.titleLabel?.font = UIFont.systemFont(ofSize: 20.0)
        backspace.layer.cornerRadius = buttonRadius
        backspace.layer.borderColor = buttonBorderColor
        backspace.layer.borderWidth = 1.0
        backspace.addTarget(self, action: #selector(startBackspaceTimer), for: .touchDown)
        backspace.addTarget(self, action: #selector(cancelBackspaceTimer), for: [.touchUpInside, .touchUpOutside])
        self.view.addSubview(backspace)
        
        returnKey.setTitle("⏎", for: UIControlState())
        returnKey.titleLabel?.font = UIFont.systemFont(ofSize: 20.0)
        returnKey.layer.cornerRadius = buttonRadius
        returnKey.layer.borderColor = buttonBorderColor
        returnKey.layer.borderWidth = 1.0
        returnKey.addTarget(self, action: #selector(insertNewline), for: .touchUpInside)
        self.view.addSubview(returnKey)
        
        // glyph keys
        let panRecognizer = UIPanGestureRecognizer(target:self, action: #selector(panButton))
        self.view.addGestureRecognizer(panRecognizer)
        
        glyphScroll.delegate = self
        self.view.addSubview(glyphScroll)
        glyphScroll.addSubview(contentView)
        
        let fontsNS: NSArray! = CTFontCopyDefaultCascadeListForLanguages(CTFontCreateWithName("Helvetica" as CFString?, glyphFontSize, nil), nil)
        fonts = fontsNS as! [CTFontDescriptor]
        setGlyphs()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        glyphScroll.contentOffset.x = CGFloat(extensionDefaults.float(forKey: scrollPositionState))
        glyphScroll.perform(#selector(glyphScroll.flashScrollIndicators), with: nil, afterDelay: 0)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        extensionDefaults.set(Float(glyphScroll.contentOffset.x), forKey: scrollPositionState)
        extensionDefaults.synchronize()
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        
        nextKeyboardButton.frame = CGRect(x: 3.0, y: 0.0, width: self.view.frame.width * 0.1, height: self.view.frame.height * 0.2)
        nextKeyboardButton.center.y = self.view.center.y * 1.75
        
        sectionsButton.frame.size = nextKeyboardButton.frame.size
        sectionsButton.frame.origin.x = nextKeyboardButton.frame.width + 6.0
        sectionsButton.center.y = nextKeyboardButton.center.y
        
        spaceBar.frame.size = CGSize(width: self.view.frame.width * 0.55, height: nextKeyboardButton.frame.height)
        spaceBar.center = CGPoint(x: self.view.center.x, y: nextKeyboardButton.center.y)
        
        backspace.frame.size = nextKeyboardButton.frame.size
        backspace.frame.origin.x = self.view.frame.width - backspace.frame.width * 2.0 - 6.0
        backspace.center.y = nextKeyboardButton.center.y
        
        returnKey.frame.size = nextKeyboardButton.frame.size
        returnKey.frame.origin.x = self.view.frame.width - returnKey.frame.width - 3.0
        returnKey.center.y = nextKeyboardButton.center.y
        
        glyphScroll.frame = self.view.frame
        glyphScroll.frame.size.height = self.view.frame.height * 0.78
        
        contentView.frame.origin = glyphScroll.frame.origin
        contentView.frame.size = CGSize(width: self.view.frame.width * CGFloat(columns) * 0.1, height: self.view.frame.height)
        glyphScroll.contentSize = CGSize(width: contentView.frame.width, height: glyphScroll.frame.height)
        
        layoutKeys()
        
        if sectionMenuIsDisplayed {
            sectionMenuBackground.frame = CGRect(x: 0.0, y: sectionsButton.frame.origin.y - sectionsButton.frame.size.height * 1.1, width: self.view.frame.width * 0.875, height: sectionsButton.frame.height)
            for (index, button) in sectionMenuButtons.enumerated() {
                button.frame.size = CGSize(width: sectionMenuBackground.frame.width / CGFloat(sectionMenuButtons.count), height: sectionMenuBackground.frame.size.height)
                let xMultiplier = CGFloat((Float(index) + 0.5) * (2 / Float(sectionMenuButtons.count)))
                button.center = CGPoint(x: sectionMenuBackground.center.x * xMultiplier, y: sectionMenuBackground.center.y)
            }
            sectionMenuBackground.frame.origin.x += sectionsButton.frame.origin.x
            for button in sectionMenuButtons {
                button.frame.origin.x += sectionMenuBackground.frame.origin.x
            }
        }
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        if floating && floatingGlyphIsFavorite {
            floatingGlyphTimer.invalidate()
            floatingIndex = floatingGlyph.tag
            rearrange()
        } else if floating {
            floatingGlyph.removeFromSuperview()
        }
        floating = false
        resetSpaceBarLabel()
        cancelBackspaceTimer()
    }
    
    // sectionsButton
    func startSectionsButtonTimer() {
        sectionsButtonTimer = Timer(timeInterval: 0.3, target: self, selector: #selector(holdSectionsButton), userInfo: nil, repeats: false)
        RunLoop.current.add(sectionsButtonTimer, forMode: RunLoopMode.defaultRunLoopMode)
    }
    
    func cancelSectionsButtonTimer() {
        sectionsButtonTimer.invalidate()
    }
    
    func holdSectionsButton() {
        if !floating && !keyTimer.isValid {
            sectionMenuIsDisplayed = true
            sectionsButton.cancelTracking(with: nil)
            sectionsButton.isEnabled = false
            sectionsButton.alpha = 0.5
            glyphScroll.isScrollEnabled = false
            
            for button in keys {
                button.isEnabled = false
                button.alpha = 0.5
            }
            
            // present sections menu
            sectionMenuBackground.layer.cornerRadius = buttonRadius
            sectionMenuBackground.layer.borderWidth = 1.0
            sectionMenuBackground.layer.borderColor = spaceBar.layer.borderColor
            self.view.addSubview(sectionMenuBackground)
            
            var sectionMenuGlyphs = [favorites[0]]
            for block in blocks {
                var scalar = block.range.lowerBound
                if scalar == 0x21ff { // ± trick
                    scalar = 0x00b1
                }
                while !characterIsDisplayable(UniChar(scalar)) {
                    scalar += 1
                }
                sectionMenuGlyphs.append("\(UnicodeScalar(scalar)!)")
            }
            
            sectionMenuButtons = []
            for (index, glyph) in sectionMenuGlyphs.enumerated() {
                let button = UIButton(type: .system)
                button.setTitle(glyph, for: UIControlState())
                button.tag = index
                button.addTarget(self, action: #selector(changeBlockNumber), for: .touchUpInside)
                button.titleLabel?.font = UIFont.systemFont(ofSize: glyphFontSize)
                sectionMenuButtons.append(button)
                self.view.addSubview(button)
            }
            viewWillLayoutSubviews()
            textDidChange(nil)
        }
    }
    
    func changeBlockNumber(_ sender: UIButton) {
        if !floating && !keyTimer.isValid {
            if sender.tag == 0 {
                blockNumber = 0
                isFavorites = true
            } else {
                blockNumber = sender.tag - 1
                isFavorites = false
            }
            
            dismissSectionMenu()
            setGlyphs()
        }
    }
    
    func dismissSectionMenu() {
        sectionMenuIsDisplayed = false
        sectionsButton.isEnabled = true
        sectionsButton.alpha = 1.0
        glyphScroll.isScrollEnabled = true
        for button in sectionMenuButtons {
            button.removeFromSuperview()
        }
        sectionMenuBackground.removeFromSuperview()
        
        for button in keys {
            button.isEnabled = true
            button.alpha = 1.0
        }
    }
    
    // glyph keys
    func layoutKeys(_ excludeFloating: Bool = false) {
        for (index, button) in keys.enumerated() {
            if excludeFloating && button == floatingGlyph {
                continue
            }
            button.frame.size = CGSize(width: self.view.frame.width * 0.095, height: self.view.frame.height * 0.22)
            
            let columnNumber = index % columns + 1
            let rowNumber = Float((index + 1 - columnNumber) / columns)
            let xMultiplier = CGFloat(Float(columnNumber) * 0.2 - 0.1)
            let yMultiplier = CGFloat(0.25 + 0.5 * rowNumber)
            
            button.center = CGPoint(x: glyphScroll.center.x * xMultiplier, y: contentView.center.y * yMultiplier)
        }
    }
    
    func setGlyphs() {
        sectionsButtonTimer?.invalidate()
        for subview in contentView.subviews {
            if floating && !floatingGlyphIsFavorite && subview == floatingGlyph {
                continue
            }
            subview.removeFromSuperview()
        }
        
        extensionDefaults.set(isFavorites, forKey: isFavoritesState)
        extensionDefaults.set(blockNumber, forKey: blockState)
        
        var glyphs = [String]()
        if isFavorites {
            spaceBar.setTitle("Favorites", for: UIControlState())
            
            glyphs = favorites
            
            isFavorites = false
        } else {
            spaceBar.setTitle(blocks[blockNumber].name, for: UIControlState())
            
            for i in blocks[blockNumber].range {
                if i == 0x21ff { // ± trick
                    glyphs.append("\(UnicodeScalar(0x00b1)!)")
                } else if characterIsDisplayable(UniChar(i)) {
                    glyphs.append("\(UnicodeScalar(i)!)")
                }
            }
            
            if blockNumber < blocks.count - 1 {
                blockNumber += 1
            } else {
                blockNumber = 0
                isFavorites = true
            }
        }
        
        spaceBarTimer?.invalidate()
        spaceBarTimer = Timer(timeInterval: 1.5, target: self, selector: #selector(resetSpaceBarLabel), userInfo: nil, repeats: false)
        RunLoop.current.add(spaceBarTimer, forMode: RunLoopMode.defaultRunLoopMode)
        
        columns = glyphs.count / 3
        if glyphs.count % 3 > 0 {
            columns += 1
        }
        if columns < 10 {
            columns = 10
        }
        
        keys = [UIButton]()
        for glyph in glyphs {
            let button = UIButton(type: .custom)
            button.setTitle(glyph, for: UIControlState())
            button.addTarget(self, action: #selector(keyPressed), for: .touchUpInside)
            button.addTarget(self, action: #selector(startKeyTimer), for: .touchDown)
            button.addTarget(self, action: #selector(cancelKeyTimer), for: [.touchUpInside, .touchUpOutside, .touchCancel, .touchDragExit])
            button.addTarget(self, action: #selector(textDidChange), for: [.touchCancel, .touchDragExit])
            button.titleLabel?.font = UIFont.systemFont(ofSize: glyphFontSize)
            button.layer.cornerRadius = buttonRadius
            button.layer.borderWidth = 1.0
            keys.append(button)
            contentView.addSubview(button)
        }
        
        viewWillLayoutSubviews()
        textDidChange(nil)
        glyphScroll.scrollRectToVisible(CGRect(origin: CGPoint.zero, size: glyphScroll.frame.size), animated: false)
        glyphScroll.perform(#selector(glyphScroll.flashScrollIndicators), with: nil, afterDelay: 0)
    }
    
    func characterIsDisplayable(_ character: UniChar) -> Bool {
        var characters = [character]
        var glyphs: [CGGlyph] = [0]
        for descriptor in fonts {
            let font = CTFontCreateWithFontDescriptor(descriptor, glyphFontSize, nil)
            if CTFontGetGlyphsForCharacters(font, &characters, &glyphs, 1) {
                return !(font == CTFontCreateWithName("AppleColorEmoji" as CFString?, glyphFontSize, nil))
            }
        }
        return false
    }
    
    func startKeyTimer(_ sender: UIButton) {
        keyTimer.invalidate() // prevent crash if multiple keys are pressed
        keyTimer = Timer(timeInterval: 0.5, target: self, selector: #selector(holdKey), userInfo: sender, repeats: false)
        RunLoop.current.add(keyTimer, forMode: RunLoopMode.defaultRunLoopMode)
        
        sender.backgroundColor = UIColor(white: 0.7, alpha: 1.0) // highlight
    }
    
    func cancelKeyTimer() {
        keyTimer.invalidate()
    }
    
    func holdKey() {
        floating = true
        cancelBackspaceTimer()
        
        floatingGlyph = keyTimer.userInfo as! UIButton
        floatingGlyph.layer.zPosition = 1.0
        let center = floatingGlyph.center
        
        if !(blockNumber == 0 && !isFavorites) {
            floatingGlyphIsFavorite = false
            
            floatingGlyph.titleLabel?.font = UIFont.systemFont(ofSize: 35.0)
            floatingGlyph.frame.size = self.view.frame.size
            floatingGlyph.center = center
            floatingGlyph.frame.origin.x -= glyphScroll.contentOffset.x
            floatingGlyph.backgroundColor = UIColor.clear
            floatingGlyph.layer.borderWidth = 0.0
            
            blockNumber = 0
            isFavorites = true
            setGlyphs()
        } else {
            floatingGlyphIsFavorite = true
            
            floatingGlyph.tag = keys.index(of: floatingGlyph)!
            floatingGlyph.titleLabel?.font = UIFont.systemFont(ofSize: glyphFontSize * 1.2)
            UIView.animate(withDuration: 0.3, animations: {
                self.textDidChange(nil)
                self.floatingGlyph.alpha = 0.9
                self.floatingGlyph.frame.size.width *= 1.2
                self.floatingGlyph.frame.size.height *= 1.2
                self.floatingGlyph.center = center
            })
        }
        
        resetSpaceBarLabel()
    }
    
    func panButton(_ gestureRecognizer: UIPanGestureRecognizer) {
        if floating {
            if gestureRecognizer.state == .began || gestureRecognizer.state == .changed {
                let translation = gestureRecognizer.translation(in: floatingGlyph.superview)
                floatingGlyph.center = (CGPoint(x: floatingGlyph.center.x + translation.x, y: floatingGlyph.center.y + translation.y))
                gestureRecognizer.setTranslation(CGPoint.zero, in:floatingGlyph.superview)
                
                previousIndex = floatingIndex
                let columnNumber = Int(floatingGlyph.center.x / (glyphScroll.frame.width / 10))
                let rowNumber = Int(floatingGlyph.center.y / (glyphScroll.frame.height / 3))
                floatingIndex = columnNumber + rowNumber * 10
                
                if floatingGlyphIsFavorite && floatingIndex != previousIndex {
                    floatingGlyphTimer.invalidate()
                    floatingGlyphTimer = Timer(timeInterval: 0.3, target: self, selector: #selector(rearrange), userInfo: nil, repeats: false)
                    RunLoop.current.add(floatingGlyphTimer, forMode: RunLoopMode.defaultRunLoopMode)
                }
            } else if gestureRecognizer.state == .ended {
                setFavorite()
            }
        } else if gestureRecognizer.state == .ended {
            cancelBackspaceTimer()
        }
    }
    
    func rearrange() {
        var isFinal = false
        if !(0..<favorites.count ~= floatingIndex) {
            floatingIndex = floatingGlyph.tag
        }
        
        keys.remove(at: keys.index(of: floatingGlyph)!)
        keys.insert(floatingGlyph, at: floatingIndex)
        
        if !floatingGlyphTimer.isValid {
            if previousIndex > favorites.count {
                let defaultFavorites = defaultDictionary[preferenceForFavorites] as! [String]
                floatingGlyph.setTitle(defaultFavorites[floatingGlyph.tag], for: UIControlState())
            }
            
            favorites.remove(at: floatingGlyph.tag)
            favorites.insert(floatingGlyph.title(for: UIControlState())!, at: floatingIndex)
            
            floatingGlyph.titleLabel?.font = UIFont.systemFont(ofSize: glyphFontSize)
            
            isFinal = true
        }
        
        UIView.animate(withDuration: 0.3, animations: {
            self.layoutKeys(!isFinal)
            if isFinal {
                self.floatingGlyph.alpha = 1.0
            }
            }, completion: {
                (value: Bool) in
                if isFinal {
                    self.floatingGlyph.layer.zPosition = 0
                }
        })
    }
    
    func setFavorite() {
        if !floatingGlyphIsFavorite && 0..<favorites.count ~= floatingIndex {
            favorites[floatingIndex] = floatingGlyph.title(for: UIControlState())!
            
            blockNumber = 0
            isFavorites = true
            setGlyphs()
        } else if floatingGlyphIsFavorite {
            floatingGlyphTimer.invalidate()
            rearrange()
        }
        if !floatingGlyphIsFavorite {
            floatingGlyph.removeFromSuperview()
        }
        extensionDefaults.setPersistentDomain([preferenceForFavorites : favorites], forName: Bundle.main.bundleIdentifier!)
        
        floating = false
        resetSpaceBarLabel()
    }
    
    func keyPressed(_ sender: UIButton) {
        if floating {
            floatingIndex = sender.tag // make sure the glyph stays in the same place if not moved
            setFavorite()
        } else {
            let title = sender.title(for: UIControlState())
            (textDocumentProxy as UIKeyInput).insertText(title!)
            
            perform(#selector(textDidChange), with: nil, afterDelay: 0.1) // undo highlight
        }
    }
    
    // space
    func resetSpaceBarLabel() {
        if floating && floatingGlyphIsFavorite {
            spaceBar.setTitle("Drag here for default.", for: UIControlState())
        } else if floating {
            spaceBar.setTitle("Drag here to cancel.", for: UIControlState())
        } else {
            spaceBar.setTitle("space", for: UIControlState())
        }
    }
    
    func insertSpace() {
        (textDocumentProxy as UIKeyInput).insertText(" ")
    }
    
    // return
    func insertNewline() {
        (textDocumentProxy as UIKeyInput).insertText("\n")
    }
    
    // repeat backspace while key is held down
    func startBackspaceTimer() {
        backspaceTimer = Timer(fireAt: Date(timeIntervalSinceNow: 0.7), interval: 0.1, target: textDocumentProxy, selector: #selector(textDocumentProxy.deleteBackward), userInfo: nil, repeats: true)
        RunLoop.current.add(backspaceTimer, forMode: RunLoopMode.defaultRunLoopMode)
        backspaceTimer.fire()
    }
    
    func cancelBackspaceTimer() {
        backspaceTimer?.invalidate()
    }
    
    // set theme
    override func textDidChange(_ textInput: UITextInput?) {
        var textColor, backgroundColor, altBackgroundColor: UIColor!
        let proxy = self.textDocumentProxy
        if proxy.keyboardAppearance == .dark || userPreferenceDark {
            textColor = UIColor.white
            backgroundColor = UIColor(white: 0.15, alpha: 1.0)
            altBackgroundColor = UIColor(white: 0.4, alpha: 0.4)
            
            sectionMenuBackground.backgroundColor = UIColor(white: 0.22, alpha: 1.0)
            
            spaceBar.layer.borderColor = UIColor.white.cgColor
            for button in keys {
                button.layer.borderColor = UIColor.white.cgColor
            }
            
            self.view.backgroundColor = UIColor(white: 0.1, alpha: 1.0)
            glyphScroll.indicatorStyle = .white
        } else {
            textColor = UIColor.black
            backgroundColor = UIColor.white
            altBackgroundColor = UIColor(red: 0.67, green: 0.7, blue: 0.74, alpha: 1.0)
            
            sectionMenuBackground.backgroundColor = UIColor.white
            
            spaceBar.layer.borderColor = buttonBorderColor
            for button in keys {
                button.layer.borderColor = buttonBorderColor
            }
            
            self.view.backgroundColor = UIColor(white: 0.8, alpha: 0.1)
            glyphScroll.indicatorStyle = .black
        }
        nextKeyboardButton.tintColor = textColor
        nextKeyboardButton.backgroundColor = altBackgroundColor
        sectionsButton.setTitleColor(textColor, for: UIControlState())
        sectionsButton.backgroundColor = altBackgroundColor
        spaceBar.setTitleColor(textColor, for: UIControlState())
        spaceBar.backgroundColor = backgroundColor
        backspace.setTitleColor(textColor, for: UIControlState())
        backspace.backgroundColor = altBackgroundColor
        returnKey.setTitleColor(textColor, for: UIControlState())
        returnKey.backgroundColor = altBackgroundColor
        for button in keys {
            button.setTitleColor(textColor, for: UIControlState())
            if button != floatingGlyph || floatingGlyphIsFavorite { // make sure floatingGlyph has clear background if two keys were held
                button.backgroundColor = backgroundColor
            }
        }
        for button in sectionMenuButtons {
            button.setTitleColor(textColor, for: UIControlState())
        }
    }
}
