# This branch is for experimental builds and may be unstable.

## Currently Testing

- Stuck Player Checker
This build has an option for checking for stuck players.

There are 2 config options for this:

## HandleStuckPlayers

0 - disabled

1 - slay

2 - teleport to last location

3 - teleport to random runner

4 - respawn (for maps without a motivator)

## StuckPlayerTimeout

This is a float value which runs the checker every X seconds if HandleStuckPlayers is enabled

## TO-DO: allow per-map basis of stuck player checker!
