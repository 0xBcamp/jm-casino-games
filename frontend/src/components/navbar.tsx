import { ConnectButton } from "thirdweb/react";
import { createThirdwebClient } from "thirdweb";


export const client = createThirdwebClient({ clientId: "a1160023f3d1c79e1d3daaa691841217" });


interface NavBarProps {
    brandName: string;
    imageSrcPath: string;
}

function NavBar({ brandName, imageSrcPath }: NavBarProps) {
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
                <div className="ml-auto">
                    <ConnectButton  client={client}/>
                </div>
            </div>
        </nav>
    );
}

export default NavBar;
