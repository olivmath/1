import Link from "next/link";
import { anvil } from "viem/chains";
import { useTargetNetwork } from "~~/hooks/scaffold-eth";

type AddressLinkWrapperProps = {
  children: React.ReactNode;
  disableAddressLink?: boolean;
  blockExplorerAddressLink: string;
};

export const AddressLinkWrapper = ({
  children,
  disableAddressLink,
  blockExplorerAddressLink,
}: AddressLinkWrapperProps) => {
  const { targetNetwork } = useTargetNetwork();

  return disableAddressLink ? (
    <>{children}</>
  ) : (
    <Link
      href={blockExplorerAddressLink}
      target={targetNetwork.id === anvil.id ? undefined : "_blank"}
      rel={targetNetwork.id === anvil.id ? undefined : "noopener noreferrer"}
    >
      {children}
    </Link>
  );
};
