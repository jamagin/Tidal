{-# LANGUAGE OverloadedStrings #-}

module Sound.Tidal.ParseTest where

import TestUtils
import Test.Microspec

import Prelude hiding ((<*), (*>))

import Sound.Tidal.Core
import Sound.Tidal.Pattern
import Sound.Tidal.UI (_degradeBy)

run :: Microspec ()
run =
  describe "Sound.Tidal.Parse" $ do
    describe "parseBP_E" $ do
      it "can parse strings" $ do
        compareP (Arc 0 12)
          ("a b c" :: Pattern String)
          (fastCat ["a", "b", "c"])
      it "can parse ints" $ do
        compareP (Arc 0 2)
          ("0 1 2 3 4 5 6 7 8 0 10 20 30 40 50" :: Pattern Int)
          (fastCat $ map (pure . read) $ words "0 1 2 3 4 5 6 7 8 0 10 20 30 40 50")
      it "can alternate with <>" $ do
        compareP (Arc 0 2)
          ("a <b c>" :: Pattern String)
          (cat [fastCat ["a", "b"], fastCat ["a", "c"]])
      it "can slow with /" $ do
        compareP (Arc 0 2)
          ("a/2" :: Pattern String)
          (slow 2 $ "a")
      it "can speed up with *" $ do
        compareP (Arc 0 2)
          ("a*8" :: Pattern String)
          (fast 8 "a")
      it "can elongate with _" $ do
        compareP (Arc 0 2)
          ("a _ _ b _" :: Pattern String)
          (timeCat [(3,"a"), (2,"b")])
      it "can replicate with !" $ do
        compareP (Arc 0 2)
          ("a! b" :: Pattern String)
          (fastCat ["a", "a", "b"])
      it "can replicate with ! inside {}" $ do
        compareP (Arc 0 2)
          ("{a a}%2" :: Pattern String)
          ("{a !}%2" :: Pattern String)
      it "can replicate with ! and number" $ do
        compareP (Arc 0 2)
          ("a!3 b" :: Pattern String)
          (fastCat ["a", "a", "a", "b"])
      it "can degrade with ?" $ do
        compareP (Arc 0 1)
          ("a?" :: Pattern String)
          (degradeByDefault "a")
      it "can degrade with ? and number" $ do
        compareP (Arc 0 1)
          ("a?0.2" :: Pattern String)
          (_degradeBy 0.2 "a")
      it "can degrade with ? for double patterns" $ do
        compareP (Arc 0 1)
          ("0.4 0.5? 0.6" :: Pattern Double)
          (fastcat[0.4, degradeByDefault 0.5, 0.6])
      it "can stretch with @" $ do
        comparePD (Arc 0 1)
          ("a@2 b" :: Pattern String)
          (timeCat [(2, "a"),(1,"b")])
      it "can do polymeter with {}" $ do
        compareP (Arc 0 2)
          ("{a b, c d e}" :: Pattern String)
          (stack [fastcat [pure "a", pure "b"], slow 1.5 $ fastcat [pure "c", pure "d", pure "e"]])
      it "can parse a chord" $ do
        compareP (Arc 0 2)
          ("'major" :: Pattern Int)
          ("[0,4,7]")
      it "can parse two chords" $ do
        compareP (Arc 0 2)
          ("'major 'minor" :: Pattern Int)
          ("[0,4,7] [0,3,7]")
      it "can parse c chords" $ do
        compareP (Arc 0 2)
          ("'major 'minor 'dim7" :: Pattern Int)
          ("c'major c'minor c'dim7")
      it "can parse various chords" $ do
        compareP (Arc 0 2)
          ("c'major e'minor f'dim7" :: Pattern Int)
          ("c e f" + "'major 'minor 'dim7")
      it "doesn't crash on zeroes (1)" $ do
        compareP (Arc 0 2)
          ("cp/0" :: Pattern String)
          (silence)
      it "doesn't crash on zeroes (2)" $ do
        compareP (Arc 0 2)
          ("cp(5,0)" :: Pattern String)
          (silence)
      it "doesn't crash on zeroes (3)" $ do
        compareP (Arc 0 2)
          ("cp(5,c)" :: Pattern String)
          (silence)
    where degradeByDefault = _degradeBy 0.5  
