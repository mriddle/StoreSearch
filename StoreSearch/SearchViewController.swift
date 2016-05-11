//
//  ViewController.swift
//  StoreSearch
//
//  Created by Matthew Riddle on 10/05/2016.
//  Copyright © 2016 Matthew Riddle. All rights reserved.
//

import UIKit

class SearchViewController: UIViewController {

  @IBOutlet weak var searchBar: UISearchBar!
  @IBOutlet weak var tableView: UITableView!
  @IBOutlet weak var segmentedControl: UISegmentedControl!

  var dataTask: NSURLSessionDataTask?
  var searchResults = [SearchResult]()
  var hasSearched = false
  var isLoading = false

  var landscapeViewController: LandscapeViewController?

  struct TableViewCellIdentifiers {
    static let searchResultCell = "SearchResultCell"
    static let nothingFoundCell = "NothingFoundCell"
    static let loadingCell = "LoadingCell"
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    tableView.contentInset = UIEdgeInsets(top: 108, left:0, bottom:0, right: 0)
    tableView.rowHeight = 80

    var cellNib = UINib(nibName: TableViewCellIdentifiers.searchResultCell, bundle: nil)
    tableView.registerNib(cellNib, forCellReuseIdentifier: TableViewCellIdentifiers.searchResultCell)

    cellNib = UINib(nibName: TableViewCellIdentifiers.nothingFoundCell, bundle: nil)
    tableView.registerNib(cellNib, forCellReuseIdentifier: TableViewCellIdentifiers.nothingFoundCell)

    cellNib = UINib(nibName: TableViewCellIdentifiers.loadingCell, bundle: nil)
    tableView.registerNib(cellNib, forCellReuseIdentifier: TableViewCellIdentifiers.loadingCell)

    searchBar.becomeFirstResponder()
  }

  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    // Dispose of any resources that can be recreated.
  }

  @IBAction func segmentedChanged(sender: UISegmentedControl) {
    performSearch()
  }

  override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
    if segue.identifier == "ShowDetail" {
      let detailViewController = segue.destinationViewController as! DetailViewController
      let indexPath = sender as! NSIndexPath
      let searchResult = searchResults[indexPath.row]
      detailViewController.searchResult = searchResult
    }
  }

  override func willTransitionToTraitCollection(newCollection: UITraitCollection, withTransitionCoordinator coordinator: UIViewControllerTransitionCoordinator) {
    super.willTransitionToTraitCollection(newCollection, withTransitionCoordinator: coordinator)

    switch newCollection.verticalSizeClass {
    case .Compact:
      showLandscapeViewWithCoordinator(coordinator)
    case .Regular, .Unspecified:
      hideLandscapeViewWithCoordinator(coordinator)
    }
  }

  func showLandscapeViewWithCoordinator(coordinator: UIViewControllerTransitionCoordinator) {
    precondition(landscapeViewController == nil)

    landscapeViewController = storyboard!.instantiateViewControllerWithIdentifier("LandscapeViewController") as? LandscapeViewController

    if let controller = landscapeViewController {
      controller.searchResults = searchResults
      controller.view.frame = view.bounds
      controller.view.alpha = 0

      view.addSubview(controller.view)
      addChildViewController(controller)

      coordinator.animateAlongsideTransition({ _ in
        controller.view.alpha = 1
        self.searchBar.resignFirstResponder()
        if self.presentedViewController != nil {
          self.dismissViewControllerAnimated(true, completion: nil)
        }
      }, completion: { _ in
        controller.didMoveToParentViewController(self)
      })

    }
  }

  func hideLandscapeViewWithCoordinator(coordinator: UIViewControllerTransitionCoordinator) {
    if let controller = landscapeViewController {
      controller.willMoveToParentViewController(nil)

      coordinator.animateAlongsideTransition({ _ in controller.view.alpha = 0}, completion: { _ in
        controller.view.removeFromSuperview()
        controller.removeFromParentViewController()
        self.landscapeViewController = nil
      })
    }
  }

  func urlWithSearchText(searchText: String, category: Int) -> NSURL {
    let entityName: String
      switch category {
      case 1: entityName = "musicTrack"
      case 2: entityName = "software"
      case 3: entityName = "ebook"
      default: entityName = ""
    }
    let escapedText = searchText.stringByAddingPercentEncodingWithAllowedCharacters(NSCharacterSet.URLQueryAllowedCharacterSet())!
    let urlString = String(format: "https://itunes.apple.com/search?term=%@&limit=200&entity=%@", escapedText, entityName)
    let url = NSURL(string: urlString)
    return url!
  }

  func parseJSON(data: NSData) -> [String: AnyObject]? {
    do {
      return try NSJSONSerialization.JSONObjectWithData(data, options: []) as? [String: AnyObject]
    } catch {
      print("JSON Error: \(error)")
      return nil
    }
  }

  func showNetworkError() {
    let alert = UIAlertController(title: "Whoops...", message: "There was an error reading from the iTunes Store. Please try again", preferredStyle: .Alert)
    let action = UIAlertAction(title: "OK", style: .Default, handler: nil)
    alert.addAction(action)

    presentViewController(alert, animated: true, completion: nil)
  }

  func parseDictionary(dictionary: [String: AnyObject]) -> [SearchResult] {
    guard let array = dictionary["results"] as? [AnyObject] else {
      print("Expected 'results' array")
      return []
    }

    var searchResults = [SearchResult]()

    for resultDict in array {
      if let resultDict = resultDict as? [String: AnyObject] {

        var searchResult: SearchResult?

        if let wrapperType = resultDict["wrapperType"] as? String {
          switch wrapperType {
            case "track":
              searchResult = parseTrack(resultDict)
            case "audiobook":
              searchResult = parseAudioBook(resultDict)
            case "software":
              searchResult = parseSoftware(resultDict)
            default:
              break
          }
        } else if let kind = resultDict["kind"] as? String where kind == "ebook" {
          searchResult = parseEBook(resultDict)
        }

        if let searchResult = searchResult {
          searchResults.append(searchResult)
        }
      }
    }

    return searchResults
  }

  func parseTrack(dictionary: [String: AnyObject]) -> SearchResult {
    let searchResult = SearchResult()

    searchResult.name = dictionary["trackName"] as! String
    searchResult.artistName = dictionary["artistName"] as! String
    searchResult.artworkURL60 = dictionary["artworkUrl60"]  as! String
    searchResult.artworkURL100 = dictionary["artworkUrl100"] as! String
    searchResult.storeURL = dictionary["trackViewUrl"] as! String
    searchResult.kind = dictionary["kind"] as! String
    searchResult.currency = dictionary["currency"] as! String

    if let price = dictionary["trackPrice"] as? Double {
      searchResult.price = price
    }
    if let genre = dictionary["primaryGenreName"] as? String {
      searchResult.genre = genre
    }
    return searchResult
  }

  func parseAudioBook(dictionary: [String: AnyObject]) -> SearchResult {
    let searchResult = SearchResult()
    searchResult.name = dictionary["collectionName"] as! String
    searchResult.artistName = dictionary["artistName"] as! String
    searchResult.artworkURL60 = dictionary["artworkUrl60"] as! String
    searchResult.artworkURL100 = dictionary["artworkUrl100"] as! String
    searchResult.storeURL = dictionary["collectionViewUrl"] as! String
    searchResult.kind = "audiobook"
    searchResult.currency = dictionary["currency"] as! String

    if let price = dictionary["collectionPrice"] as? Double {
      searchResult.price = price
    }
    if let genre = dictionary["primaryGenreName"] as? String {
      searchResult.genre = genre
    }
    return searchResult
  }

  func parseSoftware(dictionary: [String: AnyObject]) -> SearchResult {
    let searchResult = SearchResult()
    searchResult.name = dictionary["trackName"] as! String
    searchResult.artistName = dictionary["artistName"] as! String
    searchResult.artworkURL60 = dictionary["artworkUrl60"] as! String
    searchResult.artworkURL100 = dictionary["artworkUrl100"] as! String
    searchResult.storeURL = dictionary["trackViewUrl"] as! String
    searchResult.kind = dictionary["kind"] as! String
    searchResult.currency = dictionary["currency"] as! String

    if let price = dictionary["price"] as? Double {
      searchResult.price = price
    }
    if let genre = dictionary["primaryGenreName"] as? String {
      searchResult.genre = genre
    }
    return searchResult
  }

  func parseEBook(dictionary: [String: AnyObject]) -> SearchResult {
    let searchResult = SearchResult()
    searchResult.name = dictionary["trackName"] as! String
    searchResult.artistName = dictionary["artistName"] as! String
    searchResult.artworkURL60 = dictionary["artworkUrl60"] as! String
    searchResult.artworkURL100 = dictionary["artworkUrl100"] as! String
    searchResult.storeURL = dictionary["trackViewUrl"] as! String
    searchResult.kind = dictionary["kind"] as! String
    searchResult.currency = dictionary["currency"] as! String

    if let price = dictionary["price"] as? Double {
      searchResult.price = price
    }
    if let genres: AnyObject = dictionary["genres"] {
      searchResult.genre = (genres as! [String]).joinWithSeparator(", ")
    }
    return searchResult
  }
}

extension SearchViewController: UISearchBarDelegate {
  func positionForBar(bar: UIBarPositioning) -> UIBarPosition {
    return .TopAttached
  }

  func searchBarSearchButtonClicked(searchBar: UISearchBar) {
    performSearch()
  }

  func performSearch() {
    if !searchBar.text!.isEmpty {
      searchBar.resignFirstResponder()

      dataTask?.cancel()

      isLoading = true
      tableView.reloadData()

      hasSearched = true
      searchResults = [SearchResult]()

      let url = urlWithSearchText(searchBar.text!, category: segmentedControl.selectedSegmentIndex)
      let session = NSURLSession.sharedSession()
      dataTask = session.dataTaskWithURL(url, completionHandler: {
        data, response, error in

        if let error = error where error.code == -999 {
          return  // Search was cancelled

        } else if let httpResponse = response as? NSHTTPURLResponse where httpResponse.statusCode == 200 {

          if let data = data, dictionary = self.parseJSON(data) {
            self.searchResults = self.parseDictionary(dictionary)
            self.searchResults.sortInPlace(<)

            dispatch_async(dispatch_get_main_queue()) {
              self.isLoading = false
              self.tableView.reloadData()
            }
            return
          }

        } else {
          print("Failure! \(response!)")
        }

        dispatch_async(dispatch_get_main_queue()) {
          self.hasSearched = false
          self.isLoading = false
          self.tableView.reloadData()
          self.showNetworkError()
        }
      })

      dataTask?.resume()
    }
  }
  
}

extension SearchViewController: UITableViewDataSource {
  func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    if isLoading {
      return 1
    } else if !hasSearched {
      return 0
    } else if searchResults.count == 0 {
      return 1
    } else {
      return searchResults.count
    }
  }

  func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
    if isLoading {
      let cell = tableView.dequeueReusableCellWithIdentifier(TableViewCellIdentifiers.loadingCell, forIndexPath: indexPath)
      let spinner = cell.viewWithTag(100) as! UIActivityIndicatorView
      spinner.startAnimating()
      return cell
    }
    if searchResults.count == 0 {
      return tableView.dequeueReusableCellWithIdentifier(TableViewCellIdentifiers.nothingFoundCell, forIndexPath: indexPath)
    } else {
      let cell = tableView.dequeueReusableCellWithIdentifier(TableViewCellIdentifiers.searchResultCell, forIndexPath: indexPath) as! SearchResultCell

      let searchResult = searchResults[indexPath.row]
      cell.configureForSearchResult(searchResult)
      return cell
    }
  }
}

extension SearchViewController: UITableViewDelegate {
  func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
    tableView.deselectRowAtIndexPath(indexPath, animated: true)
    performSegueWithIdentifier("ShowDetail", sender: indexPath)
  }

  func tableView(tableView: UITableView, willSelectRowAtIndexPath indexPath: NSIndexPath) -> NSIndexPath? {
    if searchResults.count == 0 || isLoading {
      return nil
    } else {
      return indexPath
    }
  }
}