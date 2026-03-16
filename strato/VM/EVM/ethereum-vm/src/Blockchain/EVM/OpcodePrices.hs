{-# OPTIONS_GHC -fno-warn-missing-signatures -fno-warn-type-defaults #-}

module Blockchain.EVM.OpcodePrices where

import Blockchain.EVM.Opcodes
import Blockchain.Strato.Model.Gas
import Prelude hiding (EQ, GT, LT)

opGasPrice :: Operation -> Gas
opGasPrice DUP1 = 3
opGasPrice DUP2 = 3
opGasPrice DUP3 = 3
opGasPrice DUP4 = 3
opGasPrice DUP5 = 3
opGasPrice DUP6 = 3
opGasPrice DUP7 = 3
opGasPrice DUP8 = 3
opGasPrice DUP9 = 3
opGasPrice DUP10 = 3
opGasPrice DUP11 = 3
opGasPrice DUP12 = 3
opGasPrice DUP13 = 3
opGasPrice DUP14 = 3
opGasPrice DUP15 = 3
opGasPrice DUP16 = 3
opGasPrice SWAP1 = 3
opGasPrice SWAP2 = 3
opGasPrice SWAP3 = 3
opGasPrice SWAP4 = 3
opGasPrice SWAP5 = 3
opGasPrice SWAP6 = 3
opGasPrice SWAP7 = 3
opGasPrice SWAP8 = 3
opGasPrice SWAP9 = 3
opGasPrice SWAP10 = 3
opGasPrice SWAP11 = 3
opGasPrice SWAP12 = 3
opGasPrice SWAP13 = 3
opGasPrice SWAP14 = 3
opGasPrice SWAP15 = 3
opGasPrice SWAP16 = 3
opGasPrice (PUSH _) = 3
opGasPrice ADD = 3
opGasPrice MUL = 5
opGasPrice SUB = 3
opGasPrice DIV = 5
opGasPrice SDIV = 5
opGasPrice MOD = 5
opGasPrice SMOD = 5
opGasPrice ADDMOD = 8
opGasPrice MULMOD = 8
opGasPrice SIGNEXTEND = 5
opGasPrice LT = 3
opGasPrice GT = 3
opGasPrice SLT = 3
opGasPrice SGT = 3
opGasPrice EQ = 3
opGasPrice ISZERO = 3
opGasPrice AND = 3
opGasPrice OR = 3
opGasPrice XOR = 3
opGasPrice NOT = 3
opGasPrice BYTE = 3
opGasPrice SHL = 3
opGasPrice SHR = 3
opGasPrice SAR = 3
opGasPrice ADDRESS = 2
opGasPrice BALANCE = 20
opGasPrice ORIGIN = 2
opGasPrice CALLER = 2
opGasPrice CALLVALUE = 2
opGasPrice CALLDATALOAD = 3
opGasPrice CALLDATASIZE = 2
opGasPrice CODESIZE = 2
opGasPrice GASPRICE = 2
opGasPrice EXTCODESIZE = 20
opGasPrice BLOCKHASH = 20
opGasPrice COINBASE = 2
opGasPrice TIMESTAMP = 2
opGasPrice NUMBER = 2
opGasPrice DIFFICULTY = 2
opGasPrice GASLIMIT = 2
opGasPrice RETURNDATASIZE = 2
opGasPrice POP = 2
opGasPrice MLOAD = 3
opGasPrice MSTORE = 3
opGasPrice MSTORE8 = 3
opGasPrice SLOAD = 50
opGasPrice JUMP = 8
opGasPrice JUMPI = 10
opGasPrice PC = 2
opGasPrice MSIZE = 2
opGasPrice GAS = 2
opGasPrice JUMPDEST = 1
opGasPrice CREATE = 32000
opGasPrice CALLCODE = 40
opGasPrice RETURN = 0
opGasPrice STOP = 0
opGasPrice REVERT = 0
opGasPrice INVALID = 0
opGasPrice SUICIDE = 0
opGasPrice (MalformedOpcode _) = 0 --gonna fail anyway, just put something arbitrary here
opGasPrice x = error $ "Missing opcode in opCodePrice: " ++ show x

gMEMWORD = 3 :: Gas

gQUADCOEFFDIV = 512 :: Gas

gEXPBASE = 10 :: Gas

gEXPBYTE = 10 :: Gas

gCALLDATACOPYBASE = 3 :: Gas

gCODECOPYBASE = 3 :: Gas

gEXTCODECOPYBASE = 20 :: Gas

gCOPYWORD = 3 :: Gas

gRETURNDATACOPYBASE = 3 :: Gas

gLOG = 375 :: Gas

gLOGTOPIC = 375 :: Gas

gLOGDATA = 8 :: Gas

gCALL = 40 :: Gas

gCALLVALUETRANSFER = 9000 :: Gas

gCALLSTIPEND = 2300 :: Gas

gCALLNEWACCOUNT = 25000 :: Gas

gCREATEDATA = 200 :: Gas

--gSHA3BASE = 30 :: Gas
--gSHA3WORD = 6 :: Gas
gECRECOVER = 3000 :: Gas

gSHA256BASE = 60 :: Gas

gSHA256WORD = 12 :: Gas

gRIPEMD160BASE = 600 :: Gas

gRIPEMD160WORD = 120 :: Gas

gIDENTITYBASE = 15 :: Gas

gIDENTITYWORD = 3 :: Gas

gQUADDIVISOR = 20 :: Gas
