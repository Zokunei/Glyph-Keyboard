//  HowToViewController.swift
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

class HowToViewController: UIViewController, UIScrollViewDelegate {
    
    let scrollView = UIScrollView()
    var labels: [UILabel]!
    let usageLabel = UILabel()
    let pageControl = UIPageControl()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let stepOne = UILabel(), stepTwo = UILabel(), stepThree = UILabel(), stepFour = UILabel(), stepFive = UILabel(), stepSix = UILabel(), conclusion = UILabel()
        labels = [stepOne, stepTwo, stepThree, stepFour, stepFive, stepSix, usageLabel, conclusion]
        stepOne.text = "Step 1: Go to Settings."
        stepTwo.text = "Step 2: Tap General."
        stepThree.text = "Step 3: Tap Keyboard."
        stepFour.text = "Step 4: Tap Keyboards."
        stepFive.text = "Step 5: Tap Add New Keyboard."
        stepSix.text = "Step 6: Tap Glyph Keyboard."
        conclusion.text = "You will then be able to access Glyph Keyboard by pressing the globe key on the system keyboard."
        usageLabel.text = "The ≣ button toward the bottom-left of the keyboard can be used to switch between sets of glyphs. Tap the ≣ button to continue to the next set, or tap and hold to reveal a menu of all the sets. The first set is your Favorites. Tap and hold a glyph in any other set to position it on your Favorites. Tap and hold a Favorite to reposition it. Dragging a Favorite to the bottom of the screen will reset it to the default glyph for its position. All sets except Favorites can be scrolled through horizontally."
        for label in labels {
            label.textColor = UIColor(white: 0.4, alpha: 1.0)
            label.font = UIFont.systemFont(ofSize: 18.0)
            label.textAlignment = .center
            label.numberOfLines = 0
            scrollView.addSubview(label)
        }
        
        pageControl.numberOfPages = 2
        pageControl.pageIndicatorTintColor = UIColor(white: 0.4, alpha: 0.5)
        pageControl.currentPageIndicatorTintColor = UIColor(white: 0.4, alpha: 1.0)
        self.view.addSubview(pageControl)
        
        scrollView.delegate = self
        scrollView.isPagingEnabled = true
        scrollView.showsHorizontalScrollIndicator = false
        self.view.addSubview(scrollView)
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        
        scrollView.frame = self.view.frame
        scrollView.frame.origin.y = 0.0
        scrollView.contentSize = CGSize(width: self.view.frame.width * CGFloat(pageControl.numberOfPages), height: self.view.frame.height)
        
        var marginFrame = self.view.frame
        marginFrame.size.width -= 20.0
        for (index, label) in labels.enumerated() {
            label.frame.size.width = marginFrame.width
            label.frame.size.height = label.textRect(forBounds: marginFrame, limitedToNumberOfLines: 0).height
            let yMultiplier = CGFloat(0.1 + 0.21 * Double(index))
            label.center = CGPoint(x: self.view.center.x, y: scrollView.center.y * yMultiplier)
        }
        
        pageControl.center.x = self.view.center.x
        let labelBottom = labels[labels.count - 1].frame.origin.y + labels[labels.count - 1].frame.height
        pageControl.center.y = labelBottom + (self.view.frame.height - labelBottom) * 0.5
        
        usageLabel.center = CGPoint(x: scrollView.center.x + scrollView.frame.width, y: scrollView.center.y - (scrollView.frame.height - pageControl.frame.origin.y) * 0.5)
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        pageControl.currentPage = Int(scrollView.contentOffset.x / scrollView.frame.width)
    }
}
