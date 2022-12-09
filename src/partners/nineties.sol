// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { ERC721PartnerSeaDrop } from "../ERC721PartnerSeaDrop.sol";

/*
      .----.                                                                         
    .   _   \                                                  _______               
   /  .' )   |            ,.--.                      .     .--.\  ___ `'.            
  |   (_.    /           //    \                   .'|     |__| ' |--.\  \           
   \     ,  / .-''` ''-. \\    |                 .'  |     .--. | |    \  '          
    `'-'/  /.'          '.`'-)/                 <    |     |  | | |     |  '         
.-.    /  //              ` /'    _              |   | ____|  | | |     |  |    _    
\  '--'  /'                '    .' |             |   | \ .'|  | | |     ' .'  .' |   
 '-....-' |         .-.    |   .   | /           |   |/  . |  | | |___.' /'  .   | / 
          .        |   |   . .'.'| |//           |    /\  \|__|/_______.'/ .'.'| |// 
           .       '._.'  /.'.'.-'  /            |   |  \  \   \_______|/.'.'.-'  /  
            '._         .' .'   \_.'             '    \  \  \            .'   \_.'   
               '-....-'`                        '------'  '---'                      
⠀⠀⢀⣀⣀⣀⣀⣀⣀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⢀⡾⠋⠁⠀⠀⠀⠀⠀⠉⠉⠓⠒⠶⠤⣤⣀⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⢸⣧⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⠉⠉⣙⠒⠲⠦⠤⢤⣤⣄⣀⣀⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠻⣗⠦⣄⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠙⠻⠥⢀⣈⣑⣒⣂⠀⠉⠙⠛⠿⠿⢷⣶⠶⠖⠲⠶⠶⠤⠤⠤⢤⣄⡀
⠀⠀⠈⠛⠦⠬⣙⣒⠶⠤⢤⣀⣀⠀⠀⠀⠀⣀⣀⣀⠀⠀⠀⠰⢶⡤⠉⣑⣒⠒⠒⠒⠤⠤⢄⡀⠀⠀⠀⠀⠀⠀⠀⣨⣿⠀
⠀⠀⠀⠀⠀⠀⣠⣼⣿⣿⣟⣒⣶⣽⢷⣖⣲⣼⠿⣶⣼⣷⣒⡒⢤⣌⣓⣤⣤⣴⣿⣭⡐⠒⠒⠉⠉⠁⠀⠀⠀⢀⣤⣾⡽⠋
⠀⠀⠀⠀⠀⢰⡏⢱⠗⡌⢫⢻⡁⠉⠓⠛⠋⠉⠉⠉⠑⠚⠻⠿⠭⣍⣙⣛⠓⠲⠦⠤⠤⠤⠤⠤⢤⡶⣖⣶⣿⣿⠟⠉⠀⠀
⠀⠀⠀⠀⠀⠘⣧⡈⠏⠁⣼⠏⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⠉⠙⢛⣿⣿⢶⣾⡛⠛⣛⢿⣿⣀⣴⠟⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠉⠉⠉⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⡟⢹⡤⡄⠙⣿⡟⠁⠀⠈⠁⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢷⣄⢻⠃⣠⡿⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠉⠉⠉⠉⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
 */

/**
 * @notice This contract uses ERC721PartnerSeaDrop,
 *         an ERC721A token contract that is compatible with SeaDrop.
 */
contract nineties is ERC721PartnerSeaDrop {
    /**
     * @notice Deploy the token contract with its name, symbol,
     *         administrator, and allowed SeaDrop addresses.
     */
    constructor(
        string memory name,
        string memory symbol,
        address administrator,
        address[] memory allowedSeaDrop
    ) ERC721PartnerSeaDrop(name, symbol, administrator, allowedSeaDrop) {}
}
