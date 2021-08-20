//
//  ViewController.swift
//  Stargazers
//
//  Created by Luca Severini on 14-Aug-2021.
//  lucaseverini@mac.com
//

import UIKit

// This could have been a TableViewController but doesn't really makes much difference
class ViewController: UIViewController
{
    @IBOutlet weak var navBar: UINavigationBar!
    @IBOutlet weak var tableView: UITableView!

    var spinner: SpinnerViewController!
    var refreshControl: UIRefreshControl!
    var stargazerSession: URLSession!
    var avatarSession: URLSession!
    var spinnerLock: NSLock!
    var loadLock: NSLock!
    var loadDelay: Double!
    var loadAvatarDelay: Double!
    var spinnerDelay: Double!

    var stargazers = [Stargazer]()
    var bottomPullDown = false
    var pageNum = 1
    var stopLoading = false

    override func viewDidLoad()
    {
        super.viewDidLoad()

        spinnerLock = NSLock()
        loadLock = NSLock()

        navBar.topItem?.title = (Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as! String)

        tableView.delegate = self

        refreshControl = UIRefreshControl()
        refreshControl.attributedTitle = NSAttributedString(string: "Pull to reload")
        refreshControl.addTarget(self, action: #selector(refresh(_:)), for: .valueChanged)
        tableView.refreshControl = refreshControl

        let storyBoard : UIStoryboard = UIStoryboard(name: "Main", bundle:nil)
        spinner = (storyBoard.instantiateViewController(withIdentifier: "SpinnerViewController") as! SpinnerViewController)

        let stargazerSessionConfig = URLSessionConfiguration.default
        stargazerSessionConfig.httpMaximumConnectionsPerHost = 1
        stargazerSessionConfig.timeoutIntervalForResource = 120
        stargazerSessionConfig.timeoutIntervalForRequest = 60
        stargazerSessionConfig.requestCachePolicy = .reloadIgnoringLocalCacheData
        stargazerSession = URLSession(configuration: stargazerSessionConfig)

        let avatarSessionConfig = URLSessionConfiguration.default
        avatarSessionConfig.httpMaximumConnectionsPerHost = 5
        avatarSessionConfig.timeoutIntervalForResource = 60
        avatarSessionConfig.timeoutIntervalForRequest = 30
        avatarSessionConfig.requestCachePolicy = .reloadIgnoringLocalCacheData
        avatarSession = URLSession(configuration: avatarSessionConfig)
    }
    
    override func viewWillAppear(_ animated: Bool)
    {
        super.viewWillAppear(animated)

        setFrames()
    }

    override func viewDidAppear(_ animated: Bool)
    {
        super.viewDidAppear(animated)

        // To avoid the blocks called with DispatchQueue.main.async to block each other
        RunLoop.current.perform(
        {
            if self.loadLock.try()
            {
                self.firstStargazersLoad()
            }
        })
    }

    override func didReceiveMemoryWarning()
    {
        super.didReceiveMemoryWarning()
    }

    // Portrait only for the iPhone
    override var supportedInterfaceOrientations:UIInterfaceOrientationMask
    {
        return UIDevice.current.userInterfaceIdiom == .pad ? UIInterfaceOrientationMask.all : UIInterfaceOrientationMask.portrait
    }

    // Called when pulling down the stargazers list
    @objc func refresh(_ sender: AnyObject)
    {
        // To avoid interference with UIAlerts that may happear during stargazers loading
        RunLoop.current.perform(
        {
            self.tableView.refreshControl!.endRefreshing()
        })

        if loadLock.try()
        {
            firstStargazersLoad()
        }
    }

    // Called when the X navbar button is tapped
    @IBAction func barButtonClearOrStop(_ sender: AnyObject)
    {
        if loadLock.try() // If no current loading delete the list
        {
            stargazers.removeAll()
            tableView.reloadData()

            loadLock.unlock()
        }
        else // Stop the loading
        {
            stopLoading = true
        }
    }

    // Called when the Info navbar button is tapped
    @IBAction func barButtonInfo(_ sender: AnyObject)
    {
        showInformation()
    }

    // Called when the Gear navbar button is tapped
    @IBAction func barButtonConfiguration(_ sender: AnyObject)
    {
        showConfiguration()
    }

    // Set few frames accordingly with the screen of the device
    func setFrames()
    {
        let window = UIApplication.shared.windows.first!
        let screenSize = window.frame.size
        let safeArea = window.safeAreaInsets

        navBar.frame.origin.y = safeArea.top
        navBar.frame.origin.x = safeArea.left
        navBar.frame.size.width = screenSize.width - navBar.frame.origin.x - safeArea.right

        tableView.frame.origin.y = safeArea.top + navBar.frame.size.height
        tableView.frame.origin.x = safeArea.left
        tableView.frame.size.height = screenSize.height - (tableView.frame.origin.y + safeArea.bottom)
        tableView.frame.size.width = screenSize.width - tableView.frame.origin.x - safeArea.right
    }

    func firstStargazersLoad()
    {
        stargazers.removeAll()
        tableView.reloadData()

        pageNum = 1

        let config = UserDefaults.standard
        loadDelay = config.double(forKey: "LoadDelay")
        loadAvatarDelay = config.double(forKey: "LoadAvatarDelay")
        spinnerDelay = config.double(forKey: "SpinnerDelay")

        loadStargazers()
    }

    // Synch loading of a page of stargazers or all of them (loops until no more)
    // Default values
    // githubUrlEdit.text = "https://api.github.com/repos/[owner]/[repo]/stargazers"
    // ownerEdit.text = "octocat"
    // repoEdit.text = "hello-world"
    func loadStargazers()
    {
        stopLoading = false

        let config = UserDefaults.standard
        let url = config.string(forKey: "GithubUrl") ?? ""
        let owner = config.string(forKey: "Owner") ?? ""
        let repo = config.string(forKey: "Repo") ?? ""
        let authToken = config.string(forKey: "AuthToken") ?? ""
        let loadAllStargazers = config.bool(forKey: "LoadAll")

        if url.isEmpty || owner.isEmpty || repo.isEmpty
        {
            let alert = UIAlertController(title: "Error",
                                          message: "Invalid configuration.\nPlease configure the app correctly.",
                                          preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
            present(alert, animated: true, completion: nil)

            return
        }

        let batchSize = loadAllStargazers ? 100 : max(10, Int(tableView.frame.height / tableView.rowHeight) * 2)

        prepareSpinner(delay: spinnerDelay, message: loadAllStargazers ? "Loading all stargazers" : "Loading stargazers")

        var loadingDone = 0
        var task: URLSessionDataTask!
        DispatchQueue.global().async
        {
            while loadingDone == 0 && self.stopLoading == false
            {
                var realUrl = url.appending("?page=[page]&per_page=[per_page]")
                realUrl = realUrl.replacingOccurrences(of: "[owner]", with: owner)
                realUrl = realUrl.replacingOccurrences(of: "[repo]", with: repo)
                realUrl = realUrl.replacingOccurrences(of: "[per_page]", with: String(batchSize))
                realUrl = realUrl.replacingOccurrences(of: "[page]", with: String(self.pageNum))
                let request = NSMutableURLRequest(url:URL(string: realUrl)!)
                request.httpMethod = "GET"

                print("Request: \(request.url!.absoluteString)")

                if authToken.isEmpty == false
                {
                    request.addValue("token " + authToken, forHTTPHeaderField: "Authorization")
                }

                let semaphore = DispatchSemaphore(value: 0)

                task = self.stargazerSession.dataTask(with: request as URLRequest)
                {
                    data, response, error in

                    if self.loadDelay != 0
                    {
                        Thread.sleep(forTimeInterval: self.loadDelay)
                    }

                    if error != nil
                    {
                        print("Stargazers download error: \(error!.localizedDescription)")

                        if error!.localizedDescription != "cancelled"
                        {
                            DispatchQueue.main.async
                            {
                                let msg = "\(error!.localizedDescription)\nURL: \(url)"

                                let alert = UIAlertController(title: "Error",
                                                              message: msg,
                                                              preferredStyle: .alert)
                                alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                                self.present(alert, animated: true, completion: nil)
                            }

                            loadingDone = -1
                        }
                        else
                        {
                            loadingDone = -2
                        }

                        semaphore.signal()

                        return
                    }

                    var indexPaths = [IndexPath]()
                    var newStargazers = [Stargazer]()

                    do {
                        let json = try JSONSerialization.jsonObject(with: data!, options: []) as? NSArray
                        if let parseJSON = json
                        {
                            let list = parseJSON as! [NSDictionary]
                            for item in list
                            {
                                if item["type"] as? String == "User"
                                {
                                    let login = item["login"] as! String
                                    let avatar = item["avatar_url"] as! String

                                    assert(login.count != 0)
                                    assert(avatar.count !=  0)

                                    newStargazers.append(Stargazer(login, avatar: avatar))

                                    indexPaths.append(IndexPath(row: self.stargazers.count + newStargazers.count - 1, section: 0))
                                }
                                else
                                {
                                    print("Invalid stargazer: \(item)")
                                }
                            }
                        }
                        else
                        {
                            let json = try JSONSerialization.jsonObject(with: data!, options: []) as? [String:AnyObject]
                            if let parseJSON = json
                            {
                                var msg = parseJSON["message"] as? String ?? ""
                                if msg.contains("API rate limit")
                                {
                                    let httpResponse = response as? HTTPURLResponse
                                    let rateLimit = (httpResponse?.value(forHTTPHeaderField: "x-ratelimit-limit") ?? "0")
                                    let rateRemain = (httpResponse?.value(forHTTPHeaderField: "x-ratelimit-remaining") ?? "0")
                                    let rateReset = (httpResponse?.value(forHTTPHeaderField: "x-ratelimit-reset") ?? "0")
                                    let date = Date(timeIntervalSince1970: TimeInterval(Int(rateReset)!))
                                    let diff = Int(date.timeIntervalSinceNow)
                                    print("Rate limit: \(rateLimit) \(rateRemain) \(diff)")

                                    msg = "API rate limit (\(rateLimit)) exceeded.\nMust wait \(diff) seconds.\nURL: \(url)"
                                }
                                else if msg.count == 0
                                {
                                    msg = "Generic error.\nURL: \(url)"
                                }
                                else
                                {
                                    msg = "Error: \(msg)\nURL: \(url)"
                                }

                                DispatchQueue.main.async
                                {
                                    let alert = UIAlertController(title: "Network Error",
                                                                  message: msg,
                                                                  preferredStyle: .alert)
                                    alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                                    self.present(alert, animated: true, completion: nil)
                                }
                            }
                        }
                    }
                    catch
                    {
                        print("JSONSerialization.jsonObject error: \(error.localizedDescription)")
                    }

                    self.stargazers.append(contentsOf: newStargazers)

                    if indexPaths.count > 0
                    {
                        print("Loaded: \(indexPaths.count)  page: \(self.pageNum)  total: \(self.stargazers.count)")

                        self.pageNum = self.pageNum + 1

                        DispatchQueue.main.async
                        {
                            self.tableView.beginUpdates()
                            self.tableView.insertRows(at: indexPaths, with: .fade)
                            self.tableView.endUpdates()

                            if loadAllStargazers && self.spinner.label != nil
                            {
                                let msg = "Loading all stargazers: \(self.stargazers.count)"
                                self.spinner.label.text = msg
                            }
                        }

                        if loadAllStargazers == false
                        {
                            loadingDone = 1
                        }
                    }
                    else
                    {
                        loadingDone = 1

                        print("All stargazers loaded: (\(self.stargazers.count))")
                    }

                    if loadingDone == 1 && self.stargazers.count == 0
                    {
                        print("No stargazers found.")

                        DispatchQueue.main.async
                        {
                            let alert = UIAlertController(title: "No Stargazers found.",
                                                          message: "No stargazers found for repository \(repo) of user \(owner).",
                                                          preferredStyle: .alert)
                            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                            self.present(alert, animated: true, completion: nil)
                        }
                    }

                    semaphore.signal()
                }
                task.resume()

                if semaphore.wait(timeout: .now() + 30) == .timedOut
                {
                    task.cancel()

                    loadingDone = -1

                    print("Timeout. Stargazers loaded: (\(self.stargazers.count))")

                    DispatchQueue.main.async
                    {
                        let alert = UIAlertController(title: "Network Error",
                                                      message: "Timeout",
                                                      preferredStyle: .alert)
                        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                        self.present(alert, animated: true, completion: nil)
                     }
                }

                if self.stopLoading
                {
                    loadingDone = -2

                    print("Stopped. Stargazers loaded: (\(self.stargazers.count))")

                    DispatchQueue.main.async
                    {
                        let alert = UIAlertController(title: "Stopped",
                                                      message: "",
                                                      preferredStyle: .alert)
                        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                        self.present(alert, animated: true, completion:
                        {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0)
                            {
                                alert.dismiss(animated: true, completion: nil)
                            }
                        })
                    }
                }
            }

            if loadAllStargazers == false
            {
                self.deleteSpinner()

                self.loadLock.unlock()
            }
        }

        // Don't stay in this loop for just a single dowlload
        while loadAllStargazers && loadingDone == 0
        {
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.01))

            if stopLoading
            {
                task.cancel()
            }
        }

        if loadAllStargazers
        {
            deleteSpinner()

            loadLock.unlock()
        }

        if stopLoading
        {
            stargazers.removeAll()
            tableView.reloadData()

            stopLoading = false
        }
    }

    // Asynch loading of the stargazer avatar
    func loadAvatar(cell: TableCell, stargazer: Stargazer)
    {
        if stargazer.avatarImage != nil
        {
            cell.avatar.image = stargazer.avatarImage
            cell.avatar.setNeedsDisplay()
        }
        else if stargazer.avatarError
        {
            cell.avatar.tintColor = UIColor.systemRed
            cell.avatar.setNeedsDisplay()
        }
        else
        {
            if stargazer.avatarUrl != nil
            {
                let curUser = cell.name.text

                let imgSize = cell.avatar.frame.size // Take the size here to avoid issues with thread checker
                let request = NSMutableURLRequest(url: stargazer.avatarUrl!)
                avatarSession.dataTask(with: request as URLRequest)
                {
                    data, response, error in

                    if self.loadAvatarDelay != 0
                    {
                        Thread.sleep(forTimeInterval: self.loadAvatarDelay)
                    }

                    DispatchQueue.main.async
                    {
                        if error != nil
                        {
                            print("Avatar download error: \(error!.localizedDescription) \(stargazer)")

                            stargazer.avatarError = true

                            if cell.name.text == curUser // Update the image only if still the same stargazer
                            {
                                cell.avatar.tintColor = UIColor.systemRed
                                cell.avatar.setNeedsDisplay()
                            }
                        }
                        else
                        {
                            if let avatarImg = UIImage(data: data ?? Data())
                            {
                                // Let's save some space
                                stargazer.avatarImage = avatarImg.resizeImage(size: imgSize)

                                // print("Avatar downloaded: \(stargazer)")

                                if cell.name.text == curUser // Update the image only if still the same stargazer
                                {
                                    cell.avatar.image = stargazer.avatarImage
                                }
                            }
                            else
                            {
                                print("Invalid avatar image: \(stargazer)")
                            }
                        }
                    }
                }.resume()
            }
        }
    }

    // Prepares the spinner and set a timer to show it after some delay
    func prepareSpinner(delay: Double, message: String! = nil)
    {
        if spinner.hidden
        {
            spinner.hidden = false
            spinner.message = message

            spinner.timer = Timer(timeInterval: delay, repeats: false)
            { _ in
                if self.spinner.hidden == false
                {
                    self.addChild(self.spinner)
                    self.spinner.view.frame = self.view.frame
                    self.view.addSubview(self.spinner.view)
                    self.spinner.didMove(toParent: self)
                }
            }
            // Add the timer to the run loop to have it executed at its time
            RunLoop.current.add(spinner.timer, forMode: .common)
        }
    }

    // Removes the spinner if it has been shown
    func deleteSpinner()
    {
        if spinner.hidden == false
        {
            spinner.hidden = true

            spinner.timer?.invalidate()

            DispatchQueue.main.async
            {
                self.spinner.willMove(toParent: nil)
                self.spinner.view.removeFromSuperview()
                self.spinner.removeFromParent()
            }
        }
    }

    // Shows some information
    func showInformation()
    {
        DispatchQueue.main.async
        {
            let appName = (Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as! String)
            let appVersion = (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String)
            let appBuild = (Bundle.main.object(forInfoDictionaryKey: "CFBundleBuildVersion") as! String)
            let msg = "Version: \(appVersion)\nBuild: \(appBuild)"
            let alert = UIAlertController(title: appName,
                                          message: msg,
                                          preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
            self.present(alert, animated: true, completion: nil)
        }
    }

    // Shows the configuration dialog and waits until is done
    func showConfiguration()
    {
        let dialogWindow = UIWindow(frame: UIScreen.main.bounds)
        dialogWindow.windowLevel = .statusBar

        let storyBoard : UIStoryboard = UIStoryboard(name: "Main", bundle:nil)
        let controller = storyBoard.instantiateViewController(withIdentifier: "ConfigurationController") as! ConfigurationController

        UIView.transition(with: dialogWindow, duration: 0.3, options: .transitionCrossDissolve, animations:
        {
            dialogWindow.rootViewController = controller
            dialogWindow.makeKeyAndVisible()
        },
        completion: nil)

        // Waits for the user to press Confirm or Cancel...
        controller.semaphore = DispatchSemaphore(value: 0)
        while controller.semaphore.wait(timeout: .now()) != DispatchTimeoutResult.success
        {
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.01))
        }

        // Dismiss the dialog
        dialogWindow.resignKey()

        if controller.response == 1 // Confirm
        {
            let config = UserDefaults.standard
            loadDelay = config.double(forKey: "LoadDelay")
            loadAvatarDelay = config.double(forKey: "LoadAvatarDelay")
            spinnerDelay = config.double(forKey: "SpinnerDelay")
        }
        else if controller.response == 2 // Reload
        {
            RunLoop.current.perform(
            {
                if self.loadLock.try()
                {
                    self.firstStargazersLoad()
                }
            })
        }
    }
}

// Contains the callbacks to manage the table
extension ViewController: UITableViewDataSource, UITableViewDelegate, UIScrollViewDelegate
{
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell
    {
        let cell = tableView.dequeueReusableCell(withIdentifier: "TableCell", for: indexPath) as! TableCell
        cell.avatar.image = UIImage(systemName: "person")!
        cell.name.text = stargazers[indexPath.row].name

        // Load the avatar
        loadAvatar(cell: cell, stargazer: stargazers[indexPath.row])

        // Load more stargazers if is the last row
        if indexPath.row >= stargazers.count - 3
        {
            if loadLock.try()
            {
                loadStargazers()
            }
        }

        return cell
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int
    {
        return stargazers.count // Pay attention that this array doesn't get resized between tableView.insertRows and this call
    }

    // Try to load more stargazers when the bottom of tableview is reached.
    // Not really necessary and if removed the loadLock can be removed too
    func scrollViewDidScroll(_ scrollView: UIScrollView)
    {
        let val = scrollView.contentSize.height - scrollView.contentOffset.y
        if val < scrollView.frame.size.height - (tableView.rowHeight * 2)
        {
            bottomPullDown = true
        }

        if bottomPullDown && val == scrollView.frame.size.height
        {
            bottomPullDown = false

            if loadLock.try()
            {
                loadStargazers()
            }
        }
    }
}

extension UIImage
{
    func resizeImage(size: CGSize) -> UIImage {
        let image = UIGraphicsImageRenderer(size: size).image
        { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }

        return image.withRenderingMode(renderingMode)
    }
}

