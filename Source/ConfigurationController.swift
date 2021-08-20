//
//  ConfigurationController.swift
//  Stargazers
//
//  Created by Luca Severini on 15-Aug-2021.
//  lucaseverini@mac.com
//

import UIKit

class ConfigurationController: UIViewController, UITextViewDelegate, UITextFieldDelegate
{
    @IBOutlet weak var dialog: UIView!
    @IBOutlet weak var reloadBtn: UIButton!
    @IBOutlet weak var confirmBtn: UIButton!
    @IBOutlet weak var cancelBtn: UIButton!
    @IBOutlet weak var ownerEdit: UITextField!
    @IBOutlet weak var repoEdit: UITextField!
    @IBOutlet weak var authTokenEdit: UITextField!
    @IBOutlet weak var githubUrlEdit: UITextField!
    @IBOutlet weak var loadDelayEdit: UITextField!
    @IBOutlet weak var loadAvatarDelayEdit: UITextField!
    @IBOutlet weak var spinnerDelayEdit: UITextField!
    @IBOutlet weak var paginationSwitch: UISwitch!

    let checkIfConfigurationChanged = false 

    var semaphore: DispatchSemaphore!
    var response: Int = 0
    var prevGithubUrlEdit: String!
    var prevAuthTokenEdit: String!
    var prevOwnerEdit: String!
    var prevRepoEdit: String!
    var currentEdit: UITextField!
    var scrollOffset: CGFloat = 0

    override func viewDidLoad()
    {
        super.viewDidLoad()

        let tap = UITapGestureRecognizer(target: self, action: #selector(UIInputViewController.dismissKeyboard))
        view.addGestureRecognizer(tap)

        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)

        self.githubUrlEdit.delegate = self
        self.authTokenEdit.delegate = self
        self.ownerEdit.delegate = self
        self.repoEdit.delegate = self
        self.loadDelayEdit.delegate = self
        self.loadAvatarDelayEdit.delegate = self
        self.spinnerDelayEdit.delegate = self
    }

    override func viewWillDisappear(_ animated: Bool)
    {
        super.viewWillDisappear(animated)

        NotificationCenter.default.removeObserver(self)
    }

    override func viewWillAppear(_ animated: Bool)
    {
        super.viewWillAppear(animated)

        loadConfiguration()
    }

    override func viewDidAppear(_ animated: Bool)
    {
        super.viewDidAppear(animated)
    }

    override func didReceiveMemoryWarning()
    {
        super.didReceiveMemoryWarning()
    }

    override var supportedInterfaceOrientations:UIInterfaceOrientationMask
    {
        return UIInterfaceOrientationMask.portrait
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool
    {
        return false
    }

    func textFieldShouldClear (_ textField: UITextField) -> Bool
    {
        return true
    }

    func textFieldDidEndEditing(_ textField: UITextField)
    {
        currentEdit = nil
    }

    func textFieldDidBeginEditing(_ textField: UITextField)
    {
        currentEdit = textField
    }

    @objc func keyboardWillShow(notification: NSNotification)
    {
        let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue
        let keyboardHeight = keyboardFrame!.cgRectValue.height
        let keyboardTop = view.frame.size.height - keyboardHeight
        let fieldBottom = (currentEdit.frame.origin.y + currentEdit.frame.size.height) + dialog.frame.origin.y

        let offset = fieldBottom - (keyboardTop - 20)
        if offset > 0 || scrollOffset != 0
        {
            let diff = offset - scrollOffset
            scrollOffset += diff

            UIView.animate(withDuration: 0.1, animations:
            { () -> Void in
                self.dialog.frame.origin.y -= diff
                self.dialog.layoutIfNeeded()
            })
        }
    }

    @objc func keyboardWillHide(notification: NSNotification)
    {
        if scrollOffset != 0
        {
            UIView.animate(withDuration: 0.1, animations:
            { () -> Void in
                self.dialog.frame.origin.y += self.scrollOffset
                self.dialog.layoutIfNeeded()
            })

            scrollOffset = 0
        }
    }

    @objc func dismissKeyboard()
    {
        view.endEditing(true)
    }

    @IBAction func cancelAction(_ sender: AnyObject?)
    {
        response = 0

        dismiss()
    }

    @IBAction func confirmAction(_ sender: AnyObject?)
    {
        if checkConfiguration(1) && saveConfiguration()
        {
            response = 1

            dismiss()
        }
    }

    @IBAction func reloadAction(_ sender: AnyObject?)
    {
        if checkConfiguration(2) && saveConfiguration()
        {
            response = 2

            dismiss()
        }
    }

    func dismiss()
    {
        githubUrlEdit.resignFirstResponder()

        UIView.animate(withDuration: 0.35, delay: 0.0, options: .curveLinear, animations:
        {
            self.view.alpha = 0
        },
        completion:
        {_ in
            self.view.removeFromSuperview()
            self.semaphore.signal()
        })
    }

    func loadConfiguration()
    {
        let config = UserDefaults.standard
        githubUrlEdit.text = config.string(forKey: "GithubUrl")!
        ownerEdit.text = config.string(forKey: "Owner")!
        repoEdit.text = config.string(forKey: "Repo")!
        authTokenEdit.text = config.string(forKey: "AuthToken")!
        loadDelayEdit.text = config.string(forKey: "LoadDelay")!
        loadAvatarDelayEdit.text = config.string(forKey: "LoadAvatarDelay")!
        spinnerDelayEdit.text = config.string(forKey: "SpinnerDelay")!
        paginationSwitch.setOn(config.bool(forKey: "LoadAll"), animated: false)

        if loadDelayEdit.text!.isEmpty
        {
            loadDelayEdit.text = "0"
        }

        if loadAvatarDelayEdit.text!.isEmpty
        {
            loadAvatarDelayEdit.text = "0"
        }

        if spinnerDelayEdit.text!.isEmpty
        {
            spinnerDelayEdit.text = "0"
        }

        if checkIfConfigurationChanged
        {
            prevGithubUrlEdit = githubUrlEdit.text
            prevAuthTokenEdit = authTokenEdit.text
            prevOwnerEdit = ownerEdit.text
            prevRepoEdit = repoEdit.text
        }
    }

    func saveConfiguration() -> Bool
    {
        let config = UserDefaults.standard
        config.set(githubUrlEdit.text, forKey: "GithubUrl")
        config.set(ownerEdit.text, forKey: "Owner")
        config.set(repoEdit.text, forKey: "Repo")
        config.set(authTokenEdit.text, forKey: "AuthToken")
        config.set(loadDelayEdit.text, forKey: "LoadDelay")
        config.set(loadAvatarDelayEdit.text, forKey: "LoadAvatarDelay")
        config.set(spinnerDelayEdit.text, forKey: "SpinnerDelay")
        config.set(paginationSwitch.isOn, forKey: "LoadAll")

        if config.synchronize()
        {
            return true
        }
        else
        {
            let alert = UIAlertController(title: "Error", message: "Configuration not saved.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Cancel", style: .default, handler: nil))
            present(alert, animated: true, completion: nil)

            return false
        }
    }

    func checkConfiguration(_ buttonselector: Int) -> Bool
    {
        if githubUrlEdit.text!.isEmpty
        {
            return synchAlert(title: "Error",
                              message: "The github URL can't be empty.",
                              button2: "Cancel")
        }

        if authTokenEdit.text!.count != 0 && authTokenEdit.text!.count != 40
        {
            return synchAlert(title: "Error",
                              message: "The token can be empty or 40 chars long.",
                              button2: "Cancel")
        }

        if ownerEdit.text!.isEmpty
        {
            return synchAlert(title: "Error",
                              message: "The user-name of the repository owner can't be empty.",
                              button2: "Cancel")
        }

        if repoEdit.text!.isEmpty
        {
            return synchAlert(title: "Error",
                              message: "The repository name can't be empty.",
                              button2: "Cancel")
        }

        if Double(loadDelayEdit.text!) ?? 0 < 0 || Double(loadDelayEdit.text!) ?? 0 > 5
        {
            return synchAlert(title: "Error",
                              message: "The stargazers load delay can be between 0 and 5 seconds (decimals allowed).",
                              button2: "Cancel")
        }

        if Double(loadAvatarDelayEdit.text!) ?? 0 < 0 || Double(loadAvatarDelayEdit.text!) ?? 0 > 5
        {
            return synchAlert(title: "Error",
                              message: "The avatar load delay can be between 0 and 5 seconds (decimals allowed).",
                              button2: "Cancel")
         }

        if Double(spinnerDelayEdit.text!) ?? 0 < 0 || Double(spinnerDelayEdit.text!) ?? 0 > 10
        {
            return synchAlert(title: "Error",
                              message: "The spinner wait delay can be between 0 and 10 seconds (decimals allowed).",
                              button2: "Cancel")
        }

        var configChanged = true
        if checkIfConfigurationChanged
        {
            if githubUrlEdit.text!.compare(prevGithubUrlEdit) != .orderedSame
            {
                configChanged = true
            }
            else if authTokenEdit.text!.compare(prevAuthTokenEdit) != .orderedSame
            {
                configChanged = true
            }
            else if ownerEdit.text!.caseInsensitiveCompare(prevOwnerEdit!) != .orderedSame
            {
                configChanged = true
            }
            else if repoEdit.text!.caseInsensitiveCompare(prevRepoEdit!) != .orderedSame
            {
                configChanged = true
            }
            else
            {
                configChanged = false
            }
        }

        if configChanged
        {
            var url = githubUrlEdit.text!
            url = url.replacingOccurrences(of: "[owner]", with: ownerEdit.text!)
            url = url.replacingOccurrences(of: "[repo]", with: repoEdit.text!)
            url = url.replacingOccurrences(of: "[per_page]", with: String(1))
            url = url.replacingOccurrences(of: "[page]", with: String(1))
            let request = NSMutableURLRequest(url:URL(string: url)!)
            request.httpMethod = "GET"

            print("Request: \(request.url!.absoluteString)")

            if authTokenEdit.text!.isEmpty == false
            {
                request.addValue("token " + authTokenEdit.text!, forHTTPHeaderField: "Authorization")
            }

            let semap = DispatchSemaphore(value: 0)

            var connError: NSError!
            let session = URLSession(configuration: URLSessionConfiguration.default)
            session.dataTask(with: request as URLRequest)
            {
                data, response, error in

                if error != nil
                {
                    connError = error! as NSError
                }
                else
                {
                    do {
                        let json = try JSONSerialization.jsonObject(with: data!, options: []) as? [String:AnyObject]
                        if json != nil
                        {
                            let info = [NSLocalizedDescriptionKey : json?["message"] as? String ?? "Generic error"]
                            connError = NSError(domain: NSURLErrorDomain, code: 1, userInfo: info)
                        }
                    }
                    catch
                    {
                        connError = error as NSError
                    }
                }

                semap.signal()
            }.resume()

            let response = semap.wait(timeout: .now() + 20) // 20 seconds seems enough
            if response == .timedOut && connError == nil
            {
                let info = [NSLocalizedDescriptionKey : "Timeout"]
                connError = NSError(domain: NSURLErrorDomain, code: 1, userInfo: info)
            }

            if connError != nil
            {
                let errorMsg = connError.localizedDescription
                let msg = "\(errorMsg)\n\nThe URL \"\(request.url!.absoluteString)\" may not be correct."
                return synchAlert(title: "Error", message: msg, button1: buttonselector == 1 ? "Confirm" : "Reload", button2: "Cancel")
            }
            else
            {
                let msg = "The URL \"\(request.url!.absoluteString)\" is correct."
                return synchAlert(title: "Everything OK", message: msg, button1: buttonselector == 1 ? "Confirm" : "Reload", button2: "Cancel")
            }
        }

        return true
    }

    func synchAlert(title: String?, message: String!, button1: String? = nil, button2: String? = nil) -> Bool // Confirm->true Cancel->false
    {
        var alertResponse = true

        let alertSemaphore = DispatchSemaphore(value: 0)

        let alert = UIAlertController(title: title ?? "", message: message, preferredStyle: .alert)

        if button1 != nil
        {
            alert.addAction(UIAlertAction(title: button1, style: .default, handler:
            { _ in
                alertResponse = true
                alertSemaphore.signal()
            }))
        }

        if button2 != nil
        {
            alert.addAction(UIAlertAction(title: button2, style: .cancel, handler:
            { _ in
                alertResponse = false
                alertSemaphore.signal()
            }))
        }

        present(alert, animated: true, completion: nil)

        while alertSemaphore.wait(timeout: .now()) != .success
        {
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.01))
        }

        return alertResponse
    }
}
