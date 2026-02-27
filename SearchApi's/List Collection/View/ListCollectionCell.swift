//
//  ListCollectionCell.swift
//  SearchApi's
//
//  Created by Rajan Singh on 11/01/26.
//

import UIKit

class ListCollectionCell: UICollectionViewCell {

    // MARK: - Outlets

    @IBOutlet weak var title: UILabel!
    @IBOutlet weak var thumbnailImage: UIImageView!

    // MARK: - Lifecycle

    override func awakeFromNib() {
        super.awakeFromNib()
        thumbnailImage.contentMode   = .scaleAspectFill
        thumbnailImage.clipsToBounds = true
    }

    // MARK: - Configuration

    /// Populates the cell with a movie summary.
    /// Only poster and title are shown here — full details live in DetailsViewController.
    func configure(with movie: MovieSummary) {
        title.text = movie.title

        if let posterURL = movie.posterURL {
            thumbnailImage.setImage(
                from: posterURL,
                placeholder: UIImage(named: "placeholder")
            )
        } else {
            thumbnailImage.image = UIImage(named: "placeholder")
        }
    }

    // MARK: - Reuse

    /// Cancel the in-flight image load so a recycled cell doesn't
    /// show the wrong poster while the correct one is downloading.
    override func prepareForReuse() {
        super.prepareForReuse()
        thumbnailImage.cancelImageLoad()
        thumbnailImage.image = nil
        title.text = nil
    }
}
