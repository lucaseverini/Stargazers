//
//  SpinnerViewController.swift
//  Stargazers
//
//  Created by Luca Severini on 14-Aug-2021.
//  lucaseverini@mac.com
//

import UIKit

class SpinnerViewController: UIViewController
{
    @IBOutlet weak var backgroundView: UIView!
    @IBOutlet weak var wheel: UIActivityIndicatorView!
    @IBOutlet weak var label: UILabel!

    var timer: Timer!
    var hidden: Bool = true
    var message: String!

    override func viewDidLoad()
    {
        super.viewDidLoad()

        view.backgroundColor = UIColor(white: 0, alpha: 0.0)
        view.isUserInteractionEnabled = false

        backgroundView.backgroundColor = UIColor(white: 0.9, alpha: 0.9)

        // Done in storyboard
        //backgroundView.layer.cornerRadius = 8.0
        //backgroundView.layer.masksToBounds = true
    }

    override func viewWillAppear(_ animated: Bool)
    {
        super.viewWillAppear(animated)

        wheel.startAnimating()

        if message != nil
        {
            label.text = message
        }
    }

    override func viewWillDisappear(_ animated: Bool)
    {
        super.viewWillAppear(animated)

        wheel.stopAnimating()
    }
}

