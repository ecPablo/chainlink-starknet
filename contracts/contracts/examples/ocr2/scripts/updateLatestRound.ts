import { Account, Contract, defaultProvider, ec, number } from 'starknet'
import { loadContract } from './index'
import dotenv from 'dotenv'

interface Transmission {
  answer: number
  block_num: number
  observation_timestamp: number
  transmission_timestamp: number
}

const CONTRACT_NAME = 'Mock_Aggregator'
let account: Account
let mock: Contract
let transmission: Transmission

dotenv.config({ path: __dirname + '/.env' })

const rl = require('readline').createInterface({
  input: process.stdin,
  output: process.stdout,
})

async function main() {
  transmission = { answer: 0, block_num: 0, observation_timestamp: 0, transmission_timestamp: 0 }

  const keyPair = ec.getKeyPair(process.env.PRIVATE_KEY_2 as string)
  account = new Account(defaultProvider, process.env.ACCOUNT_ADDRESS_2 as string, keyPair)

  const MockArtifact = loadContract(CONTRACT_NAME)

  mock = new Contract(MockArtifact.abi, process.env.MOCK as string)
  transmission.answer = Number(await input('Enter a number for new answer: '))
  transmission.block_num = Number(await input('Enter a number for new block_num: '))
  transmission.observation_timestamp = Number(await input('Enter a number for new observation_timestamp: '))
  transmission.transmission_timestamp = Number(await input('Enter a number for new transmission_timestamp: '))
  rl.close()

  callFunction(transmission)
}

async function callFunction(transmission: Transmission) {
  const transaction = await account.execute(
    {
      contractAddress: mock.address,
      entrypoint: 'set_latest_round_data',
      calldata: [
        number.toFelt(transmission.answer),
        number.toFelt(transmission.block_num),
        number.toFelt(transmission.observation_timestamp),
        number.toFelt(transmission.transmission_timestamp),
      ],
    },
    [mock.abi],
    { maxFee: 30000000000000 },
  )
  console.log('Waiting for Tx to be Accepted on Starknet - OCR2 Deployment...')
  await defaultProvider.waitForTransaction(transaction.transaction_hash)
}

function input(prompt: string) {
  return new Promise((callbackFn, errorFn) => {
    rl.question(prompt, (uinput: string) => {
      switch (isNaN(Number(uinput))) {
        case true:
          console.log('input is not a number we will use the default value of 1')
          uinput = '1'
          break
        default:
          break
      }
      callbackFn(uinput)
    })
  })
}

main()
