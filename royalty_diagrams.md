    For now, implement "Option 2", though we'll probably go with Option 3 or its inverse.                                                                                                                                                                   
                                                                                                                                                                       
        "Option 1"                                                                           "Option 2"                                                                
    OpenSea Disburses                                                                          Instant                                                                 
           Fees                                                                                Payouts     ┌───────┐  ┌───────┐                                        
                             ┌──────────────────────────────────────────────┐                              │OpenSea│  │Partner│                                        
                             │NFT Contract                                  │                              │Wallet │  │Wallet │                                        
                             │                                              │                              └───────┘  └───────┘                                        
                     O       │                             ┌──────────────┐ │                                  ▲          ▲                                            
                    /|\      │         ┌───────┐           │ Contract ETH │ │                                  │          │                                            
                 ┌─▶/ \ ─────ETH──────▶│mint() │──Update──▶│   Balance    │ │                              Gas fee    Gas fee                                          
                 │  User     │         └───────┘           │(Sales + Fees)│ │                                  │          │                                            
                 │           │             │               └──────────────┘ │                                  │          │                                            
                 │           │             │                       ▲        │                                  └─────┬────┘                                            
    O            └──NFT──────┼─────────────┘                       │        │                          ┌─────────────┼────────────┐                                    
   /|\                       │                                     │        │                          │NFT Contract │            │                                    
   / \                       │        ┌───────────┐                │        │                          │             │            │                                    
   OpenSea ───(At any point)─┼───────▶│withdraw() │────Set to 0────┘        │                  O       │            ETH           │                                    
                             │        └─────┬─────┘                         │                 /|\      │         ┌───┴───┐        │                                    
                             └──────────────┼───────────────────────────────┘              ┌─▶/ \ ─────┼ETH─────▶│mint() │        │                                    
                                            │                                              │  User     │         └───────┘        │                                    
                                           ETH                                             │           │             │            │                                    
                                            │                                              │           │             │            │                                    
                                       (Withdrawer                                         └──NFT──────┼─────────────┘            │                                    
                                     pays small gas                                                    │                          │                                    
                                          fee)                                                         └──────────────────────────┘                                    
                                            │                                                                                                                          
                                            ▼                                                                                                                          
                                        ┌───────┐                  ┌───────┐                                                                                           
                                        │OpenSea│  Transfer ETH    │Partner│                                                                                           
                                        │Wallet │──(Sale revenue──▶│Wallet │                                                                                           
                                        └───────┘   minus fees)    └───────┘                 "Option 4"                                                                
                                                                                             Withdrawal                                                                
                                                                                               splits                                                                  
                                    ┌───────┐                                                                                                                          
                "Option 3"          │Partner│                                                                                                                          
             Instant Partner        │Wallet │                                                                     ┌───────────────────────────────────────────────────┐
                 Payouts            └───────┘                                                                     │NFT Contract                    ┌───────────┐      │
               (OpenSea fee             ▲                                                                         │                                │ Contract  │      │
               withdrawal)              │                                                                 O       │                        ┌──────▶│ETH Balance│◀─┐   │
                                     Gas fee                                                             /|\      │         ┌───────┐      │       └───────────┘  │   │
                                        │                                                             ┌─▶/ \ ─────ETH──────▶│mint() │──Update      ┌──────────┐   │   │
                          ┌─────────────┼────────────────────────────────┐                            │  User     │         └───────┘      │       │ OpenSea  │   │   │
                          │NFT Contract │                                │                            │           │             │          └──────▶│Fee Amount│   │   │
                          │             │                                │                            │           │             │                  └──────────┘   │   │
                  O       │            ETH              ┌──────────────┐ │             O              └──NFT──────┼─────────────┘                        ▲        │   │
                 /|\      │         ┌───┴───┐           │ Contract ETH │ │            /|\                         │                                      │        │   │
              ┌─▶/ \ ─────ETH──────▶│mint() │──Update──▶│   Balance    │ │            / \                         │        ┌───────────┐                 │        │   │
              │  User     │         └───────┘           │(Fee balance) │ │            OpenSea ─────(At any point)─┼───────▶│withdraw() │─────────────────┴Set to 0┘   │
              │           │             │               └──────────────┘ │            or                          │        └─────┬─────┘                              │
              │           │             │                       ▲        │            Partner                     └──────────────┼────────────────────────────────────┘
 O            └──NFT──────┼─────────────┘                       │        │                                                       │                                     
/|\                       │                                     │        │                                                      ETH                                    
/ \                       │        ┌───────────┐                │        │                                                       │                                     
OpenSea ───(At any point)─┼───────▶│withdraw() │────Set to 0────┘        │                                                       │                                     
                          │        └─────┬─────┘                         │                                              ┌────────┴───────┐                             
                          └──────────────┼───────────────────────────────┘                                              │                │                             
                                         │                                                                              │   (Withdrawer  │                             
                                        ETH                                                                             │ pays small gas │                             
                                         │                                                                              │      fee)      │                             
                                    (Withdrawer                                                                         │                │                             
                                  pays small gas                                                                        │                │                             
                                       fee)                                                                             ▼                ▼                             
                                         │                                                                          ┌───────┐        ┌───────┐                         
                                         ▼                                                                          │OpenSea│        │Partner│                         
                                     ┌───────┐                                                                      │Wallet │        │Wallet │                         
                                     │OpenSea│                                                                      └───────┘        └───────┘                         
                                     │Wallet │                                                                                                                         
                                     └───────┘                                                                                                                         