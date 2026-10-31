# Fuel Tracker

A SwiftUI iPhone and iPad app for tracking fuel across the four tanks of a Piper Cherokee 235 in flight: which tank you're feeding from, how much is left in each, and how long you can stay up.

## Features

- **Four tanks:** left tip (LT), left main (LM), right main (RM) and right tip (RT), laid out like the wing. Each ring shows how full that tank is. The tank you're currently feeding from is blue and marked with a ▲ under its name.
- **Tank switching:** tap a tank when you switch to it and enter the total fuel used so far, read from your fuel totalizer. The difference since the last switch is subtracted from the tank you were on; the sheet previews how much that leaves before you confirm.
- **Totals and endurance:**
  - **Used:** total fuel burned since the last reset.
  - **Remaining:** total fuel left across all tanks.
  - **Endurance:** time left at a 12 gal/hr burn rate, counting down since the last switch. Shown large at the top of the screen.
  - **After 45 min reserve:** endurance minus a 45-minute reserve.
  - Both endurance times turn red when less than an hour is left.
- **Last switch:** a line under the totals shows which tanks you last switched between, how long ago, and the fuel used at the time.
- **More menu (•••):** **Reset Used** clears the used total, and **All Tanks Full** fills every tank.
- **iPhone Duo:** the title and the ••• menu sit in the system's side bar instead of a row at the top of the screen.
- **Setting tank levels:** long-press a tank to set its level. Drag the slider, type gallons, or type a FuelHawk dipstick reading; the other values follow, using that tank's calibration curve. The same sheet has **Empty**, **Full** and **All Tanks Full** buttons.
- **Saved between launches:** tank levels and switch history are kept on the device.

## Tank configuration

| Tank | Capacity | Max FuelHawk reading |
|------|----------|----------------------|
| LM, RM (main) | 25 gal | 13.5 |
| LT, RT (tip) | 17 gal | 13.0 |

### FuelHawk to gallons

The app converts a FuelHawk reading `r` to gallons `g` with a quadratic fit for each tank type:

| Tank | Formula | Endpoints |
|------|---------|-----------|
| Main (LM, RM) | g = −0.0838 r² + 2.95 r + 0.356 | r = 0 → 0 gal, r = 13.5 → 25 gal |
| Tip (LT, RT) | g = −0.013 r² + 1.49 r − 0.0792 | r = 0 → 0 gal, r = 13.0 → 17 gal |

At the endpoints the app returns exactly empty or exactly full rather than the formula's value. The formula alone gives about 24.9 gal for a full main tank and about 17.1 gal for a full tip tank.

Capacities, FuelHawk calibration curves and the burn rate are hard-coded in `Fuel Tracker/Tank.swift` and `Fuel Tracker/FuelViewModel.swift`. Change them there to match your aircraft.

## Project layout

```
Fuel Tracker/
  Fuel_TrackerApp.swift   App entry point
  ContentView.swift       Main screen: endurance, tank rings, totals
  SwitchTankSheet.swift   Tap sheet for switching tanks
  TankEditor.swift        Long-press sheet for setting a tank's level
  FuelViewModel.swift     Fuel state, endurance math, persistence
  Tank.swift              Tank models and FuelHawk calibration curves
Fuel TrackerTests/        Unit tests
Fuel TrackerUITests/      UI tests
```

## Building

You need Xcode (for the iOS SDK) and iOS or iPadOS 18.5 or later on the device. You don't have to open Xcode: everything below runs from the command line.

The first time, sign in with your Apple ID under Xcode → Settings → Accounts so the app can be signed for your devices.

```sh
make deploy iphone   # Build, install and launch on the connected iPhone
make deploy ipad     # Same, on the connected iPad
make build           # Only build the signed app
make test            # Run the tests in the simulator
make devices         # List connected devices
make clean           # Delete build output
```

A device counts if it's plugged in or paired over the network. With plain `make deploy`, it uses an iPhone, or an iPad if there's no iPhone. To pick one device out of several of the same kind, pass its identifier from `make devices`:

```sh
make deploy DEVICE=00008160-00021CEC34A00036
```

`make test` runs on an iPhone 16 simulator. Change it with `SIMULATOR="iPhone 17"`.

If you sign with a free Apple ID, the app stops opening after 7 days. Run `make deploy` again to reinstall it.

## Disclaimer

This app is a convenience for keeping track of fuel. It doesn't replace your aircraft's fuel gauges, a proper preflight fuel check or your own fuel planning.
