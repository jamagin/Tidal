# TidalCycles log of changes

## 1.0.12 - 🐝⌛️🦋

* Fix ESPGrid support - @dktr0
* Add 'snowball' function - @XiNNiW

## 1.0.11 - Cros Bríde

2019-04-17  Alex McLean  <alex@slab.org>
	* Add `bite` function for slicing patterns (rather than samples)
	* Tweak tidal.el to attempt to infer location of default BootTidal.hs
	* Skip time (forward or backward) if the reference clock jumps suddenly
	* Fix `fit` - @bgold-cosmos
	* Remove 'asap'
	* Add cB for boolean control input
	* `pickF` for choosing between functions with a pattern of integers
	* `select` for choosing between list of patterns with a floating point pattern
	* `squeeze` for choosing between list of patterns with a pattern of integers, where patterns are squeezed into the integer event duration
	* `splice` for choosing between slices of a pattern, where the slices are squeezed into event duration
	* Ord and Eq instances for value type @bgold-cosmos
	* `trigger` - support for resetting envelopes on evaluation
	* Support for rational event values
	* Tweak how `*>` and `<*` deal with analog patterns
	* Caribiner link bridge support

## 1.0.10 - This machine also kills fascists
* Add exports to Sound.Tidal.Scales for `getScale` and `scaleTable`

## 1.0.9 - This machine kills fascists
* sec and msec functions for converting from seconds to cycles (for stut etc) @yaxu
* template haskell upper bounds @yaxu
* fix for multi-laptop sync/tempo sharing @yaxu
* fix toScale so it doesn't break on empty lists @bgold-cosmos
* `deconstruct` function for displaying patterns stepwise @yaxu
* `djf` control ready for new superdirt dj filter @yaxu
* `getScale` for handrolling/adding scales to `scale` function	* Add `djf` control for upcoming superdirt dj filter @yaxu

## 1.0.8 (trying to get back to doing these, 
## see also https://tidalcycles.org/index.php/Changes_in_Tidal_1.0.x 
## for earlier stuff)

* Add 'to', 'toArg' and 'from' controls for new superdirt routing experiments - @telephon
* Fixes for squeezeJoin (nee unwrap') - @bgold-cosmos
* Simplify `cycleChoose`, it is now properly discrete (one event per cycle) - @yaxu
* The return of `<>`, `infix alias for overlay` - @yaxu
* Fix for `wedge` to allow 0 and 1 as first parameter  - @XiNNiW
* Support for new spectral fx - @madskjeldgaard
* Fix for _euclidInv - @dktr0
* `chordList` for listing chords - @XiNNiW
* new function `soak` - @XiNNiW
* tempo fixes - @bgold-cosmos
* miniTidal developments - @dktr0
* potentially more efficient euclidean patternings - @dktr0
* unit tests for euclid - @yaxu
* fix for `sometimesBy` - @yaxu

## 0.9.10 (and earlier missing versions from this log)

* arpg, a function to arpeggiate
* within', an alternate within with a different approach to time, following discussion here https://github.com/tidalcycles/Tidal/issues/313
* sine et al are now generalised so can be used as double or rational patterns
* New Sound.Tidal.Simple module with a range of simple transformations (faster, slower, higher, lower, mute, etc)
* slice upgraded to take a pattern of slice indexes
* espgrid support
* lindenmayerI
* sew function, for binary switching between two patterns
* somecycles alias for someCycles
* ply function, for repeating each event in a pattern a given number
  of times within their original timespan
* patternify juxBy, e, e', einv, efull, eoff

## 0.9.7

### Enhancements

* The `note` pattern parameter is no longer an alias for `midinote`,
  but an independent parameter for supercollider to handle (in a manner
  similar to `up`)
  
## 0.9.6

### Enhancements

* Added `chord` for chord patterns and `scaleP` for scale patterns
* The `n` pattern parameter is now floating point

## 0.9.5

### Enhancements

* Added `hurry` which both speeds up the sound and the pattern by the given amount.
* Added `stripe` which repeats a pattern a given number of times per
  cycle, with random but contiguous durations.
* Added continuous function `cosine`
* Turned more pattern transformation parameters into patterns - spread', striateX, every', inside, outside, swing
* Added experimental datatype for Xenakis sieves
* Correctly parse negative rationals
* Added `breakUp` that finds events that share the same timespan, and spreads them out during that timespan, so for example (breakUp "[bd,sn]") gets turned into the "bd sn"
* Added `fill` which 'fills in' gaps in one pattern with events from another. 

## 0.9.4

### Fixes

* Swapped `-` for `..` in ranges as quick fix for issue with parsing negative numbers
* Removed overloaded list thingie for now, unsure whether it's worth the dependency

## 0.9.3

### Enhancements

* The sequence parser can now expand ranges, e.g. `"0-3 4-2"` is
  equivalent to `"[0 1 2 3] [4 3 2]"`
* Sequences can now be described using list syntax, for example `sound ["bd", "sn"]` is equivalent to `sound "bd sn"`. They *aren't* lists though, so you can't for example do `sound (["bd", "sn"] ++ ["arpy", "cp"])` -- but can do `sound (append ["bd", "sn"]  ["arpy", "cp"])`
* New function `linger`, e.g. `linger (1/4)` will only play the first quarter of the given pattern, four times to fill the cycle. 
* `discretise` now takes time value as its first parameter, not a pattern of time, which was causing problems and needs some careful thought.
* a `rel` alias for the `release` parameter, to match the `att` alias for `attack`
* `_fast` alias for `_density`
* The start of automatic testing for a holy bug-free future

### Fixes

* Fixed bug that was causing events to double up or get lost,
  e.g. where `rev` was combined with certain other functions.
