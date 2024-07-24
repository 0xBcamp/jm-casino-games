import { ConnectButton } from "thirdweb/react";
import { defineChain, ThirdwebClient } from "thirdweb";
import { sepolia } from "thirdweb/chains";

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
                        className="d-inline-block align-text-centre" />
                    <span className="fw-bolder fs-4">
                        {brandName}
                    </span>
                </a>
                {/* use modeNetwork in production */}
                <ConnectButton client={client} chain={sepolia}/>
            </div>
        </nav>
    )
}

export default NavBar;