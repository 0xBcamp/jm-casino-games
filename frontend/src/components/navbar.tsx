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
            <div className="container-fluid d-flex align-items-center">
                <a className="navbar-brand d-flex align-items-center" href="#">
                    <img
                        src={imageSrcPath}
                        alt="Brand Logo"
                        width="60"
                        height="100"
                        className="d-inline-block align-text-center" />
                    <span className="fw-bolder fs-4 ms-2">
                        {brandName}
                    </span>
                </a>
                <div className="ms-auto"> {/* Use ms-auto for right alignment */}
                    {/* Use modeNetwork in production */}
                    <ConnectButton client={client} chain={sepolia} />
                </div>
            </div>
        </nav>
    );
}

export default NavBar;
