const Governance = artifacts.require('Governance');
const catchRevert = require('../helpers/exceptions.js').catchRevert;
const increaseTime = require('../helpers/increaseTime.js').increaseTime;
const encode = require('../helpers/encoder.js').encode;
const getProposalIds = require('../helpers/reward.js').getProposalIds;
const getAddress = require('../helpers/getAddress.js').getAddress;
const initializeContracts = require('../helpers/getAddress.js')
  .initializeContracts;
const Pool = artifacts.require('Pool');
const Master = artifacts.require('Master');
const GBTStandardToken = artifacts.require('GBTStandardToken');
const ProposalCategory = artifacts.require('ProposalCategory');
const MemberRoles = artifacts.require('MemberRoles');
const TokenProxy = artifacts.require('TokenProxy');
const sampleAddress = 0x0000000000000000000000000000000000000001;
const nullAddress = 0x0000000000000000000000000000000000000000;

let gbt;
let sv;
let pl;
let gv;
let ms;
let mr;
let pc;
let dAppToken;
let propId;
let pid;
let ownerProposals;
let voterProposals;

const BigNumber = web3.BigNumber;
require('chai')
  .use(require('chai-bignumber')(BigNumber))
  .should();

const e18 = new BigNumber(1e18);

contract('Governance', ([owner, notOwner, voter, noStake]) => {
  it('Should fetch addresses from master', async function() {
    await initializeContracts();
    address = await getAddress('GV');
    gv = await Governance.at(address);
    address = await getAddress('MR');
    mr = await MemberRoles.at(address);
    address = await getAddress('GBT');
    gbt = await GBTStandardToken.at(address);
    address = await getAddress('PC');
    pc = await ProposalCategory.at(address);
    address = await getAddress('PL');
    pl = await Pool.at(address);
    tp = await TokenProxy.new(gbt.address,18);
    address = await getAddress('MS');
    ms = await Master.at(address);
    address = await ms.dAppLocker();
    dAppToken = await GBTStandardToken.at(address);
  });

  it('Should create an uncategorized proposal', async function() {
    await gv.setPunishVoters(true);
    pid = await gv.getProposalLength();
    await gbt.transfer(notOwner, e18.mul(10));
    await gv.createProposal('Add new member', 'Add new member', 'hash', 0);
    await gv.createProposal('Add new member', 'Add new member', 'hash', 0, {
      from: notOwner
    });
    await catchRevert(gv.createProposal('Add new member', 'Add new member', 'hash', 6, {
      from: noStake
    }));
    assert.equal(
      pid.toNumber() + 2,
      (await gv.getProposalLength()).toNumber(),
      'Proposal not created'
    );
  });

  it('Should not categorize if pool balance is less than category default incentive', async function() {
    var stake = Math.pow(10,18);
    var incentive = Math.pow(10,18);
    await pc.updateCategory(
      7,
      'Transfer Ether',
      1,
      50,
      25,
      [1,2],
      72000,
      'QmRUmxw4xmqTN6L2bSZEJfmRcU1yvVWoiMqehKtqCMAaTa',
      nullAddress,
      'PL',
      [stake, incentive]
    );
    await dAppToken.lock('GOV', e18.mul(10), 54685456133563456);
    await catchRevert(gv.categorizeProposal(pid, 7));
    await dAppToken.transfer(pl.address, e18.mul(20));
    await gbt.transfer(pl.address, e18.mul(20));
  });

  it('Should not allow to categorize if tokens are not locked', async function() {
    await catchRevert(gv.categorizeProposal(pid, 7, { from: notOwner }));
  });

  it('Should not allow unauthorized person to categorize proposal', async function() {
    await catchRevert(gv.categorizeProposal(pid, 7, { from: notOwner }));
    await dAppToken.lock('GOV', e18.mul(10), 54685456133563456, {
      from: notOwner
    });
  });

  it('Should categorize proposal', async function() {
    await gv.createProposal('Add new member', 'Add new member', 'hash', 12);
    await gv.categorizeProposal(pid, 1);
    assert.equal(await gv.canCloseProposal(pid), 0);
    let proposalData = await gv.proposal(pid);
    //check proposal category
    assert.equal(
      proposalData[1].toNumber(),
      1,
      'Not categorized'
    );
  });

  it('Should update proposal', async function() {
    let proposalData = await gv.proposal(pid);
    await gv.updateProposal(pid,"Addnewmember","AddnewmemberSD","AddnewmemberDescription");
    let proposalDataUpdated = await gv.proposal(pid);
    assert.isAbove(proposalDataUpdated[3].toNumber(),proposalData[3].toNumber(),"Proposal not updated");
    assert.equal(proposalDataUpdated[1].toNumber(),0,"Category not reset");
  });

  it('Should allow authorized people to categorize multiple times', async function() {
    await gv.categorizeProposal(pid, 2);
    let proposalData = await gv.proposal(pid);
    assert.equal(
      proposalData[1].toNumber(),
      2,
      'Not categorized'
    );
    await mr.updateRole(notOwner, 1, true);
    await gv.categorizeProposal(pid, 7);
    proposalData = await gv.proposal(pid);
    assert.equal(
      proposalData[1].toNumber(),
      7,
      'Not categorized'
    );
    await mr.updateRole(notOwner, 1, false);
  });

  it('Should not allow unauthorized people to open proposal for voting and submit solutions', async () => {
    let proposalData = await gv.proposalDetails(pid);
    await catchRevert(
      gv.submitProposalWithSolution(pid, '0x0', '0x0', { from: noStake })
    );
    await catchRevert(
      gv.submitProposalWithSolution(pid, '0x0', '0x0', { from: notOwner })
    );
    const finalSol = await gv.proposalDetails(pid);
    assert.equal(proposalData[1].toNumber(), finalSol[1].toNumber());
  });

  it('Should allow anyone to submit solution', async () => {
    await gv.addSolution(pid, '0x0', '0x0', { from: notOwner });
    await catchRevert(gv.addSolution(pid, '0x0', '0x0', { from: noStake }));
  });

  it('Should not allow to categorize if there are solutions', async () => {
    await catchRevert(gv.categorizeProposal(pid, 7));
  });

  it('Should not allow voting before proposal is open for voting', async () => {
    await catchRevert(gv.submitVote(pid, [1]));
  });

  it('Should allow authorized people to submit solution', async () => {
    const initSol = await gv.proposalDetails(pid);
    await gv.submitProposalWithSolution(pid, '0x0', '0x0');
    assert.equal(await gv.canCloseProposal(pid), 0);
    const finalSol = await gv.proposalDetails(pid);
    assert.equal(finalSol[1].toNumber(), initSol[1].toNumber() + 1);
  });

  it('Should not allow to update proposal when there are solutions', async () =>{
    await catchRevert(gv.updateProposal(pid,"","",""));
  });

  it('Should not allow voting for non existent solution', async () => {
    await catchRevert(gv.submitVote(pid, [5]));
  });

  it('Should not allow unauthorized people to vote', async () => {
    await catchRevert(gv.submitVote(pid, [1], { from: notOwner }));
  });

  it('Should allow voting', async () => {
    await gv.submitVote(pid, [2]);
  });

  it('Should not close a paused proposal', async() =>{
    await catchRevert(gv.resumeProposal(pid));
    await gv.pauseProposal(pid);
    await catchRevert(gv.closeProposal(pid));
    await gv.resumeProposal(pid);
  });

  it('Should close proposal when voting is completed', async () => {
    await catchRevert(pl.claimReward(owner, [1]));
    await gv.closeProposal(pid);
    await catchRevert(gv.closeProposal(pid));
  });

  it('Should claim reward after proposal passed', async () => {
    voterProposals = await getProposalIds(owner, gv);
    const balance = await dAppToken.balanceOf(owner);
    await pl.claimReward(owner, voterProposals);
    assert.isAbove(
      (await dAppToken.balanceOf(owner)).toNumber(),
      balance.toNumber()
    );
    await catchRevert(pl.claimReward(owner, voterProposals));
  });

  it('Should check reward distribution when punish voters is true', async () => {
    await mr.updateRole(notOwner, 1, true);
    await mr.updateRole(voter, 1, true);
    await gv.createProposal('Add new member', 'Add new member', 'hash', 0);
    await gbt.transfer(voter, e18.mul(10));
    propId = (await gv.getProposalLength()).toNumber() - 1;
    await gv.categorizeProposal(propId, 7);
    await gv.submitProposalWithSolution(propId, '0x0', '0xf213d00c0000000000000000000000000000000000000000000000000000000000000001');
    await gv.addSolution(propId, '0x0', '0xf213d00c0000000000000000000000000000000000000000000000000000000000000001', { from:notOwner });
    await gv.submitVote(propId, [1]);
    await gv.submitVote(propId, [1], { from: notOwner });
    await catchRevert(gv.submitVote(propId, [2], { from: voter }));
    await dAppToken.lock('GOV', e18.mul(10), 54685456133563456, {
      from: voter
    });
    await gv.submitVote(propId, [2], { from: voter });
    await gv.closeProposal(propId);
    await gv.getSolutionAction(propId, 1);
    await gv.getPendingReward(owner, 0);
    voterProposals = await getProposalIds(owner, gv);
    var balance = await dAppToken.balanceOf(owner);
    await pl.claimReward(owner, voterProposals);
    assert.isAbove((await dAppToken.balanceOf(owner)).toNumber(), balance.toNumber());
    voterProposals = await getProposalIds(voter, gv);
    balance = await dAppToken.balanceOf(voter);
    await pl.claimReward(voter, voterProposals , { from:voter });
    assert.equal((await dAppToken.balanceOf(voter)).toNumber(), balance.toNumber());
  });

  it('Should give reward to all voters when punish voters is false', async () => {
    await gv.setPunishVoters(false);
    await gv.createProposal('Add new member', 'Add new member', 'hash', 0);
    propId = (await gv.getProposalLength()).toNumber() - 1;
    await gv.categorizeProposal(propId, 7);
    await gv.submitProposalWithSolution(propId, '0x0', '0xf213d00c0000000000000000000000000000000000000000000000000000000000000001');
    await gv.addSolution(propId, '0x0', '0xf213d00c0000000000000000000000000000000000000000000000000000000000000001', { from:notOwner });
    await gv.submitVote(propId, [1]);
    await gv.submitVote(propId, [1], { from: notOwner });
    await gv.submitVote(propId, [2], { from: voter });
    await gv.closeProposal(propId);
    await mr.updateRole(voter, 1, false);
    await mr.updateRole(notOwner, 1, false);
    voterProposals = await getProposalIds(owner, gv);
    var balance = (await dAppToken.balanceOf(owner)).toNumber();
    await pl.claimReward(owner, voterProposals);
    assert.isAbove((await dAppToken.balanceOf(owner)).toNumber(), balance);
    voterProposals = await getProposalIds(voter, gv);
    balance = (await dAppToken.balanceOf(voter)).toNumber();
    await pl.claimReward(voter, voterProposals , { from:voter });
    assert.isAbove((await dAppToken.balanceOf(owner)).toNumber(), balance);
  });

  it('Should not give reward if proposal is rejected', async () => {
    await gv.createProposal('Add new member', 'Add new member', 'hash', 0);
    propId = (await gv.getProposalLength()).toNumber() - 1;
    await gv.categorizeProposal(propId, 7);
    await gv.submitProposalWithSolution(propId, '0x0', '0xf213d00c0000000000000000000000000000000000000000000000000000000000000001');
    await gv.submitVote(propId, [0]);
    await gv.closeProposal(propId);
    voterProposals = await getProposalIds(owner, gv);
    // await dAppToken.transfer(pl.address, e18.mul(10));
    var balance = (await dAppToken.balanceOf(owner)).toNumber();
    // console.log(await gv.claimVoteReward(owner,voterProposals));
    await pl.claimReward(owner, voterProposals);
    assert.equal((await dAppToken.balanceOf(owner)).toNumber(), balance);
    let statusOfProposals = await gv.getStatusOfProposals();
  });

  it('Should check voting process when anyone is allowed to vote', async () => {
    let c1 = await pc.totalCategories();
    await pc.addCategory(
      'New Category',
      2,
      20,
      0,
      [1,2],
      1000,
      'New Sub Category',
      0x0000000000000000000000000000000000000001,
      '0x4164',
      [0, 100000]
    );
    let c2 = await pc.totalCategories();
    assert.equal(c2.toNumber(), c1.toNumber() + 1, 'category not added');
    await gv.createProposal(
      'Add new member',
      'Add new member',
      'Addnewmember',
      1
    );
    let proposalId = await gv.getProposalLength();
    await gv.submitProposalWithSolution(proposalId.toNumber()-1, '0x0', '0x0');
    await gv.submitVote(proposalId.toNumber()-1, [1])
    await gv.closeProposal(proposalId.toNumber()-1);
    let proposalData = await gv.proposal(proposalId.toNumber() - 1);
    assert.equal(proposalData[2].toNumber(),3);
  });

  it('should add new category with token holder as voters', async () => {
    let c1 = await pc.totalCategories();
    await pc.addCategory(
      'New Category',
      2,
      20,
      0,
      [1,2],
      1000,
      'New Sub Category',
      0x0000000000000000000000000000000000000001,
      '0x4164',
      [0, 100000]
    );
    let c2 = await pc.totalCategories();
    assert.equal(c2.toNumber(), c1.toNumber() + 1, 'category not added');
  });

  it('Proposal should be denied if threshold is not reached', async function(){
    await gv.createProposal(
      'Add new member',
      'Add new member',
      'Addnewmember',
      1
    );
    let proposalId = await gv.getProposalLength();
    await gv.submitProposalWithSolution(proposalId.toNumber()-1, '0x0', '0x0');
    await increaseTime(72000);
    await gv.closeProposal(proposalId.toNumber()-1);
  });

  it('Should create proposal with solution for token holders', async function() {
    let c = await pc.totalCategories();
    propId = (await gv.getProposalLength()).toNumber();
    await gv.createProposalwithSolution(
      'Add new member',
      'Add new member',
      'Addnewmember',
      c.toNumber() - 1,
      'Add new member',
      '0x5465'
    );
    await catchRevert(gv.createProposalwithSolution(
      'Add new member',
      'Add new member',
      'Addnewmember',
      11,
      'Add new member',
      '0x5465', { from: noStake}
    ));
    let statusOfProposals = await gv.getStatusOfProposals();
    assert.equal(propId+1, (await gv.getProposalLength()).toNumber());
  });

  it('Should not allow non token holders to vote', async function() {
    await catchRevert(gv.submitVote(propId, [0], { from: noStake }));
  });

  it('Should allow token holders to vote', async function() {
    await gv.submitVote(propId, [1], { from: voter });
    await catchRevert(gv.submitVote(propId, [0], { from: voter }));
  });

  it('Should not close proposal when time is not reached', async function() {
    await catchRevert(gv.closeProposal(propId));
  });

  it('Should allow more token holders to vote', async function() {
    dAppToken.transfer(notOwner,e18.mul(1));
    await gv.submitVote(propId, [0] , { from: notOwner });
    await catchRevert(gv.submitVote(propId, [1]));
  });

  it('Should close proposal when time is reached', async function() {
    await increaseTime(2000);
    await gv.closeProposal(propId);
    await catchRevert(gv.closeProposal(propId));
  });

  it('Should configure global paramters', async function() {
    await catchRevert(gv.configureGlobalParameters("0x5448", 10 ,{from:noStake}));
    await gv.configureGlobalParameters("0x5448", 704400);
    await gv.configureGlobalParameters("0x4d56", 10);
  });
  
});