/* Copyright (C) 2017 NexusMutual.io

  This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

  This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
    along with this program.  If not, see http://www.gnu.org/licenses/ */


pragma solidity ^0.4.8;
import "./zeppelin-solidity/contracts/token/BasicToken.sol";
import "./zeppelin-solidity/contracts/token/MintableToken.sol";
import "./memberRoles.sol";
// import "./MintableToken.sol";
// import "./BasicToken.sol";

contract governanceData{
    struct proposal{
        address owner;
        string shortDesc;
        string longDesc;
        uint date_add;
        uint date_upd;
        uint versionNum;
        uint roleStatus;
        uint propStatus;  
        uint category;
        uint finalVerdict;
    }

    struct proposalCategory{
        address categorizedBy;
        uint[] paramInt;
        bytes32[] paramBytes32;
        address[] paramAddress;
        uint8 verdictOptions;
    }
    struct proposalVersionData{
        uint versionNum;
        string shortDesc;
        string longDesc;
        uint date_add;
    }
    struct Status{
        uint statusId;
        uint date;
    }

    struct category{
        string categoryName;
        string functionName;
        address contractAt;
        uint8 paramInt;
        uint8 paramBytes32;
        uint8 paramAddress;
        uint8[] memberRoleSequence;
        uint[] memberRoleMajorityVote;
    }
     struct proposalVote {
        address voter;
        uint proposalId;
        uint verdictChoosen;
        uint dateSubmit;
        uint voterTokens;
    }

    function governanceData () 
    {
        owner = msg.sender;
        proposalVoteClosingTime = 60;
        pendingProposalStart=0;
        quorumPercentage=25;
        addStatusAndCategory();
    }

    struct proposalVoteAndTokenCount 
    {
        mapping(uint=>mapping(uint=>uint)) totalVoteCount; 
        mapping(uint=>uint) totalTokenCount; 
    }

    mapping(uint => proposalVoteAndTokenCount) allProposalVoteAndTokenCount;
    mapping(uint=>mapping(uint=>uint)) getProposalRoleVote;
    mapping(address=>mapping(uint=>uint)) getAddressRoleVote;   
    mapping(address=>uint8) public advisoryBoardMembers;


    mapping(uint=>proposalCategory) allProposalCategory;
    mapping(uint=>proposalVersionData[]) proposalVersions;
    mapping(uint=>Status[]) proposalStatus;

    uint public proposalVoteClosingTime;
    uint public quorumPercentage;
    uint public pendingProposalStart;
    uint public memberCounter;
    uint public totalVotes;
    address public owner;

    category[] public allCategory;
    string[] public status;
    proposal[] allProposal;
    proposalVote[] allVotes;
    
    address basicTokenAddress;
    BasicToken basicToken;
    address mintableTokenAddress;
    MintableToken mintableToken;
    address memberRolesAddress;
    memberRoles mRoles;

    function changeMemberRoleAddress(address _contractAddress)
    {
        memberRolesAddress = _contractAddress;
        mRoles = memberRoles(memberRolesAddress);
    }

    /// @dev Change basic token contract's address
    function changeBasicTokenAddress(address _contractAddress) public
    {
        basicTokenAddress = _contractAddress;
        basicToken=BasicToken(basicTokenAddress);
    }

    /// @dev Creating object for mintable contract to mint tokens.
    function changeMintableTokenAddress(address _contractAddress) public
    {
        mintableTokenAddress = _contractAddress;
        mintableToken = MintableToken(mintableTokenAddress);
    }

    /// @dev Fetch user balance when giving member address.
    function getBalanceOfMember(address _memberAddress) public constant returns (uint totalBalance)
    {
        mintableToken = MintableToken(mintableTokenAddress);
        totalBalance = mintableToken.balanceOf(_memberAddress);
    }

    /// @dev get total supply tokens available for voting.
    function getTotalSupply() public constant returns(uint totalSupplyTokens) 
    {
        mintableToken = MintableToken(mintableTokenAddress);
        totalSupplyTokens = mintableToken.totalSupply();
    }

    /// @dev Get the vote count(voting done by AB) for options of proposal when giving Proposal id and Option index.
    function getProposalVoteAndTokenCountByRoleId(uint _proposalId,uint _roleId,uint _optionIndex) constant returns(uint totalVotes,uint totalToken)
    {
        totalVotes = allProposalVoteAndTokenCount[_proposalId].totalVoteCount[_roleId][_optionIndex];
        totalToken = allProposalVoteAndTokenCount[_proposalId].totalTokenCount[_roleId];
    }


    /// @dev add status and category.
    function addStatusAndCategory () 
    {
        // addCategory();
        addStatus();
    }
    
    /// @dev Increases the count of NXM Members by 1 (called whenever a new Member is added).
    function incMemberCounter() internal
    {
        memberCounter++;
    }

    /// @dev Decreases the count of NXM Members by 1 (called when a member is removed i.e. NXM tokens of a member is 0).
    function decMemberCounter() internal
    {
        memberCounter--;
    }

    /// @dev Gets the Quorum Percentage.
    function getQuorumPerc() public constant returns(uint percentage) 
    {
        percentage = quorumPercentage;
    }

    /// @dev Changes the Quorum Percentage.
    function changeQuorumPercentage(uint _percentage) public  
    {
        quorumPercentage = _percentage;
    }

    /// @dev Changes the status of a given proposal to open it for voting. // wil get called when we submit the proposal on submit button
    function openProposalForVoting(uint _proposalId) public
    {
        require(allProposal[_proposalId].owner == msg.sender || allProposal[_proposalId].propStatus == 0);
        pushInProposalStatus(_proposalId,1);
        updateProposalStatus(_proposalId,1);
    }

    /// @dev Changes the time(in seconds) after which proposal voting is closed.
    function changeProposalVoteClosingTime(uint _closingTime) public
    {
        proposalVoteClosingTime = _closingTime;   
    }

    /// @dev Checks if voting time of a given proposal should be closed or not. 
    function checkProposalVoteClosing(uint _proposalId) constant returns(uint8 closeValue)
    {
        require((allProposal[_proposalId].date_upd + proposalVoteClosingTime <= now));
        closeValue=1;
    }

    /// @dev fetch the parameter details for the final verdict (Option having maximum votes)
    function getProposalFinalVerdictDetails(uint _proposalId) public constant returns(uint paramint, bytes32 parambytes32,address paramaddress)
    {
        uint category = allProposal[_proposalId].category;
        uint verdictChoosen = allProposal[_proposalId].finalVerdict;
        if(allProposalCategory[_proposalId].paramInt.length != 0)
        {
             paramint = allProposalCategory[_proposalId].paramInt[verdictChoosen];
        }

        if(allProposalCategory[_proposalId].paramBytes32.length != 0)
        {
            parambytes32 = allProposalCategory[_proposalId].paramBytes32[verdictChoosen];
        }

        if(allProposalCategory[_proposalId].paramAddress.length != 0)
        {
            paramaddress = allProposalCategory[_proposalId].paramAddress[verdictChoosen];
        }  
    }
    
    /// @dev Get final verdict of proposal after CloseproposalVote function.
    function getProposalFinalVerdict(uint _proposalId) constant returns(uint verdict) 
    {
        verdict = allProposal[_proposalId].finalVerdict;
    }  

    function closeProposalVote(uint _proposalId)
    {
        if(checkProposalVoteClosing(_proposalId)==1)
        {
            mRoles = memberRoles(memberRolesAddress);
            uint category = allProposal[_proposalId].category;
            uint max;
            uint totalVotes;
            uint verdictVal;
            uint majorityVote;
            uint8 verdictOptions = allProposalCategory[_proposalId].verdictOptions;
            uint index = allProposal[_proposalId].roleStatus;
            uint roleId = mRoles.getMemberRoleByAddress(msg.sender);

            max=0;  
            for(uint i = 0; i < verdictOptions; i++)
            {
                totalVotes = totalVotes + allProposalVoteAndTokenCount[_proposalId].totalVoteCount[roleId][i]; 
                if(allProposalVoteAndTokenCount[_proposalId].totalVoteCount[roleId][max] < allProposalVoteAndTokenCount[_proposalId].totalVoteCount[roleId][i])
                {  
                    max = i; 
                }
            }
            verdictVal = allProposalVoteAndTokenCount[_proposalId].totalVoteCount[roleId][max];
            majorityVote = allCategory[_proposalId].memberRoleMajorityVote[index];

            if(verdictVal*100/totalVotes>=majorityVote)
            {   
                index++;
                if(index < allCategory[_proposalId].memberRoleSequence.length)
                {
                    changeProposalStatus(_proposalId,allCategory[_proposalId].memberRoleSequence[index]);
                }
                else
                {
                    if(max > 0)
                    {
                        pushInProposalStatus(_proposalId,2);
                        updateProposalStatus(_proposalId,2);
                        allProposal[_proposalId].finalVerdict = max;
                        actionAfterProposalPass(_proposalId ,category); 
                    }
                    else
                    {   
                        pushInProposalStatus(_proposalId,3);
                        updateProposalStatus(_proposalId,3);
                        allProposal[_proposalId].finalVerdict = max;
                        changePendingProposalStart();
                    }
                }
            } 
            else
            {
                changeProposalStatus(_proposalId,4);
                allProposal[_proposalId].finalVerdict = max;
                changePendingProposalStart();
            } 
        }
    }

    /// @dev Change pending proposal start variable
    function changePendingProposalStart() public
    {
        uint pendingPS = pendingProposalStart;
        uint proposalLength = allProposal.length;
        for(uint j=pendingPS; j<proposalLength; j++)
        {
            if(allProposal[j].propStatus > 2)
                pendingPS += 1;
            else
                break;
        }
        if(j!=pendingPS)
        {
            pendingProposalStart = j;
        }
    }

    /// @dev Function to be called after Closed proposal voting and Proposal is accepted.
    function actionAfterProposalPass(uint256 _proposalId,uint _categoryId) public //NEWW
    {
        address contractAt = allCategory[_categoryId].contractAt; // then function name:
        contractAt.call(bytes4(sha3(allCategory[_categoryId].functionName)),_proposalId);
    }

    /// @dev Check if the member who wants to change in contracts, is owner.
    function isOwner(address _memberAddress) constant returns(uint checkOwner)
    {
        checkOwner=0;
        if(owner == _memberAddress)
            checkOwner=1;
    }

    /// @dev Change current owner
    function changeOwner(address _memberAddress) public
    {
        if(owner == msg.sender)
            owner = _memberAddress;
    }

    /// @dev Gets the total number of categories.
    function getCategoriesLength() constant returns (uint length){
        length = allCategory.length;
    }

    /// @dev Gets category details by category id.
    function getCategoryDetails(uint _categoryId) public constant returns (string categoryName,string functionName,address contractAt,uint8 paramInt,uint8 paramBytes32,uint8 paramAddress,uint8[] memberRoleSequence,uint[] memberRoleMajorityVote)
    {    
        categoryName = allCategory[_categoryId].categoryName;
        functionName = allCategory[_categoryId].functionName;
        contractAt = allCategory[_categoryId].contractAt;
        paramInt = allCategory[_categoryId].paramInt;
        paramBytes32 = allCategory[_categoryId].paramBytes32;
        paramAddress = allCategory[_categoryId].paramAddress;
        memberRoleSequence = allCategory[_categoryId].memberRoleSequence;
        memberRoleMajorityVote = allCategory[_categoryId].memberRoleMajorityVote;
    } 


    /// @dev Increases the number of votes by 1.
    function increaseTotalVotes() internal
    {
        totalVotes++;
    }

    function proposalVoting(uint _proposalId,uint _verdictChoosen) public // 
    {
        require(_verdictChoosen <= allProposalCategory[_proposalId].verdictOptions && getBalanceOfMember(msg.sender) != 0 && allProposal[_proposalId].propStatus == 1);
        mRoles = memberRoles(memberRolesAddress);
        uint index = allProposal[_proposalId].roleStatus;
        uint roleId = mRoles.getMemberRoleByAddress(msg.sender);
        require(roleId ==  allCategory[_proposalId].memberRoleSequence[index]);
        uint votelength = totalVotes;
        uint _voterTokens = getBalanceOfMember(msg.sender);
        allVotes.push(proposalVote(msg.sender,_proposalId,_verdictChoosen,now,_voterTokens));
        allProposalVoteAndTokenCount[_proposalId].totalVoteCount[roleId][_verdictChoosen] +=1;
        allProposalVoteAndTokenCount[_proposalId].totalTokenCount[roleId] +=_voterTokens;
        getAddressRoleVote[msg.sender][roleId] = votelength;
        getProposalRoleVote[_proposalId][roleId] = votelength;
    }
    
    /// @dev Provides Vote details of a given vote id. 
    function getVoteDetailByid(uint _voteid) public constant returns( address voter,uint proposalId,uint verdictChoosen,uint dateSubmit,uint voterTokens)
    {
        return(allVotes[_voteid].voter,allVotes[_voteid].proposalId,allVotes[_voteid].verdictChoosen,allVotes[_voteid].dateSubmit,allVotes[_voteid].voterTokens);
    }

    /// @dev Creates a new proposal 
    function addNewProposal(string _shortDesc,string _longDesc) public
    {
        allProposal.push(proposal(msg.sender,_shortDesc,_longDesc,now,now,0,0,0,0,0));
    }

    /// @dev Fetch details of proposal by giving proposal Id
    function getProposalDetailsById(uint _id) public constant returns (address owner,string shortDesc,string longDesc,uint date_add,uint date_upd,uint versionNum,uint propStatus)
    {
        return (allProposal[_id].owner,allProposal[_id].shortDesc,allProposal[_id].longDesc,allProposal[_id].date_add,allProposal[_id].date_upd,allProposal[_id].versionNum,allProposal[_id].propStatus);
    }
     
    function getProposalCategory(uint _proposalId) public constant returns(uint category) 
    {
        category = allProposal[_proposalId].category; 
    }
    
    /// @dev Edits a proposal and Only owner of a proposal can edit it.
    function editProposal(uint _id , string _shortDesc, string _longDesc) public
    {
        require(msg.sender == allProposal[_id].owner);
        {
            storeProposalVersion(_id);
            updateProposal(_id,_shortDesc,_longDesc);
            allProposal[_id].category = 0;
            allProposalCategory[_id].paramInt.push(0);
            allProposalCategory[_id].paramBytes32.push("");
            allProposalCategory[_id].paramAddress.push(0);
        }
    }

    /// @dev Stores the information of a given version number of a given proposal. Maintains the record of all the versions of a proposal.
    function storeProposalVersion(uint _id) internal 
    {
        proposalVersions[_id].push(proposalVersionData(allProposal[_id].versionNum,allProposal[_id].shortDesc,allProposal[_id].longDesc,allProposal[_id].date_add));            
    }

    /// @dev Edits the details of an existing proposal and creates new version.
    function updateProposal(uint _id,string _shortDesc,string _longDesc) internal
    {
        allProposal[_id].shortDesc = _shortDesc;
        allProposal[_id].longDesc = _longDesc;
        allProposal[_id].date_upd = now;
        allProposal[_id].versionNum += 1;
    }

    /// @dev Gets version details of a given proposal id.
    function getProposalDetailsByIdAndVersion(uint _id,uint _versionNum) public constant returns( uint versionNum,string shortDesc,string longDesc,uint date_add)
    {
        return (proposalVersions[_id][_versionNum].versionNum,proposalVersions[_id][_versionNum].shortDesc,proposalVersions[_id][_versionNum].longDesc,proposalVersions[_id][_versionNum].date_add);
    }

    /// @dev Changes the status of a given proposal.
    function changeProposalStatus(uint _id,uint _status) 
    {
        require(allProposal[_id].category != 0);
        pushInProposalStatus(_id,_status);
        updateProposalStatus(_id,_status);
    }

    /// @dev Adds status names in array - Not generic right now
    function addStatus() internal
    {   
        status.push("Draft for discussion, Voting is not yet started"); 
        status.push("Voting started"); 
        status.push("Proposal Decision - Accepted by Majority Voting"); 
        status.push("Proposal Decision - Rejected by Majority voting"); 
        status.push("Proposal Denied, Threshold not reached"); 
    }

    /// @dev Updates  status of an existing proposal.
    function updateProposalStatus(uint _id ,uint _status) internal
    {
        allProposal[_id].propStatus = _status;
        allProposal[_id].date_upd =now;
    }

    /// @dev Stores the status information of a given proposal.
    function pushInProposalStatus(uint _id , uint _status) internal
    {
        proposalStatus[_id].push(Status(_status,now));
    }

    /// @dev Adds a new category.
    function addNewCategory(string _categoryName,string _functionName,address _contractAt,uint8 _paramInt,uint8 _paramBytes32,uint8 _paramAddress,uint8[] _memberRoleSequence,uint[] _memberRoleMajorityVote) public
    {
        require(_memberRoleSequence.length == _memberRoleMajorityVote.length);
        allCategory.push(category(_categoryName,_functionName,_contractAt,_paramInt,_paramBytes32,_paramAddress,_memberRoleSequence,_memberRoleMajorityVote));
    }

    /// @dev Updates a category details
    function updateCategory(uint _categoryId,string _categoryName,uint8 _memberVoteRequired,uint8 _majorityVote,string _functionName,address _contractAt,uint8 _paramInt,uint8 _paramBytes32,uint8 _paramAddress) public
    {
        allCategory[_categoryId].categoryName = _categoryName;
        allCategory[_categoryId].functionName = _functionName;
        allCategory[_categoryId].contractAt = _contractAt;
        allCategory[_categoryId].paramInt = _paramInt;
        allCategory[_categoryId].paramBytes32 = _paramBytes32; 
        allCategory[_categoryId].paramAddress = _paramAddress;
    }
    
    /// @dev Updates a category MVR value (Will get called after action after proposal pass)
    // function updateCategoryMVR(uint _categoryId) 
    // {
    //     allCategory[_categoryId].memberVoteRequired = 1;
    // }

    /// @dev Get the category paramets given against a proposal after categorizing the proposal.
    function getProposalCategoryParams(uint _proposalId) constant returns(uint[] paramsInt,bytes32[] paramsBytes,address[] paramsAddress)
    {
        paramsInt = allProposalCategory[_proposalId].paramInt;
        paramsBytes = allProposalCategory[_proposalId].paramBytes32;
        paramsAddress = allProposalCategory[_proposalId].paramAddress;
    }

    /// @dev categorizing proposal to proceed further.
    function categorizeProposal(uint _id , uint _categoryId,uint[] _paramInt,bytes32[] _paramBytes32,address[] _paramAddress,uint8 _verdictOptions) public
    {
        require(advisoryBoardMembers[msg.sender]==1 && allProposal[_id].propStatus == 0);
        uint8 paramInt; uint8 paramBytes32; uint8 paramAddress;

        if(_paramInt.length != 0  )
        {
            allProposalCategory[_id].paramInt.push(0);
        }

        if(_paramBytes32.length != 0  )
        {
            allProposalCategory[_id].paramBytes32.push("");
        }

        if(_paramAddress.length != 0  )
        {
            allProposalCategory[_id].paramAddress.push(0x00);
        }
    
        (,,,paramInt,paramBytes32,paramAddress,,) = getCategoryDetails(_categoryId);

        if(paramInt*_verdictOptions == _paramInt.length && paramBytes32*_verdictOptions == _paramBytes32.length && paramAddress*_verdictOptions == _paramAddress.length)
        {
            allProposalCategory[_id].verdictOptions = _verdictOptions+1;
            allProposalCategory[_id].categorizedBy = msg.sender;
            allProposal[_id].category = _categoryId;
            for(uint i=0;i<_verdictOptions;i++)
            {
                if(_paramInt.length != 0  )
                {
                    allProposalCategory[_id].paramInt.push(_paramInt[i]);
                }
        
                if(_paramBytes32.length != 0  )
                {
                    allProposalCategory[_id].paramBytes32.push(_paramBytes32[i]);
                }
        
                if(_paramAddress.length != 0  )
                {
                    allProposalCategory[_id].paramAddress.push(_paramAddress[i]);
                }
            }
            
        } 
    }
}  

contract governance 
{
    address governanceDataAddress;
    governanceData gd1;

    function changeGovernanceDataAddress(address _contractAddress) public
    {
        governanceDataAddress = _contractAddress;
        gd1=governanceData(governanceDataAddress);
    }
    
    /// @dev function to get called after Proposal Pass
    function updateCategory_memberVote(uint256 _proposalId) 
    {
        gd1=governanceData(governanceDataAddress);
        uint _categoryId = gd1.getProposalCategory(_proposalId);
        uint paramint;
        bytes32 parambytes32;
        address paramaddress;
        (paramint,parambytes32,paramaddress) = gd1.getProposalFinalVerdictDetails(_proposalId);
        // add your functionality here;
        // gd1.updateCategoryMVR(_categoryId);
    }

    
}


