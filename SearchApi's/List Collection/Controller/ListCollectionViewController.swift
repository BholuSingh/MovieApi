//
//  ListCollectionViewController.swift
//  SearchApi's
//
//  Created by Rajan Singh on 11/01/26.
//

import UIKit

class ListCollectionViewController: UIViewController {

    // MARK: - Outlets

    @IBOutlet weak var listCollectionView: UICollectionView!

    // MARK: - Private

    private let viewModel = ListCollectionViewModel()

    private let activityIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.hidesWhenStopped = true
        indicator.translatesAutoresizingMaskIntoConstraints = false
        return indicator
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setUpCollectionView()
        setUpActivityIndicator()
        viewModel.delegate = self
        viewModel.loadInitialData()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        viewModel.cancelFetch()
    }

    // MARK: - Setup

    private func setUpCollectionView() {
        let nib = UINib(nibName: "ListCollectionCell", bundle: nil)
        listCollectionView.register(nib, forCellWithReuseIdentifier: "ListCollectionID")

        let layout = UICollectionViewFlowLayout()
        layout.estimatedItemSize       = .zero
        layout.minimumLineSpacing      = 10
        layout.minimumInteritemSpacing = 10
        listCollectionView.collectionViewLayout = layout
    }

    private func setUpActivityIndicator() {
        view.addSubview(activityIndicator)
        NSLayoutConstraint.activate([
            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    // MARK: - Error Presentation

    private func showError(_ error: NetworkError) {
        let alert = UIAlertController(
            title:          "Something went wrong",
            message:        error.errorDescription,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - ViewModel Delegate

extension ListCollectionViewController: ListCollectionViewModelDelegate {

    func viewModelDidStartLoading() {
        activityIndicator.startAnimating()
    }

    func viewModelDidReloadData() {
        activityIndicator.stopAnimating()
        listCollectionView.reloadData()
    }

    func viewModelDidLoadMore(at indexPaths: [IndexPath]) {
        listCollectionView.performBatchUpdates {
            listCollectionView.insertItems(at: indexPaths)
        }
    }

    func viewModelDidFail(with error: NetworkError) {
        activityIndicator.stopAnimating()
        showError(error)
    }
}

// MARK: - UICollectionViewDelegateFlowLayout

extension ListCollectionViewController: UICollectionViewDelegateFlowLayout {

    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(
            width:  (collectionView.frame.width / 3) - 20,
            height: collectionView.frame.height / 4
        )
    }
}

// MARK: - UICollectionViewDelegate

extension ListCollectionViewController: UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView,
                        didSelectItemAt indexPath: IndexPath) {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        guard let detailVC = storyboard.instantiateViewController(
            withIdentifier: "DetailsViewSBID"
        ) as? DetailsViewController else { return }

        let movie = viewModel.movies[indexPath.item]
        detailVC.movieTitle = movie.title
        detailVC.movieType  = movie.year
        navigationController?.pushViewController(detailVC, animated: true)
        collectionView.deselectItem(at: indexPath, animated: false)
    }

    /// Pagination: when the last visible cell is about to appear, request the
    /// next page so results are ready before the user actually reaches the end.
    func collectionView(_ collectionView: UICollectionView,
                        willDisplay cell: UICollectionViewCell,
                        forItemAt indexPath: IndexPath) {
        guard !viewModel.movies.isEmpty,
              indexPath.item == viewModel.movies.count - 1 else { return }
        viewModel.fetchNextPage()
    }
}

// MARK: - UICollectionViewDataSource

extension ListCollectionViewController: UICollectionViewDataSource {

    func numberOfSections(in collectionView: UICollectionView) -> Int { 1 }

    func collectionView(_ collectionView: UICollectionView,
                        numberOfItemsInSection section: Int) -> Int {
        viewModel.movies.count
    }

    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: "ListCollectionID",
            for: indexPath
        ) as? ListCollectionCell else {
            return UICollectionViewCell()
        }
        cell.configure(with: viewModel.movies[indexPath.item])
        return cell
    }
}
