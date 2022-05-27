import { useContractReader } from "eth-hooks";
import { ethers, utils } from "ethers";
import React from "react";
import { useEffect } from "react";
import { useState } from "react";
import { Link } from "react-router-dom";
import { Divider } from "antd";
import { Address } from "../components";

/**
 * web3 props can be passed from '../App.jsx' into your local view component for use
 * @param {*} yourLocalBalance balance on current network
 * @param {*} readContracts contracts from current chain already pre-loaded using ethers contract module. More here https://docs.ethers.io/v5/api/contract/contract/
 * @returns react component
 **/
function Home({ yourLocalBalance, readContracts, writeContracts, address, mainnetProvider }) {
  // you can also use hooks locally in your component of choice
  // in this case, let's keep track of 'purpose' variable from our contract

  const [goals, setGoals] = useState([]);

  useEffect(() => {
    async function fetchGoals() {
      const result = await writeContracts.Spouf.getGoal();
      setGoals(result);
    }

    if (writeContracts.Spouf !== undefined) {
      fetchGoals();
    }
  }, [writeContracts.Spouf]);

  return (
    <div>
      <div style={{ margin: 32, fontSize: 18 }}>
        Connected with: <Address address={address} ensProvider={mainnetProvider} fontSize={16} />
        <p>Balance: <span style={{ fontWeight: "bold" }}>{ethers.utils.formatEther(yourLocalBalance)} ETH</span></p>
      </div>

      <Divider/>

      <div style={{ margin: 32, display: "flex", justifyContent: "center", alignItems: "center" }}>
        <ul>
          {goals.map((goal, index) => {
            return <li key={index} style={{ margin: 16, padding: 12, fontSize: "1.2rem", textAlign: "start", listStyleType: "none", border: "1px solid #cccccc", width: 400 }}>
              <h4 style={{ margin: 0, padding: 0 }}>Name</h4>{ goal.goal }<br/>
              <h4 style={{ margin: 0, padding: 0 }}>Deadline</h4>{ new Date(goal.deadline * 1000).toString().slice(0, 21) }<br/>
              <h4 style={{ margin: 0, padding: 0 }}>Pledge</h4>{ utils.formatUnits(goal.amount, 6) } USDC<br/>
              { goal.status === 1 ? "Completed" : (goal.status === 2 ? "Expired" : (goal.status === 3 ? "Cancelled" : "")) }
            </li>
          })}
        </ul>
      </div>
    </div>
  );
}

export default Home;
