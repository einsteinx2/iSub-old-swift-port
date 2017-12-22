//
//  PlaylistViewController.swift
//  iSub Beta
//
//  Created by Andres Felipe Rodriguez Bolivar on 12/20/17.
//  Copyright © 2017 Ben Baron. All rights reserved.
//

import UIKit

class PlaylistViewController: UIViewController {

    private var viewModel: ItemViewModel {
        didSet {
            viewModel.loadModelsFromWeb()
        }
    }
    private let viewStyle: PresentationMode
    @IBOutlet private weak var collectionView: UICollectionView!
    @IBOutlet weak var contentView: UIView!
    @IBOutlet weak var botomConstraint: NSLayoutConstraint!
    @IBOutlet weak var leftConstraint: NSLayoutConstraint!
    @IBOutlet weak var rightContraint: NSLayoutConstraint!
    @IBOutlet weak var topConstraint: NSLayoutConstraint!
    
    init(with viewModel: ItemViewModel, mode: PresentationMode = .fullScreen) {
        let viewModel2 = RootServerItemViewModel(loader: RootPlaylistsLoader(), title: "Playlists")
        self.viewModel = viewModel2
        self.viewStyle = mode
        super.init(nibName: "PlaylistViewController", bundle: nil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if viewStyle == .modal { setupModal() }
        setupView()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if viewStyle == .modal {
            animateModal()
        }
    }
}

// MARK: - Private methods
private extension PlaylistViewController {
    
    func setupView() {
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.registerNibForCell(with: PlaylistCell.self)

        viewModel.loadModelsFromWeb { _, _  in
            self.collectionView.reloadData()
        }
    }
    
    func setupModal() {
        modalTransitionStyle = .crossDissolve
        modalPresentationStyle = .overFullScreen
        
        topConstraint.constant = 40
        botomConstraint.constant = -40
        leftConstraint.constant = 20
        rightContraint.constant = -20
        
        contentView.then {
            $0.layer.cornerRadius = 8
            $0.layer.masksToBounds = true
            $0.transform = CGAffineTransform(translationX: 0, y: view.frame.height)
        }

        navigationController?.navigationBar.isHidden = true
    
    }
    
    func animateModal() {
        UIView.animate(withDuration: 0.3) {
            self.contentView.transform = .identity
        }
    }
    
}

// MARK: - CollectionView datasource methods
extension PlaylistViewController: UICollectionViewDataSource {
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return viewModel.playlists.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell: PlaylistCell = collectionView.reuse(at: indexPath)
        
        let playlistName: String = viewModel.playlists[indexPath.row].name
        let playlistImage: String? = viewModel.playlists[indexPath.row].coverArtId
        
        cell.setup(playlistName: playlistName,
                   coverArtId: playlistImage,
                   serverId: viewModel.serverId)
        
        return cell
    }
    
}


// MARK: - CollectionView delegate methods
extension PlaylistViewController: UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        print(viewModel.playlists[indexPath.row].name)
        let playlist = self.viewModel.playlists[indexPath.row]
        if let viewController = itemViewController(forItem: playlist, isBrowsingCache: false) {
            self.navigationController?.pushViewController(viewController, animated: true)
        }
    }
    
    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: contentView.bounds.width, height: 50.0)
    }
    
    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return 1.0
    }
    
    func collectionView(_ collectionView: UICollectionView, layout
        collectionViewLayout: UICollectionViewLayout,
                        minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return 1.0
    }
}
