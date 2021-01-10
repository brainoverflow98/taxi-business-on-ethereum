pragma solidity ^0.7.0;

contract TaxiBusiness {
    
    //CONSTANTS
    uint constant private fixedExpenses = 10 ether;
    uint constant private participationFee = 30 ether;
    uint8 constant private participantLimit = 9;
    uint constant private dateIntervalUnit = 1 seconds;  // time unit for testing time dependent functions.
    uint constant private profitDistributionInterval = 60 * dateIntervalUnit;
    uint constant private carExpensePaymentInterval = 60 * dateIntervalUnit;
    uint constant private salaryPaymentInterval = 30 * dateIntervalUnit;
   
   //STATE VARIABLES
   ParticipantRegistry private participants;
   address public manager;
   TaxiDriver public taxiDriver;
   DriverProposal public proposedDriver;
   uint public contractBalance;
   address payable public carDealer;
   uint112 public ownedCar;
   CarProposal public proposedCar;
   CarProposal public proposedRepurchase;
   uint public nextProfitDistributionDate;
   uint public nextCarExpensePaymentDate;
   
   //FUNCTIONS
   constructor()
   {
       manager = msg.sender;
       nextProfitDistributionDate = block.timestamp + profitDistributionInterval;
       nextCarExpensePaymentDate = block.timestamp + carExpensePaymentInterval;
   }
   
   /*function contractBalance() public view returns(uint)
   {
       return address(this).balance;
   }*/
   
   function join() external payable
   {
       require(msg.value == participationFee, "Sent ammount does not match the participation fee.");
       require(participants.accounts.length < participantLimit, "Participant limit is reached.");
       require(participants.isEntranceFeePaid[msg.sender] == false, "You already joined as participant.");
       participants.isEntranceFeePaid[msg.sender] = true;
       participants.accounts.push(msg.sender);
       contractBalance += msg.value;
   }
   
   function setCarDealer(address payable addr) external onlyManager
   {
       carDealer = addr;
   }
   
   function carProposeToBusiness(uint112 carId, uint priceInEther, uint validFor) external onlyDealer
   {
       proposedCar.carId = carId;
       proposedCar.price = priceInEther * 1 ether;
       proposedCar.offerValidTime = block.timestamp + validFor * dateIntervalUnit;
       proposedCar.approvalState = 0;
       delete proposedCar.voters;
   }
   
   function approvePurchaseCar() external onlyParticipant
   {
       for(uint i=0; i < proposedCar.voters.length; i++ )
       {
           if(proposedCar.voters[i] == msg.sender)
                revert("You have already voted.");
       }
       proposedCar.voters.push(msg.sender);
       proposedCar.approvalState += 1;
   }
   
   
   function purchaseCar() external onlyManager
   {
       require(proposedCar.offerValidTime > block.timestamp, "Offer is expired");
       require(proposedCar.approvalState > participants.accounts.length / 2, "Proposed car is not approved by the participants.");
       carDealer.transfer(proposedCar.price);
       contractBalance -= proposedCar.price;
       ownedCar = proposedCar.carId;
       proposedCar.offerValidTime = 0;
   }
   
   
   function repurchaseCarPropose(uint112 carId, uint priceInEther, uint validFor) external onlyDealer
   {
       proposedRepurchase.carId = carId;
       proposedRepurchase.price = priceInEther * 1 ether;
       proposedRepurchase.offerValidTime = block.timestamp + validFor * dateIntervalUnit;
       proposedRepurchase.approvalState = 0;
       delete proposedCar.voters;
   }
   
   
   function approveSellProposal() external onlyParticipant
   {
       for(uint i=0; i < proposedRepurchase.voters.length; i++ )
       {
           if(proposedRepurchase.voters[i] == msg.sender)
                revert("You have already voted.");
       }
       proposedRepurchase.voters.push(msg.sender);
       proposedRepurchase.approvalState += 1;
   }
   
   function repurchaseCar() external payable onlyDealer
   {
       require(proposedRepurchase.offerValidTime > block.timestamp, "Offer is expired.");
       require(proposedRepurchase.approvalState > participants.accounts.length / 2, "Proposed repurchase is not approved by the participants.");
       require(proposedRepurchase.price == msg.value, "Amount sent does not match with the offered price.");
       contractBalance += msg.value;
       ownedCar = 0;
       proposedRepurchase.offerValidTime = 0;
   }
   
   function proposeDriver(address payable addr, uint salaryInEther) external onlyManager
   {
       proposedDriver.account = addr;
       proposedDriver.salary = salaryInEther * 1 ether;
       proposedDriver.approvalState = 0;
       delete proposedDriver.voters;
   }
   
   function approveDriver() external onlyParticipant
   {
       for(uint i=0; i < proposedDriver.voters.length; i++ )
       {
           if(proposedDriver.voters[i] == msg.sender)
                revert("You have already voted.");
       }
       proposedDriver.voters.push(msg.sender);
       proposedDriver.approvalState += 1;
   }
   
   function setDriver() external onlyManager
   {
       require(proposedDriver.approvalState > participants.accounts.length / 2, "Proposed driver is not approved by the participants.");
       require(taxiDriver.account == address(0), "You should fire the current driver first.");
       taxiDriver.account = proposedDriver.account;
       taxiDriver.salary = proposedDriver.salary;
       taxiDriver.nextSalaryPaymentDate = block.timestamp + salaryPaymentInterval;
       taxiDriver.balance = 0;
   }
   
   function fireDriver() external onlyManager
   {
       require(taxiDriver.account != address(0), "There is not a driver to fire.");
       taxiDriver.account.transfer(taxiDriver.balance + taxiDriver.salary);
       contractBalance -= taxiDriver.balance + taxiDriver.salary;
       delete taxiDriver;
   }
   
   function payTaxiCharge() external payable
   {
       contractBalance += msg.value;
   }
   
   
   function releaseSalary() external onlyManager 
   {
       require(block.timestamp > taxiDriver.nextSalaryPaymentDate, "Driver salary can be claimed once a month.");
       contractBalance -= taxiDriver.salary;
       taxiDriver.balance += taxiDriver.salary;
       taxiDriver.nextSalaryPaymentDate += salaryPaymentInterval;
   }
   
   function getSalary() external onlyDriver
   {
       taxiDriver.account.transfer(taxiDriver.balance);
       taxiDriver.balance = 0;
   }
   
   
   function payCarExpenses() external payable onlyManager
   {
       require(block.timestamp > nextCarExpensePaymentDate, "Car expenses can be paid once in 6 months.");
       carDealer.transfer(fixedExpenses);
       contractBalance -= fixedExpenses;
       nextCarExpensePaymentDate += carExpensePaymentInterval;
   }
   
   function payDividend() external onlyManager
   {
       require(block.timestamp > nextProfitDistributionDate, "Profit can be distributed once in 6 months.");
       uint share = contractBalance / participants.accounts.length;
       for(uint i=0; i<participants.accounts.length; i++ )
       {
           address acc = participants.accounts[i];
           participants.balances[acc] += share;
           
       }
       contractBalance = 0;
       nextProfitDistributionDate += profitDistributionInterval;
   }
   
   
   function getDividend() external onlyParticipant
   {
       msg.sender.transfer(participants.balances[msg.sender]);
       participants.balances[msg.sender] = 0;
   } 
   
   fallback() external
   {}
   
   //STRUCTS
   struct ParticipantRegistry
   {
        mapping(address => bool) isEntranceFeePaid;
        mapping(address => uint) balances;
        address payable[] accounts;
   }
   
   struct TaxiDriver
   {
        address payable account;
        uint balance;
        uint salary;
        uint nextSalaryPaymentDate;
   }
   
   struct DriverProposal
   {
        uint8 approvalState;
        address payable account;
        uint salary;
        address[] voters; // to make it easier to delete
   }
   
   struct CarProposal
   { 
        uint112 carId;
        uint8 approvalState;
        uint price;
        uint offerValidTime;
        address[] voters;
   }
   
   
   
   //MODIFIERS
   modifier onlyManager {
      require(msg.sender == manager, "You are not a valid Manager.");
      _;
   }
   
   modifier onlyParticipant {
      require( participants.isEntranceFeePaid[msg.sender] == true, "You are not a valid participant.");
      _;
   }
   
   modifier onlyDriver {
      require( msg.sender == taxiDriver.account, "You are not a valid Taxi Driver.");
      _;
   }
   
   modifier onlyDealer {
      require( msg.sender == carDealer, "You are not a valid Car Dealer.");
      _;
   }
}