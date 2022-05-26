import { useContractReader } from "eth-hooks";
import { ethers } from "ethers";
import React from "react";
import { Link } from "react-router-dom";

/**
 * web3 props can be passed from '../App.jsx' into your local view component for use
 * @param {*} yourLocalBalance balance on current network
 * @param {*} readContracts contracts from current chain already pre-loaded using ethers contract module. More here https://docs.ethers.io/v5/api/contract/contract/
 * @returns react component
 **/
function Home({ yourLocalBalance, readContracts, writeContracts }) {
  // you can also use hooks locally in your component of choice
  // in this case, let's keep track of 'purpose' variable from our contract

  console.log(writeContracts.Spouf);

  return (
    <div>
      <div style={{ margin: 32 }}>

      </div>
      <div style={{ margin: 32 }}>
        <span style={{ fontWeight: "bold" }}>Your balance: {ethers.utils.formatEther(yourLocalBalance)} ETH</span>
      </div>
    </div>
  );
}

export default Home;
