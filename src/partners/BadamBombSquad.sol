// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { ERC721PartnerSeaDrop } from "../ERC721PartnerSeaDrop.sol";

/*
                                                                                      .;odddool:.                                          
                                                                                    ,kOl,,,;;cxOo.                                        
                                                                                  .o0o.  ...   ,xOl.                                      
                                                                                  :Ok;    .;;,.. .;dkd:.                                   
                                                                                lKl.     .;;;;,..  .cdkxc.                                
                            .........                            .......        .d0,      .,;;;;;,'..  .c0d.                               
                  ..,:loddxxdddxxddxxdo:'.            ..,:codddxxxxddxxddoc,.   ;Ko      .,;;;;;;;;,.  .kO'                               
              .,codxxdol:,'..........',coxkd;    .';codxxdolc;,'''......',:oxkd;..kO.     .';;;;;;;;;.  'Ok.                               
          .:xkdl:,.......''',,,,,,,'...  'lOkddxxxdl:,'....''',,,,,,,,''.. .'lOko00'      .,;;;;;;;;.  ;Kd                                
          ;kk:. ...'',;;;;;;;;;;;;;;;;;,'.  'lc,'.....',,;;;;;;;;;;;;;;;;;;,'. .okl,        ....,;;;;.  :Kl                                
        'xOl.  ',;;;;;;;;;;;;;;;;;;;;;;;;;'.   ..',,;;;;;;;;;;;;;;;;;;;;;;;;;,.        ....''...';;;;.  cXc                                
      .oOd'   .,;;;;;;;;;;;;;;;;;;;;;;;;;;;.   .;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;,.     .',;;;;;;;;;;;;;.  cKl                                
    ,Ok;     .,;;;;;;;;;;;;;;;;;;;;;;;;;;;,.  .;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;.   .';;;;;;;;;;;;;;;;'  ;Ko                                
    .k0'      .,;;;;;;;;;;,'.......';;;;;;;,.  .;;;;;;;;;;;;;'.......,;;;;;;;;;.  .';;;;;;;;;;;;;;;;;,. '0k.                               
    .Ok.      .;;;;;;;;;;'. .      .';;;;;;;.  .;;;;;;;;;;,...       .,;;;;;;;,.  .;;;;;;;;;;;;;;;;;;;. .dK;                               
    .Ok.      .'..,;;;;;;'..c,      .;;;;;;,.  .;;;;;;;;;'. .,.      .,;;;;;;;'. .';;;;;;;;,''',;;;;;;,. ,0x.                              
    .Ok.         .,;;;;;;,.'d;     .';;;;;;'.  ..';;;;;;;'  'c.      .;;;;;;;,.  .,;;;;;;;'.   ';;;;;;;' .lKo.                             
    .Ok.         .;;;;;;;,.':.     .;;;;;;,.     .;;;;;;;'  .'      .,;;;;;;,.    ';;;;;;;'.   .;;;;;;;,. .cOx,                            
    '0k.         .;;;;;;;,.      .',;;;;;,.     .';;;;;;;'        .';;;;;;,'.     .';;;;;;;,'...,;;;;;;;,.  .xK:                           
    .x0c;'      .';;;;;;;;.    ..,;;;;;,'.      .,;;;;;;;.     ...,;;;;;,'.        .';;;;;;;;;'....',;;;;;'  lKc                           
    .cxXk.     .,;;;;;;;;'...',;;;;;,.. .;:.   .,;;;;;;;.   .',;;;;;;,'. ..         .';;;;;;;;;,'.....',;' .kK;                           
      .Ok.     .,;;;;;;;;;;;;;;;;,'.    ,xo.   .,;;;;;;;,'',;;;;;;,'..  .:l'          .',;;;;;;;;;,,...... .:xko,                         
      .kO.     .,;;;;;;;;;;;;;;;,'..     ..    .;;;;;;;;;;;;;,,''..                     ..,;;;;;;;;;;;,'..    'oOx,                       
      .x0'     .,;;;;;;;;;;;;;;;;,,,,,,'''...  .',;;;;;;;;;;;,'''''''''.....   .....       ..,;;;;;;;;;;;,'..   .oOx'                     
      .dK,     .,;;;;;;;;,..'',,;;;;;;;;;;;;,'.. ..,;;;;;;,'',,,,;;;;;;;;;;;,'...';;,'...     .',;;;;;;;;;;;,'.   .d0o.                   
        lK:     .';;;;;;;;,.    ....'',;;;;;;;;;,.. .';;;;;.    .....',;;;;;;;;;,...,;;;;;,'.     .',;;;;;;;;;;,'.   ;Ok,                  
        :Kl      ';;;;;;;;,.          ..,;;;;;;;;;'. .';;;;,.  ..      .,;;;;;;;;,...;;;;;;,.       ..,;;;;;;;;;;,.   'k0;                 
        ,Kd      .,;;;;;;;;. ..         ';;;;;;;;;;'. .,;;;;. .ckd,     .;;;;;;;;;,..';;;;;;,.        .';;;;;;;;;;;'.  .x0;                
        .Ok.     .,;;;;;;;;,..cc.      .,;;;;;;;;;;,. .';;;;,. .,x0,    ';;;;;;;;;;...;;;;;;;,.        .,;;;;;;;;;;;,.  .k0,               
        .x0'      ';;;;;;;;;' 'd;     .';;;;;;;;;;;;. .';;;;;,.  .o;   .,;;;;;;;;;;...;;;;;;;;;'...   ..,;;;;;;;;;;;;,.  ,0x.              
        .xX:      .,;;;;;;;;;'...  ..',;;;;;;;;;;;;;. .,;;;;;;,.  .  ..,;;;;;;;;;;,..,;;;;;;;;;;;;,,,,,;;;;;;;;;;;;;;;'.  lK:              
    .:okko.      .';;;;;;;;;;'.  .,;;;;;;;;;;;;;;;,. .;;;;;;;;'.. .',;;;;;;;;;;;,...;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;.  '0x.             
  ;xkdc'          .,;;;;;;;;;;,.....,;;;;;;;;;;;;,. .,;;;;;;;;;;'...,;;;;;;;;;;'. .,;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;'  .x0'             
  '0k'             .,;;;;;;;;;;;;;. .,;;;;;;;;;;;,. .,;;;;;;;;;;;;,. .';;;;;;;'.    .,;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;,. .dK,             
  .kO'         ...',;;;;;,,'''.......;;;;;;;;;;,....,;;;;;;;;;;,''.. .';;;;,'.       .,;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;'. .x0,             
  ,Ok.       .,;;;;;;;;;,.......'',;;;;;;;;;,...',;;;;;;;;;,'.....'',;;,'..          .';;;;;;;;;;;;;;;;;;;;;;;;;;;;;;,.  ,0x.             
    ;0x.       .,;;;;;;;;;;,,;;;;;;;;;;;;;,..   .,;;;;;;;;;,,',,;;;;,'..  .,,.          .',;;;;;;;;;;;;;;;;;;;;;;;;;;,.  .x0;              
    :0d.       .,;;;;;;;;;;;;;;;;;;;;,'..       .,;;;;;;;;;;;;,,'... ..:okO0x,           .',;;;;;;;;;;;;;;;;;;;;;;;'.  .d0:               
      lKl        .,;;;;;;;;;;;;;;,,'...           .,;;;;;;;,'...  .'coxxdc'.'dOd'           ..',;;;;;;;;;;;;;;;;;,'.   ;kO;                
      .o0c        .,;;;;;;;;,,'...       .;dl.     .,,,'...  .;lodxxo:'.      'okx:.            ..',,;;;;;;;,,'...  .:xOl.                 
      .d0:        .,;;,''...         .,lkkkKo.      .  .':oxxxlc;.             .:dkxc,.            .........   .':dkxc.                   
        .x0;        ...           ..:okxo,..lKl     .;ldxxdc'.                     .;oxxxol:,'...      ...',:codxxo:.                      
        .kO'                .,:odxxdc'     .l0dcldxxdl;.                              .';coddddddxxxddxxxddol:,.                          
          'Ok.         ..;ldxxdoc,.           ,cll:'.                                          ..........                                  
          ;0x.   .,codxxdl;..                                                                                                             
            ;kkddxxdo:,.                                                                                                                   
            .,;;..                                                                                                                        
*/

/*
 * @notice This contract uses ERC721PartnerSeaDrop,
 *         an ERC721A token contract that is compatible with SeaDrop.
 */
contract BadamBombSquad is ERC721PartnerSeaDrop {
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