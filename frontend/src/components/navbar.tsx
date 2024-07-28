import { ConnectButton } from "thirdweb/react";
<<<<<<< HEAD
import { createThirdwebClient } from "thirdweb";


export const client = createThirdwebClient({ clientId: "a1160023f3d1c79e1d3daaa691841217" });
=======
import { defineChain, ThirdwebClient } from "thirdweb";
import { sepolia } from "thirdweb/chains";
>>>>>>> e3998a6c9429f124a123c997c5595cd0bdac9ee8

const modeNetwork = defineChain({
    name: "Mode",
    id: 34443,
    rpc: "https://mainnet.mode.network/",
});

interface NavBarProps {
    brandName: string;
    imageSrcPath: string;
    client: ThirdwebClient;
}

function NavBar({ brandName, imageSrcPath, client }: NavBarProps) {
    return (
        <nav className="navbar navbar-expand-md navbar-dark bg-dark shadow">
            <div className="container-fluid">
                <a className="navbar-brand" href="#">
                    <img
                        src={imageSrcPath}
                        alt=""
                        width="60"
                        height="100"
                        className="d-inline-block align-text-center" />
                    <span className="fw-bolder fs-4">
                         {brandName}
                    </span>
                </a>
<<<<<<< HEAD
                <div className="ml-auto">
                    <ConnectButton  client={client}/>
                </div>
=======
                {/* use modeNetwork in production */}
                <ConnectButton client={client} chain={sepolia}/>
>>>>>>> e3998a6c9429f124a123c997c5595cd0bdac9ee8
            </div>
        </nav>
    );
}

export default NavBar;
