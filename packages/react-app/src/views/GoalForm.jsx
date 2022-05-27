import { useContractReader } from "eth-hooks";
import { ethers, utils } from "ethers";
import React, { useEffect } from "react";
import { Input, Button } from "antd";
import { useState } from "react";

function GoalForm({ readContracts, writeContracts, tx }) {
    let [linkFees, setLinkFees]= useState("");
    
    useEffect(() => {
        async function fetchFees() {
          const fees = await readContracts.Spouf.LINK_FEES();
          setLinkFees(utils.formatUnits(fees, 18));
        }

        if (readContracts.Spouf !== undefined) {
          fetchFees();
        };
    }, [readContracts.Spouf]);
    
    const [goal, setGoal] = useState({
        name: "",
        deadline: 0,
        amount: 0
    });

    function convertNumber(number, decimals) {
        if (number === 0 || number === undefined || !number) {
            return 0;
        } else {
            if (decimals === 0) {
                return parseInt(number, 10);
            } else {
                return utils.parseUnits(number, decimals);
            }
        }
    }

    function convertDate(date) {
        return Math.floor(new Date(date).getTime() / 1000);
    }

  return (
    <div style={{ border: "1px solid #cccccc", padding: 16, width: 600, margin: "auto", marginTop: 64, display: "flex", flexDirection: "column", justifyContent: "center", alignItems: "center" }}>
      <h1>Define your goal</h1>
      
      <h3>Goal's name:</h3>
      <div style={{ margin: 8, width: "50%" }}>
        <Input type="text" placeholder="Get a Six Pack 💪" required
        onChange={(e) => {
            setGoal({...goal, name: e.target.value})
        }}></Input>
      </div>

      <h3>Deadline:</h3>
      <div style={{ margin: 8, width: "50%" }}>
        <Input type="datetime-local" min={
            new Date().getFullYear() + '-' +
            ((new Date().getMonth() + 1) < 10 ? '0' + (new Date().getMonth() + 1) : (new Date().getMonth() + 1)) + '-' +
            (new Date().getDate() < 10 ? '0' + new Date().getDate() : new Date().getDate()) + 'T' +
            (new Date().getHours() < 10 ? '0' + new Date().getHours() : new Date().getHours()) + ':' +
            (new Date().getMinutes() < 10 ? '0' + new Date().getMinutes() : new Date().getMinutes())
          }
          required
          onChange={(e) => {
                setGoal({...goal, deadline: convertDate(e.target.value)})
            }}>
        </Input>
      </div>

      <h3>Amount willing to lose (in USDC):</h3>
      <div style={{ margin: 8, width: "50%" }}>
        <Input onChange={(e) => {
                setGoal({...goal, amount: convertNumber(e.target.value, 6)})
            }} type="text" inputmode="decimal" autocomplete="off" autocorrect="off" pattern="^[0-9]*[.,]?[0-9]*$" minlength="1" maxlength="79" placeholder="0.0" min="0.0" step="0.00000001" required></Input>
      </div>

      <Button
      style={{ marginTop: 8, width: "30%" }}
      onClick={async () => {
          // USDC approval
        tx(writeContracts.USDC.approve(writeContracts.Spouf.address, goal.amount)).then((USDCTx) => {
          // LINK approval
          if (USDCTx) {
            tx(writeContracts.LINK.approve(writeContracts.Spouf.address, convertNumber("0.2", 18))).then(async (LINKTx) => {
              if (LINKTx) {
                await tx(writeContracts.Spouf.setGoal(
                  goal.name,
                  goal.deadline,
                  goal.amount,
                  { gasLimit: 300000 }
                ));
              }
            });
          }
        });
      }}
      >Create goal</Button>
      <div style={{ margin: 8 }}>
        <span style={{ fontWeight: "bold" }}>You'll have to accept 3 transactions coming one after another:</span>
        <ul style={{ textAlign: "start", listStylePosition: "inside" }}>
            <li>1. Grant the permission for the contract to receive your USDC</li>
            <li>2. Grant he permission for the contract to receive your { linkFees } LINK (used to pay for fees with Chainlink Keepers)</li>
            <li>3. Call the contract the create your goal</li>
        </ul>
      </div>
    </div>
  );
}

export default GoalForm;
