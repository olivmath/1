"""
Automation for update debug section in front-end
"""

from dataclasses import dataclass, field
from json import dumps, load
from typing import List
import json
import glob
import os


@dataclass
class Contract:
    """
    # Contract must have:
    - contractAddress: str
    - contractName: str
    - abi: list
    """

    name: str
    address: str
    abi: list = field(default_factory=list)


CHAIN_ID = int(os.getenv('CHAIN_ID'))
CONTRACT_SCRIPT_NAME = "Deploy.s.sol"
TRANSACTIONS_PATH = f"broadcast/{CONTRACT_SCRIPT_NAME}/{CHAIN_ID}/run-latest.json"
TARGET_DIR_UI = "../ui/contracts/deployedContracts.ts"

CONTRACTS = []



def abi_path(name) -> str:
    return f"artifacts/{name}.sol/{name}.json"


def print_step(message):
    print(f"\n\033[1;34m>>> {message}\033[0m")


def print_success(message):
    print(f"\033[1;32m✓ {message}\033[0m")


def print_warning(message):
    print(f"\033[1;33m! {message}\033[0m")


def print_error(message):
    print(f"\033[1;31m✗ {message}\033[0m")


def generate_typescript_for_ui(contracts):
    print_step("Gerando arquivo TypeScript para UI")
    typescript_content = f"""
import {{ GenericContractsDeclaration }} from "~~/utils/fwt/contract";

const deployedContracts = {{
    {CHAIN_ID}: {dumps({
        contract.name: {
            "address": contract.address,
            "abi": contract.abi,
        }
        for contract in contracts
    }, indent=4)}
}} as const;

export default deployedContracts satisfies GenericContractsDeclaration;
"""

    with open(TARGET_DIR_UI, "w") as ts_file:
        ts_file.write(typescript_content)
    print_success(f"Arquivo de contratos atualizado em {TARGET_DIR_UI}")

def updateABI():
    print_step("Iniciando atualização de ABIs e endereços")

    print("Lendo transações do arquivo de broadcast...")
    with open(TRANSACTIONS_PATH) as deployed_contracts:
        json_file = load(deployed_contracts)
        transactions = json_file["transactions"]
        contracts: List[Contract] = []

        print(f"Encontradas {len(transactions)} transações")

        for contract in transactions:
            if contract["transactionType"] == "CREATE":
                name, address = contract["contractName"], contract["contractAddress"]
                print(f"Processando contrato: {name} ({address})")
                CONTRACTS.append(name)

                abi_file_path = abi_path(name)
                print(f"Lendo ABI de {abi_file_path}")

                with open(abi_file_path) as full_abi_json:
                    abi = load(full_abi_json)["abi"]
                    contracts.append(Contract(name, address, abi))
                    print_success(f"ABI de {name} carregada com sucesso")

    generate_typescript_for_ui(contracts)



def get_metadata():
    print_step("Processando metadados de build")

    print("Procurando arquivos de build info...")
    BUILD_INFO = glob.glob("artifacts/build-info/*.json")
    if not BUILD_INFO:
        print_error("Nenhum arquivo de build info encontrado!")
        return

    BUILD_INFO = BUILD_INFO[0]
    print(f"Usando arquivo de build: {BUILD_INFO}")

    with open(BUILD_INFO) as build_info:
        json_file = load(build_info)
        contracts_data = json_file["output"]["contracts"]
        print(
            f"Total de contratos encontrados: {sum(len(v) for v in contracts_data.values())}"
        )

        print("Filtrando contratos relevantes...")
        filtered_contracts = {
            contract_path: {
                name: contracts_data[contract_path][name]
                for name in contracts_data[contract_path]
                if name in CONTRACTS
            }
            for contract_path in contracts_data
            if any(name in contracts_data[contract_path] for name in CONTRACTS)
        }

        print(
            f"Contratos após filtro: {sum(len(v) for v in filtered_contracts.values())}"
        )
        json_file["output"]["contracts"] = filtered_contracts

    print("Salvando metadados filtrados...")
    with open(BUILD_INFO, "w") as build_info:
        json.dump(json_file, build_info, indent=4)
    print_success("Metadados atualizados com sucesso")


print_step("Iniciando processo de atualização de contratos")
updateABI()
get_metadata()
print_success("Processo concluído com sucesso!")
