pragma solidity 0.8.7;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../Interfaces/IpriceB.sol";
import "../Interfaces/ILPToken.sol";
import "./DataToken.sol";
contract sol2{
    IERC20 public USDC=IERC20(0xe2899bddFD890e320e643044c6b95B9B0b84157A);
    DataToken public NFT=DataToken(0x1c91347f2A44538ce62453BEBd9Aa907C662b4bD);
    IpriceB public priceB=IpriceB(0x93f8dddd876c7dBE3323723500e83E202A7C96CC);

    uint public priceEth;
    uint public priceUsdc;
    uint public LiquidationFee=10;
    uint public  fees=3;
    uint256 private _nextId = 1;
    uint256 private _nextPoolId = 1;
    uint256 public liquidatedCollateralAmount;
    
    
    struct POSITIONS{
        uint256 _liquidity;
        uint256 _interestRate;
        uint256 _collateralFactor;
        uint256 _poolId;
        uint256 _k;
    }

    struct BORROWTRANSACTIONS{
        uint256 _interestRateBorrowedAt;
        uint256 _collateralFactorBorrowedAt;
        uint256 _totalBorrowed;
        address _borrower;
    }

    struct LIQUIDATEDTRANSACTIONS{
        uint256 _poolId;
        uint _amountLiquidatedFromPool;
    }

    struct NFTSTOPOOL{
        uint _tokenId;
    }


    POSITIONS [] public positions;
    BORROWTRANSACTIONS [] public borrowtransactions;
    NFTSTOPOOL [] public nftsToPool;
    LIQUIDATEDTRANSACTIONS [] public liquidatedTransactions;
    mapping (uint=>uint) public NftIdToAmount;
    mapping (uint=>NFTSTOPOOL[]) public poolToNftId;
    mapping (uint=>uint) public NftIdToPoolId;
    mapping(uint =>mapping(uint =>bool)) public collateralFactorToIntrestRate;
    mapping(uint =>mapping(uint =>uint)) public amountBorrowedAtAnArea;
    mapping (address=>uint256)public CollateralAmount;
    mapping (address=>uint256)public CollateralValue;
    mapping (address=>uint256)public borrowedValue;
    mapping (address=>uint256)public totalMCR;
    mapping(uint256 => mapping(uint256=>uint256)) public collateralFactor_IntrestRateTopoolIds;
    mapping(address=>BORROWTRANSACTIONS[]) public addressToBorrowTransaction;

    error NOLIQUIDITYATTHEPOINT();
    error CANT_BE_LIQUIDATED();
    error NOT_OWING_THE();
    error POSITION_DOES_NOT_EXIST();

    event liquidityAdded(uint amount, address from, uint256 collateralFactor, uint256 interestRate);
    event created(uint256 liquidity, uint256 collateralFactor, uint256 interestRate);
    event Borrowed(uint amount, address to, uint newLiquidity);
    event isLiquidationAllowed(address borrower,uint amountOwed, uint CollateralValue );
    event liquidated(address borrower, address liquidator, uint amountOwed, uint CollateralValue );
    event addressLiquidatable(address borrower);


    function addLiquidity(uint256 _amount, uint256 _collateralFactor, uint256 _interestRate) external{
        priceUsdc=priceB.priceUsdc();
        if(collateralFactorToIntrestRate[_collateralFactor][_interestRate]==false ){
            _create( _amount, _collateralFactor, _interestRate);
            collateralFactorToIntrestRate[_collateralFactor][_interestRate]=true;  
        }else{
            _getPairAndUpdate( _amount, _collateralFactor,  _interestRate);
        } 
    }

    function _create(uint256 _amount, uint256 _collateralFactor, uint256 _interestRate) internal{
        positions.push(POSITIONS({_liquidity:_amount, _interestRate:_interestRate, _collateralFactor:_collateralFactor, _poolId:_nextPoolId, _k:1 }));
        collateralFactor_IntrestRateTopoolIds[_collateralFactor][_interestRate]=_nextPoolId;
        NFTSTOPOOL []storage data=poolToNftId[_nextPoolId];
        data.push(NFTSTOPOOL({_tokenId:_nextId}));
        uint toTransfer=(_amount*1e20)/(priceUsdc);
        USDC.transferFrom(msg.sender, address(this), toTransfer);
        NFT.safeMint(msg.sender, _nextId,_amount, _collateralFactor,_interestRate, _nextPoolId);
        NftIdToAmount[_nextId]=_amount;
        NftIdToPoolId[_nextId]=_nextPoolId;
        _nextId++;
        _nextPoolId++; 
        emit created( _amount, _collateralFactor, _interestRate);        
    }

    function _getPairAndUpdate(uint256 _amount,uint256 _collateralFactor, uint256 _interestRate) internal{
        uint borrowed=amountBorrowedAtAnArea[_collateralFactor][_interestRate];
        for (uint i; i<positions.length;i++){
            POSITIONS storage data=positions[i];
            if (data._collateralFactor==_collateralFactor && data._interestRate==_interestRate){
                if(borrowed==0){
                    uint toTransfer=(_amount*1e20)/(priceUsdc);
                    USDC.transferFrom(msg.sender, address(this), toTransfer);
                    NFT.safeMint(msg.sender, _nextId, _amount, _collateralFactor,_interestRate, data._poolId);
                    NftIdToAmount[_nextId]=_amount;
                    NftIdToPoolId[_nextId]=data._poolId;
                    _nextId++;
                    data._liquidity+=_amount;
                   
                }else{
                uint utilizationRate=(borrowed*100)/data._liquidity;
                uint percentageIntrestGrowth=(utilizationRate*_interestRate)/100;
                //uint k=(data._k*percentageIntrestGrowth)/100;
                uint toTransfer=(_amount*1e20)/(priceUsdc);
                //data._k+=k;
                //uint liquidityprovided=_amount/k;
                //uint remainant=_amount-liquidityprovided;
                USDC.transferFrom(msg.sender, address(this), toTransfer);
                NFT.safeMint(msg.sender, _nextId, _amount, _collateralFactor,_interestRate, data._poolId);
                //NftIdToAmount[_nextId]=liquidityprovided;
                NftIdToPoolId[_nextId]=data._poolId;
                _nextId++; 
                data._liquidity+=_amount;
                /*NFTSTOPOOL []storage nfts=poolToNftId[data._poolId];
                uint toDistribute=remainant/nfts.length;
                for (uint j;j<nfts.length;j++){
                    uint lp=poolToNftId[data._poolId][j]._tokenId;
                    NftIdToAmount[lp]+=toDistribute;

                }*/

            
                }
            }
        } 
        emit liquidityAdded(_amount, msg.sender,_collateralFactor, _interestRate );     
    }




    function addCollateral()external payable{
         updatePrice();   
        address(this).balance+msg.value;  
        CollateralAmount[msg.sender]+=msg.value;
    }

    function withdrawCollateral(uint _amount)external payable{
        updatePrice();
        for (uint i; i<borrowtransactions.length;i++){
            BORROWTRANSACTIONS storage data=borrowtransactions[i];
            if (data._borrower==msg.sender){
                uint factor=(data._totalBorrowed*LiquidationFee)/100;
                uint check=CollateralValue[msg.sender]-(data._totalBorrowed+factor);
                require (_amount<CollateralValue[msg.sender], "amount greater than available collateral");
                require(_amount<=check, "cant withdraw collateral used to support borrow");
                address(this).balance-_amount;
                (bool sent, ) = payable(msg.sender).call{value: _amount}("");
                require(sent, "Failed to send Ether");
                CollateralAmount[msg.sender]-=_amount;
            }else{
                require (_amount<CollateralValue[msg.sender], "amount greater than available collateral");
                address(this).balance-_amount;
                (bool sent, ) = payable(msg.sender).call{value: _amount}("");
                require(sent, "Failed to send Ether");
                CollateralAmount[msg.sender]-=_amount;
            }

        }
    }

    function updatePrice() public{
        priceEth=priceB.priceEth();  
        priceUsdc=priceB.priceUsdc(); 
        CollateralValue[msg.sender]=(CollateralAmount[msg.sender]*priceEth)/1e20;  
    }

    function initBorrow (uint256 _amount, uint256 _collateralFactor, uint256 _interestRate) internal{
        updatePrice();   
        for (uint i; i<positions.length;i++){
            POSITIONS storage data=positions[i]; 
            if (data._collateralFactor==_collateralFactor && data._interestRate==_interestRate){
                uint liquidationFee=(CollateralValue[msg.sender]*LiquidationFee)/100;
                uint si=CollateralValue[msg.sender]-liquidationFee;
                uint mt=(si*data._collateralFactor)/100;
                uint interest=(_interestRate*_amount)/100;
                require(CollateralValue[msg.sender]>_amount, "amount more than collateral value");
                require(_amount<=mt, "amount greater than MCR for ur collateral");
                uint toTransfer=(_amount*1e20)/(priceUsdc);
                amountBorrowedAtAnArea[_collateralFactor][_interestRate]=_amount;
                USDC.transfer( msg.sender, toTransfer);
                borrowedValue[msg.sender]=_amount+interest;
                data._liquidity-=_amount;
                borrowtransactions.push(BORROWTRANSACTIONS({_interestRateBorrowedAt:_interestRate, _collateralFactorBorrowedAt:_collateralFactor, _totalBorrowed:_amount, _borrower:msg.sender}));
                BORROWTRANSACTIONS []storage trx=addressToBorrowTransaction[msg.sender];
                trx.push(BORROWTRANSACTIONS({_interestRateBorrowedAt:_interestRate, _collateralFactorBorrowedAt:_collateralFactor, _totalBorrowed:_amount, _borrower:msg.sender}));         
                emit Borrowed(_amount, msg.sender,data._liquidity);
            }
        }
    }


   /* function subBorrows (uint256 _amount, uint256 _collateralFactor, uint256 _interestRate) internal{
        updatePrice();   
        for (uint i; i<positions.length;i++){
            POSITIONS storage data=positions[i]; 
            if (data._collateralFactor==_collateralFactor && data._interestRate==_interestRate){
               BORROWTRANSACTIONS storage borrowData=borrowtransactions[i];
               if(borrowData._borrower==msg.sender){

                uint liquidationFee=(CollateralValue[msg.sender]*LiquidationFee)/100;
                uint mt=((CollateralValue[msg.sender]-liquidationFee)*data._collateralFactor)/100;
                uint predictedTotalBorrow=borrowedValue[msg.sender]+_amount;
                amountBorrowedAtAnArea[_collateralFactor][_interestRate]+=_amount;
                require(CollateralValue[msg.sender]>_amount, "amount more than collateral value");
                require(_amount<=mt, "amount greater than MCR for ur collateral"); 
                uint toTransfer=(_amount*1e20)/(priceUsdc);
                USDC.transfer( msg.sender, toTransfer);
                data._liquidity-=_amount;
                borrowedValue[msg.sender]+=_amount; 
                totalMCR[msg.sender]=_collateralFactor;
                borrowData._totalBorrowed+=_amount;
                emit Borrowed(_amount, msg.sender,data._poolId);    
               }
               else{
                borrowtransactions.push(BORROWTRANSACTIONS({_interestRateBorrowedAt:_interestRate, _collateralFactorBorrowedAt:_collateralFactor, _totalBorrowed:_amount, _borrower:msg.sender}));
                uint liquidationFee=(CollateralValue[msg.sender]*LiquidationFee)/100;
                uint mt=((CollateralValue[msg.sender]-liquidationFee)*data._collateralFactor)/100;
                require(_amount<=mt, "amount greater than MCR for ur collateral"); 
                for (uint j;j<borrowtransactions.length;j++){
                    BORROWTRANSACTIONS storage borrowData=borrowtransactions[i];
                    if 
                }
                uint predictedTotalBorrow=borrowedValue[msg.sender]+_amount;
                uint x=(borrowedValue[msg.sender]*100)/predictedTotalBorrow;
                uint y=(_amount*100)/predictedTotalBorrow;
                uint tmcr=x+y;
                amountBorrowedAtAnArea[_collateralFactor][_interestRate]+=_amount;
                require(CollateralValue[msg.sender]>_amount, "amount more than collateral value");

                require(_collateralFactor<=tmcr, "amount greater than total mcr");
                uint toTransfer=(_amount*1e20)/(priceUsdc);
                USDC.transfer( msg.sender, toTransfer);
                data._liquidity-=_amount;
                borrowedValue[msg.sender]+=_amount;
                totalMCR[msg.sender]=tmcr;
                emit Borrowed(_amount, msg.sender,data._liquidity);

               }

            }
        }
    }*/

    function subBorrows (uint256 _amount, uint256 _collateralFactor, uint256 _interestRate) internal{
        updatePrice();
        for (uint i; i<positions.length;i++){
            POSITIONS storage data=positions[i]; 
            if (data._collateralFactor==_collateralFactor && data._interestRate==_interestRate){

                for (uint j; j<borrowtransactions.length;j++){
                    BORROWTRANSACTIONS storage borrowData=borrowtransactions[j];
                    if (msg.sender==borrowData._borrower){
                        uint liquidationFee=(LiquidationFee*CollateralValue[msg.sender])/100;
                        uint newColValue=CollateralValue[msg.sender]-liquidationFee;
                        uint maxBorrow=(newColValue*data._collateralFactor)/100;
                        require (_amount<=maxBorrow);
                        uint toTransfer=(_amount*1e20)/(priceUsdc);
                        USDC.transfer( msg.sender, toTransfer);
                        data._liquidity-=_amount;
                        borrowedValue[msg.sender]+=_amount; 
                        totalMCR[msg.sender]=_collateralFactor;
                        borrowData._totalBorrowed+=_amount;
                        emit Borrowed(_amount, msg.sender,data._poolId);   

                    }else{
                        uint presumedTotaldebt=borrowedValue[msg.sender]+_amount;
                        uint yColFactor=(_amount*100)/presumedTotaldebt;
                        uint bColFactor=(yColFactor*_collateralFactor)/100;
                        uint TMCR;
                        borrowtransactions.push(BORROWTRANSACTIONS({_interestRateBorrowedAt:_interestRate, _collateralFactorBorrowedAt:_collateralFactor, _totalBorrowed:_amount, _borrower:msg.sender  }));
                    }

                }

            }else{
                revert POSITION_DOES_NOT_EXIST();
            }
        }


    }

    function borrow(uint _amount, uint256 _collateralFactor, uint256 _interestRate)external {
        updatePrice();         
        if(borrowedValue[msg.sender]==0){
            initBorrow( _amount, _collateralFactor, _interestRate);
        }else{
            subBorrows(_amount, _collateralFactor, _interestRate);
        }  
    }

    function repay(uint _amount)external {
        updatePrice();
        for (uint i; i<borrowtransactions.length;i++){
            BORROWTRANSACTIONS storage data=borrowtransactions[i];
            uint amountOwed=data._totalBorrowed;
            if(data._borrower==msg.sender&&amountOwed==_amount){ 
                uint poolOwed=collateralFactor_IntrestRateTopoolIds[data._collateralFactorBorrowedAt][data._interestRateBorrowedAt];    
                borrowtransactions[i]=borrowtransactions[borrowtransactions.length-1];
                borrowtransactions.pop();           
                for (uint j; j<positions.length;j++){
                    POSITIONS storage positiontrx=positions[j];
                    if(positiontrx._poolId==poolOwed){
                        positiontrx._liquidity+=_amount;
                        uint toTransfer=(_amount*1e20)/(priceUsdc);
                        USDC.transferFrom(msg.sender, address(this), toTransfer);
                        borrowedValue[msg.sender]-=_amount;
                    }
                }
            }
            if(data._borrower==msg.sender){ 
                uint poolOwed=collateralFactor_IntrestRateTopoolIds[data._collateralFactorBorrowedAt][data._interestRateBorrowedAt];             
                for (uint j; j<positions.length;j++){
                    POSITIONS storage positiontrx=positions[j];
                    if(positiontrx._poolId==poolOwed){
                        positiontrx._liquidity+=_amount;
                        uint toTransfer=(_amount*1e20)/(priceUsdc);
                        USDC.transferFrom(msg.sender, address(this), toTransfer);
                        borrowedValue[msg.sender]-=_amount;
                        data._totalBorrowed-=_amount;

                    }
                }
            } else{
                revert NOT_OWING_THE();
            }           
       
        }
    }



    function withdrawLiquidity(uint256 _id, uint _amount) external{
        updatePrice();
        require(NftIdToAmount[_id]>=_amount, "you dont have the amount you are trying to withdraw");
        if(NftIdToAmount[_id]==_amount){
            NFT.transferFrom(msg.sender, address(this), _id );
            NFT.burn(_id);
            NftIdToAmount[_nextId]=0;
            uint toTransfer=(_amount*1e20)/(priceUsdc);
            USDC.transfer( msg.sender, toTransfer);
        }else{
            for (uint i;i<positions.length;i++){
                POSITIONS storage data=positions[i]; 
                if (data._poolId==NftIdToPoolId[_id]){
                    NFT.transferFrom(msg.sender, address(this), _id );
                    NFT.burn(_id);
                    NftIdToAmount[_nextId]-=_amount;
                    uint toTransfer=(_amount*1e20)/(priceUsdc);
                    USDC.transfer( msg.sender, toTransfer);
                    NFT.safeMint(msg.sender, _nextId,NftIdToAmount[_nextId], data._collateralFactor,data._interestRate, data._poolId);
                    _nextId++;
                }
            }
        }

        
    }

    function chackIfLiquidationIsAllowed(address _borrower)external  returns (bool CAN_BE_LIQUIDATED){
        updatePrice();
        for (uint i; i<borrowtransactions.length; i++){
            BORROWTRANSACTIONS memory data=borrowtransactions[i];
            if (data._borrower==_borrower){
                uint liquidationThreshold=data._collateralFactorBorrowedAt+LiquidationFee;
                uint healtFactor=(CollateralValue[_borrower]*liquidationThreshold)/borrowedValue[_borrower]*100;
                uint amountOwed=data._totalBorrowed;
                emit isLiquidationAllowed(_borrower, amountOwed, CollateralValue[_borrower] );
            
                if(healtFactor<=1){
                    return true;
                }else{
                    return false;
                }
            }

        }
    }

    function liquidate(address _borrower)external{
        updatePrice();
        for (uint i; i<borrowtransactions.length; i++){
            BORROWTRANSACTIONS memory data=borrowtransactions[i];
            if (data._borrower==_borrower){
                uint liquidationThreshold=data._collateralFactorBorrowedAt+LiquidationFee;
                uint healtFactor=(CollateralValue[_borrower]*liquidationThreshold)/borrowedValue[_borrower]*100;
                uint amountOwed=data._totalBorrowed;
                if(healtFactor<=1){
                    uint poolId=collateralFactor_IntrestRateTopoolIds[data._collateralFactorBorrowedAt][data._interestRateBorrowedAt];
                    liquidatedTransactions.push(LIQUIDATEDTRANSACTIONS({ _poolId:poolId,  _amountLiquidatedFromPool:CollateralAmount[_borrower]}));
                    liquidatedCollateralAmount+=CollateralAmount[_borrower];
                    CollateralAmount[_borrower]=0;
                    amountOwed=0;
                    emit liquidated(_borrower, msg.sender, amountOwed, CollateralValue[_borrower] );
                }else{
                    revert CANT_BE_LIQUIDATED();
                }   
            }
        }
    }

    function getUserBorrowData(address _borrower)external view returns (BORROWTRANSACTIONS memory borrowersInfo){
        for (uint i; i<borrowtransactions.length; i++){
            BORROWTRANSACTIONS memory data=borrowtransactions[i];
            if (data._borrower==_borrower){
                return data;
            }
        }
    }


    function getAdressesLiquidatable()external  {
        for (uint i; i<borrowtransactions.length; i++){
            BORROWTRANSACTIONS memory data=borrowtransactions[i];
            uint liquidationThreshold=data._collateralFactorBorrowedAt+LiquidationFee;
            uint healtFactor=(CollateralValue[data._borrower]*liquidationThreshold)/borrowedValue[data._borrower]*100;
            if (healtFactor<=1){
                data._borrower;
                emit addressLiquidatable(data._borrower);   
            }
        }
    }


    function buyLiquidatedCollaterals(uint _minAmount, uint _baseAmount, address _recipient )external{
        /*uint discount=(3*_baseAmount)/100;
        uint amount=_baseAmount-discount;
        uint toTransfer=(amount*1e20)/(priceEth);
        require(amount>=_minAmount, "less than minAmount");
        address(this).balance-toTransfer;
        (bool sent, ) = payable(_recipient).call{value: toTransfer}("");
        require(sent, "Failed to send Ether");
        liquidatedCollateralAmount-=toTransfer;       uint256 _poolId;
        uint _amountLiquidatedFromPool;
        */
        for (uint i; i<liquidatedTransactions.length;i++){
            LIQUIDATEDTRANSACTIONS memory data=liquidatedTransactions[i];
            uint discount=(3*_baseAmount)/100;
            uint amount=_baseAmount-discount;
            uint remainant=0;
            //if (amount>)
        }
    }

    function totalLiquidaterdValue()external view returns (uint){
       return liquidatedCollateralAmount;
    }

    function hhhhhhh() external view returns (BORROWTRANSACTIONS memory  data){
    
    for (uint j; j<borrowtransactions.length;j++){
         
            
               BORROWTRANSACTIONS storage borrowData=borrowtransactions[j];
                
                    if(borrowData._borrower==msg.sender){
                       
    
                   
                  
                  
                    return borrowData;
            

       

            }
        }
    }

    







}