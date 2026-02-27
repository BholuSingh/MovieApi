//
//  DetailsViewController.swift
//  SearchApi's
//
//  Created by Rajan Singh on 11/01/26.
//

import UIKit

class DetailsViewController: UIViewController {

    // MARK: - Outlets
    @IBOutlet weak var movieImageView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var typeLabel: UILabel!

    // MARK: - Data
    var movieTitle: String?
    var movieType: String?

    override func viewDidLoad() {
        super.viewDidLoad()
        titleLabel.text = movieTitle
        typeLabel.text = movieType
    }
}
