import React from "react";
import NavBar from "../src/components/navbar"
import 'bootstrap/dist/css/bootstrap.css'
import imagePath from '../../images/logo.png'
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
  handleStartGame: () => void;
  handleReset: () => void;
}) {
  return (
    <>
      <label className="flex flex-col gap-4">
        Bet Amount
        <input
          type="text"
          placeholder="Enter bet amount"
          className="p-2 border border-gray-400 rounded-lg bg-gray-50"
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
          onClick={handleStartGame}
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

  const modifyTileState = (index: number, newState: TileState) => {
    setStates((prevStates) => {
      const newStates = [...prevStates];
      newStates[index] = newState;
      return newStates;
    });
  };

  const handleStartGame = () => {
    setStates((prevStates) => {
      const newStates = [...prevStates];
      for (let i = 0; i < TILE_COUNT; i++) {
        if (prevStates[i] === "clicked") {
          newStates[i] = Math.random() < 1 / 25 ? "mine" : "gem";
        }
      }
      return newStates;
    });
  };

  const handleReset = () => {
    setStates(Array.from({ length: TILE_COUNT }).map(() => "unclicked"));
  };

  return (
    <ThirdwebProvider>
    <div>
      <NavBar 
      brandName="Treasure Tiles"
      imageSrcPath={imagePath} />
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
      </main>
    </div>
    </ThirdwebProvider>
  );
}

export default App;
