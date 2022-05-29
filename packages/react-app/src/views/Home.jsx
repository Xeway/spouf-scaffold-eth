import { useContractReader } from "eth-hooks";
import { ethers, utils } from "ethers";
import React from "react";
import { useEffect } from "react";
import { useState } from "react";
import { Link } from "react-router-dom";
import { Divider, Button, Checkbox } from "antd";
import { Address } from "../components";
import moment from "moment";

/**
 * web3 props can be passed from '../App.jsx' into your local view component for use
 * @param {*} yourLocalBalance balance on current network
 * @param {*} readContracts contracts from current chain already pre-loaded using ethers contract module. More here https://docs.ethers.io/v5/api/contract/contract/
 * @returns react component
 **/
function Home({ tx, yourLocalBalance, readContracts, writeContracts, address, mainnetProvider }) {
  // you can also use hooks locally in your component of choice
  // in this case, let's keep track of 'purpose' variable from our contract

  const [goals, setGoals] = useState([]);

  useEffect(() => {
    async function fetchGoals(updateNeeded, newGoals) {
      let result;
      if (updateNeeded) {
        result = newGoals;
      } else {
        result = await writeContracts.Spouf.getGoal();
      }

      const arr = [];

      result.forEach(goal => {
        let g, deadline, amount, status;
        for (const key of goal.keys()) {
          switch (key) {
            case 0:
              g = goal[key];
              break;
            case 1:
              deadline = goal[key];
              break;
            case 2:
              amount = goal[key];
              break;
            case 3:
              status = goal[key];
              break;
          }
        }

        arr.push({
          goal: g,
          deadline: deadline,
          amount: amount,
          status: status,
          timeLeft: null
        });
      });

      setGoals(arr);

      writeContracts.Spouf.on("UpdateGoals", (updatedGoals) => {
        fetchGoals(true, updatedGoals);
      });
    }

    if (writeContracts.Spouf !== undefined) {
      fetchGoals(false, null);
    }
  }, [writeContracts.Spouf]);

  function computeTimeLeft(deadline, index) {
    window.setInterval(() => {
      const now = moment();
      const timeLeft = moment.duration(moment(new Date(deadline)).diff(now));

      const newArr = [...goals];
      newArr[index].timeLeft = `
      ${timeLeft.years() > 0 ? timeLeft.years() + " years" : ""}
      ${timeLeft.months() > 0 || timeLeft.years() > 0 ? timeLeft.months() + " months" : ""}
      ${timeLeft.days() > 0 || timeLeft.months() > 0 ? timeLeft.days() + " days" : ""}
      ${timeLeft.hours() > 0 || timeLeft.days() > 0 ? timeLeft.hours() + " hours" : ""}
      ${timeLeft.minutes() > 0 || timeLeft.hours() > 0 ? timeLeft.minutes() + " minutes" : ""}
      ${timeLeft.seconds() > 0 || timeLeft.minutes() > 0 ? timeLeft.seconds() + " seconds" : ""}
      `;
      
      setGoals(newArr);
    }, 1000);
  }

  async function deleteGoal(index, completed, event) {
    if (index < goals.length) {
      if (completed) {
        if (event.target.checked) {
          const transaction = await tx(writeContracts.Spouf.deleteGoal(index, completed));
          console.log(transaction);
          if (transaction === undefined) {
            event.target.checked = false;
            event.target.parentElement.classList.remove("ant-checkbox-checked");
          }
        }
      } else {
        await tx(writeContracts.Spouf.deleteGoal(index, completed));
      }
    } else {
      console.log("Failed (index out of bound).");
    }
  }

  return (
    <div>
      <div style={{ margin: 32, fontSize: 18 }}>
        {goals.length === 0 &&
        <>
          <h1>Hey there 👋</h1>
          <h3>We all procrastinate, right ?<br/>
          If you're searching to stop that, this dapp is made for <b>you</b> 😎</h3>
          <h4>You have a goal but you're too lazy to accomplish it ? Why not lose money if you don't complete this objective?<br/>
          Go to<Button type="link" href="./create-goal">Create goal</Button>to add yours.</h4>
          <Divider dashed />
        </>
        }

        Connected with: <Address address={address} ensProvider={mainnetProvider} fontSize={16} />
        <p>Balance: <span style={{ fontWeight: "bold" }}>{ethers.utils.formatEther(yourLocalBalance)} ETH</span></p>
      </div>

      <Divider/>

      <div style={{ margin: 32, display: "flex", justifyContent: "center", alignItems: "center" }}>
        <ul>
          {goals.map((goal, index) => {
            if (goal.status === 0) {
              return <li key={index} style={{ margin: 16, padding: 12, fontSize: "1.2rem", textAlign: "start", listStyleType: "none", border: "1px solid #cccccc", width: 400 }}>
                <h4 style={{ margin: 0, padding: 0 }}>Name</h4>{ goal.goal }<br/>
                <h4 style={{ margin: 0, padding: 0 }}>Deadline</h4>{ new Date(goal.deadline * 1000).toString().slice(0, 21) }<br/>
                <h4 style={{ margin: 0, padding: 0 }}>Pledge</h4>{ utils.formatUnits(goal.amount, 6) } USDC<br/>
                <h4 style={{ margin: 0, padding: 0, color:"#8A817C" }}>{ computeTimeLeft(goal.deadline * 1000, index) }{ goal.timeLeft }</h4>

                <span style={{ display: "flex", justifyContent: "center", alignItems: "center" }}>
                  <Checkbox onClick={(e) => { deleteGoal(index, true, e) }} style={{ marginRight: 10 }}>Complete</Checkbox>
                  <Button onClick={() => { deleteGoal(index, false, null) }} type="primary" style={{ marginLeft: 10, backgroundColor: "red" }}>Delete</Button>
                </span>
              </li>
            }
          })}
        </ul>
        {(goals.filter(goal => goal.status === 0).length === 0) &&
          <h3>You have no goal up-to-date for the moment 😶</h3>
        }
      </div>
    </div>
  );
}

export default Home;
