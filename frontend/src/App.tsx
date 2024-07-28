import React, { useState } from "react";
import NavBar from "../src/components/navbar"
import imagePath from '../../images/logo.png'
<<<<<<< HEAD
import { ThirdwebProvider } from "thirdweb/react";
useSendTransaction
import { prepareContractCall, getContract } from "thirdweb";
import { client } from "../src/components/navbar"
import { sepolia } from "thirdweb/chains";


interface startGameProps {
  amount: ;
  selectedTiles: string;
}

function startGame(amount: number) {
  const contract = getContract({
    client,
    chain: sepolia,
    address: "0xdaE97900D4B184c5D2012dcdB658c008966466DD"
  });

  const { mutate: sendTransaction, isPending } = useSendTransaction();

}
=======
import { ThirdwebProvider, useContractEvents, useSendAndConfirmTransaction } from "thirdweb/react";
import { getContract, createThirdwebClient, ThirdwebContract, prepareContractCall, toWei, prepareEvent } from "thirdweb";
import { sepolia } from "thirdweb/chains";
import treasureTilesABI from "./ABI/TreasureTiles.json";
import { Abi } from "abitype";

const client = createThirdwebClient({ clientId: "a1160023f3d1c79e1d3daaa691841217" });

const treasureTilesContract = getContract({
  client,
  chain: sepolia,
  address: "0xdaE97900D4B184c5D2012dcdB658c008966466DD",
  abi: treasureTilesABI as Abi,
});
>>>>>>> e3998a6c9429f124a123c997c5595cd0bdac9ee8

type TileProps = {
  index: number;
  state: TileState;
  modifyTileState: (state: TileState) => void;
};
type TileState = "unclicked" | "clicked" | "mine" | "gem";

const TILE_COUNT = 25;

function Tile({
  index,
  state,
  modifyTileState,
}: React.PropsWithChildren<TileProps>) {
  const handleClick = () => {
    console.log(`Tile ${index} clicked`);
    // setState(Math.random() < 1 / 25 ? "mine" : "gem");
    modifyTileState(state === "clicked" ? "unclicked" : "clicked");
  };

  return (
    <button
      key={index}
      onClick={handleClick}
      data-state={state}
      className="relative flex items-center justify-center text-3xl transition-transform duration-100 rounded-lg isolate size-24 btn"
    >
      <span className="inline-block -translate-y-1">
        {state === "mine" && "💣"}
        {state === "gem" && "💎"}
      </span>
    </button>
  );
}

function BetWidget({
  handleStartGame,
  handleReset,
}: {
  handleStartGame: (betAmount: number) => void;
  handleReset: () => void;
}) {
  const [betAmount, setBetAmount] = useState(0);
  const handleBetAmountChange = (event: React.ChangeEvent<HTMLInputElement>) => {
    setBetAmount(Number(event.target.value));
  }

  const handleStart = () => {
    handleStartGame(betAmount);
  }
  return (
    <>
      <label className="flex flex-col gap-4">
        Bet Amount (in ETH)
        <input
          type="number"
          placeholder="Enter bet amount"
          className="p-2 border border-gray-400 rounded-lg bg-gray-50"
          // value={betAmount}
          onChange={handleBetAmountChange}
        />
      </label>
      <div className="flex items-center w-full gap-4">
        <button
          onClick={handleReset}
          className="grid w-full px-4 py-3 text-red-900 bg-red-200 rounded-lg place-items-center"
        >
          Reset
        </button>
        <button
          onClick={handleStart}
          className="grid w-full px-4 py-3 text-indigo-900 bg-indigo-200 rounded-lg place-items-center"
        >
          Start Game
        </button>
      </div>
    </>
  );
}

function App() {
  const [states, setStates] = React.useState<TileState[]>(
    Array.from({ length: TILE_COUNT }).map(() => "unclicked")
  );

  const { mutate: sendTransaction, data: transactionReceipt } = useSendAndConfirmTransaction();
  // const { data, isLoading, error } = useContractEvents (treasureTilesContract as ThirdwebContract);
  // const randomnessFulfilledEvent = prepareEvent({
  //   signature: "event RandomnessFulfilled(uint256 indexed nonce, Game)"
  // })
  
  // const contractEvents = useContractEvents({
  //   contract: treasureTilesContract as ThirdwebContract,
  //   events: [randomnessFulfilledEvent],
  // });

  const modifyTileState = (index: number, newState: TileState) => {
    setStates((prevStates) => {
      const newStates = [...prevStates];
      newStates[index] = newState;
      return newStates;
    });
  };

  const handleStartGame = async (betAmount: number) => {
    // setStates((prevStates) => {
    //   const newStates = [...prevStates];
    //   for (let i = 0; i < TILE_COUNT; i++) {
    //     if (prevStates[i] === "clicked") {
    //       newStates[i] = Math.random() < 1 / 25 ? "mine" : "gem";
    //     }
    //   }
    //   return newStates;
    // });
    const clicked = states.filter((state) => state === "clicked").length;
    if (clicked === 0) {
      alert("Please click on some tiles first");
      return;
    }
    if (betAmount === 0) {
      alert("Please enter a bet amount");
      return;
    }

    const betInWei = toWei (betAmount.toString());

    const tx = prepareContractCall({
      contract: treasureTilesContract as ThirdwebContract,
      method: "function startGame(uint256 selectedTiles, uint256 betAmount)",
      params: [BigInt (clicked), BigInt (betInWei)],
      value: BigInt (betInWei),
    });

    sendTransaction(tx);

  };

  const handleReset = () => {
    setStates(Array.from({ length: TILE_COUNT }).map(() => "unclicked"));
  };

  return (
        <div>
          <NavBar 
          imageSrcPath={imagePath}
          brandName="Treasure Tiles"
          client={client} />
          <main className="grid w-full h-screen place-items-center">
            <div className="grid grid-cols-2 gap-4 p-4 bg-gray-200 border rounded-lg border-gray-400/25">
              <div className="flex flex-col justify-between rounded-lg">
                <BetWidget
                  handleStartGame={handleStartGame}
                  handleReset={handleReset}
                />
              </div>
              <div className="grid grid-cols-5 grid-rows-5 gap-4">
                {Array.from({ length: TILE_COUNT }).map((_, index) => (
                  <Tile
                    key={index}
                    index={index}
                    state={states[index]}
                    modifyTileState={(newState) => modifyTileState(index, newState)}
                  />
                ))}
              </div>
            </div>
            <div>
            </div>
            <div>
              {transactionReceipt && (
                <div>
                  <h2>Transaction Receipt</h2>
                  <pre>{transactionReceipt.status}</pre>
                  {contractEvents.data && (
                    <pre>{JSON.stringify(contractEvents.data, null, 2)}</pre>
                  )}
                </div>
              )}
            </div>
          </main>
        </div>
  );
}

function AppWrapper () {
  return (
    <ThirdwebProvider>
      <App />
    </ThirdwebProvider>
  )
}

export default AppWrapper;
