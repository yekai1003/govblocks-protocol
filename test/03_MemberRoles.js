const MemberRoles = artifacts.require("MemberRoles");
const catchRevert = require("../helpers/exceptions.js").catchRevert;
const encode = require("../helpers/encoder.js").encode;

let mr;
// add newMemberRole tested already

contract('MemberRoles', function([owner,member,nonmember]) {
  before(function(){
    MemberRoles.deployed().then(function(instance){
      mr = instance;
    });
  });

  it("should be initialized with default roles", async function () {
    this.timeout(100000);
    let ab = await mr.getMemberRoleNameById.call(1);
    let th = await mr.getMemberRoleNameById(2);

    assert.equal(ab[1], "0x41647669736f727920426f617264000000000000000000000000000000000000", "Advisory Board not created");
    assert.equal(th[1], "0x546f6b656e20486f6c6465720000000000000000000000000000000000000000", "Token Holder not created");
    let roles = await mr.getRoleIdByAddress(owner);
    
    assert.equal(await mr.checkRoleIdByAddress(owner,1), true, "Owner not added to AB");
    assert.equal(roles[0].toNumber(), 1, "Owner not added to AB");
  });

  it("should add a member to a role", async function () {
    this.timeout(100000);
    await mr.updateMemberRole(member,1,true,356854);
    assert.equal(await mr.checkRoleIdByAddress(member,1), true, "user not added to AB");
  });

  it("Should check getters", async function (){
    this.timeout(100000);
    let g3 = await mr.getAllAddressByRoleId(1);
    let g4 = await mr.getAllMemberLength(1);
    let g5 = await mr.getAllMemberAddressById(1,0);
    let g6 = await mr.getRolesAndMember();
    await mr.changeMasterAddress();
    await mr.updateDependencyAddresses();

    //TODO verify the data returned
  });

  it("Should change validity of member", async function () {
    this.timeout(100000);
    await mr.setRoleValidity(1,true);
    await mr.setValidityOfMember(member,1,5);
    let val = await mr.getValidity(member, 1);
    assert.equal(val.toNumber(), 5, "Validity not updated");
  }); 

  it("Should change can add member", async function() {
    this.timeout(100000);
    await mr.changeCanAddMember(1, member);
    assert.equal(await mr.getAuthrizedMemberAgainstRole(1), member, "Authorized address not changed");
  });
});