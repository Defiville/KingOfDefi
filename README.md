# KingOfDefi
KingOfDefi is a game where players can buy virtual token to become the king

## Game

V0 Rules:
- Users can subscribe to the game for free, it gives 100K virtual-USD to the player.
- Players can use the v-USD to buy other virtual assets, the pair rate price is fetched via the related chainlink oracle.
- Players can swap virtual asset for the entire game period, there is only a delay to wait between swaps by the same player.
- At the end of the game period, a new crown dispute period begins and players can start to steal the crown from other players.
- The crown can be steal ONLY IF the actual USD value of the total virtual assets bought is higher than the actual crown holder usd value.
- At the end of the dispute period, the king can redeem the prize.

Prize:
- Every ERC20 token is supported as prize, and everyone can topUp the game prize.

V0 Game Parameter:
- game duration (duration of the game, it is the period where players can do swaps)
- crown dispute duration (it is the dispute duration, when the game durations ends, players can steal the crown during this period)
- swap delay duration (it is the swap delay, a player needs to wait this period between 2 swaps)


## Dev

Install packages

`yarn`

Compile contracts

`yarn compile`

Run test

`yarn test`
