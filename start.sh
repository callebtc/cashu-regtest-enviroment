#!/bin/bash
print_success() {
  printf "\033[;1;32mPASSED\033[;0m $1\n"
}

print_error() {
  printf "\033[;1;31mFAILED\033[;0m $1\n"
}

run(){
  label=$1
  value=$2
  cmd=$3
  if [[ "$cmd" == "$value" ]]; then
    print_success "$label is $cmd"
  else
    print_error "$label is $cmd, should be $value"
    failed="true"
  fi
}

failed="false"
blockheight=201
utxos=3
channel_size=24000000 # 0.024 btc
balance_size=12000000 # 0.012 btc

source docker-scripts.sh
cashu-regtest-start
echo "=================================="
printf "\033[;1;36mregtest started! starting tests...\033[;0m\n"
echo "=================================="
echo ""

for i in 1 2 3; do
  run "lnd-$i .synced_to_chain" "true" $(lncli-sim $i getinfo | jq -r ".synced_to_chain")
  run "lnd-$i utxo count" $utxos $(lncli-sim $i listunspent | jq -r ".utxos | length")
  run "lnd-$i .block_height" $blockheight $(lncli-sim $i getinfo | jq -r ".block_height")
  if [[ "$i" == "1" ]]; then
    channel_count=5
  elif [[ "$i" == "3" ]]; then
    channel_count=3
  else 
    channel_count=2
  fi
  run "lnd-$i openchannels" $channel_count $(lncli-sim $i listchannels | jq -r ".channels | length")
  run "lnd-$i .channels[0].capacity" $channel_size $(lncli-sim $i listchannels | jq -r ".channels[0].capacity")
  run "lnd-$i .channels[0].push_amount_sat" $balance_size $(lncli-sim $i listchannels | jq -r ".channels[0].push_amount_sat")
done
for i in 1 2 3; do
  # run "cln-$i blockheight" $blockheight $(lightning-cli-sim $i getinfo | jq -r ".blockheight")
  run "cln-$i utxo count" $utxos $(lightning-cli-sim $i listfunds | jq -r ".outputs | length")
  run "cln-$i openchannels" 2 $(lightning-cli-sim $i getinfo | jq -r ".num_active_channels")
  run "cln-$i channel[0].state" "CHANNELD_NORMAL" $(lightning-cli-sim $i listfunds | jq -r ".channels[0].state")
  run "cln-$i channel[0].amount_msat" $(($channel_size * 1000)) $(lightning-cli-sim $i listfunds | jq -r ".channels[0].amount_msat" | sed 's/msat//g')
  run "cln-$i channel[0].our_amount_msat" $(($balance_size * 1000)) $(lightning-cli-sim $i listfunds | jq -r ".channels[0].our_amount_msat" | sed 's/msat//g')
done

run "lnbits service status" "200" $(curl -s -o /dev/null -w "%{http_code}" "http://localhost:5001/")

# return non-zero exit code if a test fails
if [[ "$failed" == "true" ]]; then
  echo ""
  echo "=================================="
  print_error "one more more tests failed"
  echo "=================================="
  exit 1
else
  echo ""
  echo "=================================="
  print_success "all tests passed! yay!"
  echo "=================================="
fi
