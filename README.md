# DEReactorController
Computer Craft: Tweaked script for controlling Draconic Evolution Reactor
# Usage
Connect computer (CC:T) to
- one reactor component(injector or stabilizer)
- one flux gate for energy output
- one flux gate for energy input

Upload `reactor-simulated-cc.lua` to the computer

Edit the config part of the script and fill in peripheral IDs

Ensure 10368 mb fuel (8 awaken draconium blocks in inventory or 10368.0 total in forth bar on GUI) in the reactor.

(idk if it works setting the maxFuelConversion in the Predict section to actual total fuel amount.)

Run the script and the reactor will be started.

Optional: Rename the script file to startup.lua to make sure it takes control on server start.

# How
This script works by calculating best energySaturation which keep the reactor at 8000℃, then calculate the generation and consumption rate.

DE is kind that at a specific energy saturation level, the temperature naturally converges to a stable value.
