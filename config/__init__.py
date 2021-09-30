## Ideally, they have one file with the settings for the strat and deployment
## This file would allow them to configure so they can test, deploy and interact with the strategy

BADGER_DEV_MULTISIG = "0xb65cef03b9b89f99517643226d76e286ee999e77"

WANT = "0x2260fac5e5542a773aa44fbcfedf7c193bc2c599"  ## wBTC
CRV_LP_COMPONENT = "0x075b1bb99792c9E1041bA13afEf80C91a1e70fB3"  ## crvRenWSBTC
REWARD_TOKEN = "0x7fc66500c84a76ad7e9c93437bfc5ac33e2ddae9"  ## AAVE Token - Needs to be changed later.

PROTECTED_TOKENS = [WANT, CRV_LP_COMPONENT, REWARD_TOKEN]
## Fees in Basis Points
DEFAULT_GOV_PERFORMANCE_FEE = 1000
DEFAULT_PERFORMANCE_FEE = 1000
DEFAULT_WITHDRAWAL_FEE = 50

FEES = [DEFAULT_GOV_PERFORMANCE_FEE, DEFAULT_PERFORMANCE_FEE, DEFAULT_WITHDRAWAL_FEE]

REGISTRY = "0xFda7eB6f8b7a9e9fCFd348042ae675d1d652454f"  # Multichain BadgerRegistry
