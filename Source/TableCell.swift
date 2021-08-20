//
//  TableCell.swift
//  Stargazers
//
//  Created by Luca Severini on 14-Aug-2021.
//  lucaseverini@mac.com
//

import UIKit

class TableCell: UITableViewCell
{
    @IBOutlet var name: UILabel!
    @IBOutlet var avatar: UIImageView!

    override func prepareForReuse()
    {
        super.prepareForReuse()

        avatar.tintColor = nil
        avatar.image = UIImage(systemName: "person")!
    }
}
