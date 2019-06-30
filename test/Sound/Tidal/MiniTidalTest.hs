{-# LANGUAGE OverloadedStrings #-}

module Sound.Tidal.MiniTidalTest where

import Test.Microspec
import Sound.Tidal.MiniTidal
import Sound.Tidal.Context as Tidal
import Data.Either
import Text.ParserCombinators.Parsec (ParseError)
import qualified Data.Map.Strict as Map

parsesTo :: String -> ControlPattern -> Property
parsesTo str p = x `shouldBe` y
  where x = query <$> miniTidal str <*> Right (State (Arc 0 16) Map.empty)
        y = Right $ query p $ State (Arc 0 16) Map.empty

causesParseError :: String -> Property
causesParseError str = isLeft (miniTidal str :: Either String ControlPattern) `shouldBe` True

-- for convenience when testing manually with GHCI
main :: IO ()
main = microspec Sound.Tidal.MiniTidalTest.run

run :: Microspec ()
run =
  describe "miniTidal" $ do

    it "parses the empty string as silence" $
      "" `parsesTo` silence

    it "parses a string containing only spaces as silence" $
      "    " `parsesTo` silence

    it "parses the identifier silence as silence" $
      "silence" `parsesTo` silence

    it "parses a very simple single 's' pattern" $
      "s \"bd cp\"" `parsesTo` s "bd cp"

    it "parses a very simple single 'sound' pattern" $
      "sound \"bd cp\"" `parsesTo` sound "bd cp"

    it "parses a single 's' pattern that uses angle brackets" $
      "s \"<bd cp>\"" `parsesTo` s "<bd cp>"

    it "parses a single 's' pattern that uses square brackets" $
      "s \"[bd sn] cp\"" `parsesTo` s "[bd sn] cp"

    it "parses a single 's' pattern that uses square brackets and *" $
      "s \"[bd sn]*2 cp\"" `parsesTo` s "[bd sn]*2 cp"

    it "parses a single 's' pattern that uses Bjorklund rhythms" $
      "s \"sn(5,16)\"" `parsesTo` s "sn(5,16)"

    it "parses a literal int as a double pattern" $
      "pan 0" `parsesTo` (pan 0)

    it "parses a literal double as a double pattern" $
      "pan 1.0" `parsesTo` (pan 1.0)

    it "parses a negative literal double as a double pattern" $
      "pan (-1.0)" `parsesTo` (pan (-1.0))

    it "parses two merged patterns" $
      "s \"bd cp\" # pan \"0 1\"" `parsesTo` (s "bd cp" # pan "0 1")

    it "parses three merged patterns" $
      "s \"bd cp\" # pan \"0 1\" # gain \"0.5 0.7\"" `parsesTo`
        (s "bd cp" # pan "0 1" # gain "0.5 0.7")

    it "parses three merged patterns, everything in brackets" $
      "(s \"bd cp\" # pan \"0 1\" # gain \"0.5 0.7\")" `parsesTo`
        ((s "bd cp" # pan "0 1" # gain "0.5 0.7"))

    it "parses three merged patterns, everything in muliple layers of brackets" $
      "(((s \"bd cp\" # pan \"0 1\" # gain \"0.5 0.7\")))" `parsesTo`
        ((((s "bd cp" # pan "0 1" # gain "0.5 0.7"))))

    it "parses three merged patterns with right associative brackets" $
      "s \"bd cp\" # (pan \"0 1\" # gain \"0.5 0.7\")" `parsesTo`
        (s "bd cp" # (pan "0 1" # gain "0.5 0.7"))

    it "parses three merged patterns with left associative brackets" $
      "(s \"bd cp\" # pan \"0 1\") # gain \"0.5 0.7\"" `parsesTo`
        ((s "bd cp" # pan "0 1") # gain "0.5 0.7")

    it "parses simple patterns in brackets applied to ParamPattern functions" $
      "s (\"bd cp\")" `parsesTo` (s ("bd cp"))

    it "parses simple patterns applied to ParamPattern functions with $" $
      "s $ \"bd cp\"" `parsesTo` (s $ "bd cp")

    it "parses addition of simple patterns" $
      "n (\"0 1\" + \"2 3\")" `parsesTo` (n ("0 1" + "2 3"))

    it "parses multiplication of simple patterns as a merged parampattern" $
      "s \"arpy*8\" # up (\"3\" * \"2\")" `parsesTo` (s "arpy*8" # up ("3" * "2"))

    it "parses pan patterns" $
      "pan \"0 0.25 0.5 0.75 1\"" `parsesTo` (pan "0 0.25 0.5 0.75 1")

    it "parses note patterns" $
      "note \"0 0.25 0.5 0.75 1\"" `parsesTo` (note "0 0.25 0.5 0.75 1")

    it "parses sine oscillators" $
      "pan sine" `parsesTo` (pan sine)

    it "parses sine oscillators used in pan patterns" $
      "s \"arpy*8\" # pan sine" `parsesTo` (s "arpy*8" # pan sine)

    it "parses striate transformations of s patterns" $
      "striate 8 $ s \"arpy*8\"" `parsesTo` (striate 8 $ s "arpy*8")

    it "parses fast transformations of parampatterns" $
      "fast 2 $ s \"bd cp\"" `parsesTo` (fast 2 $ s "bd cp")

    it "parses fast transformations of parampatterns when in brackets" $
      "(fast 2) $ s \"bd cp\"" `parsesTo` ((fast 2) $ s "bd cp")

    it "parses rev transformations of parampatterns" $
      "rev $ s \"bd cp\"" `parsesTo` (rev $ s "bd cp")

    it "parses rev transformations of parampatterns when in brackets" $
      "(rev) $ s \"bd cp\"" `parsesTo` ((rev) $ s "bd cp")

    it "parses jux transformations with transformations in brackets" $
        "jux (rev) $ s \"arpy*8\" # up \"0 2 3 5 3 5 7 8\"" `parsesTo`
         (jux (rev) $ s "arpy*8" # up "0 2 3 5 3 5 7 8")

    it "parses jux transformations with transformations not in brackets" $
        "jux rev $ s \"arpy*8\" # up \"0 2 3 5 3 5 7 8\"" `parsesTo`
         (jux rev $ s "arpy*8" # up "0 2 3 5 3 5 7 8")

    it "doesn't parse when a transformation requiring an argument is provided without parens or $ to jux" $
      causesParseError "jux fast 2 $ s \"bd*4 cp\""

    it "parses multiple fast transformations of parampatterns" $
      "fast 2 $ fast 2 $ s \"bd cp\"" `parsesTo` (fast 2 $ fast 2 $ s "bd cp")

    it "parses an 'every' transformation applied to a simple s pattern" $
      "every 2 (fast 2) (s \"bd cp\")" `parsesTo` (every 2 (fast 2) (s "bd cp"))

    it "parses a transformed pattern merged with a pattern constructed from parampatterning an arithmetic expression on patterns" $
      "(every 2 (fast 2) $ s \"arpy*8\") # up (\"[0 4 7 2,16 12 12 16]\" - \"<0 3 5 7>\")" `parsesTo` ((every 2 (fast 2) $ s "arpy*8") # up ("[0 4 7 2,16 12 12 16]" - "<0 3 5 7>"))

    it "parses a fast transformation applied to a simple (ie. non-param) pattern" $
      "up (fast 2 \"<0 2 3 5>\")" `parsesTo`
        (up (fast 2 "<0 2 3 5>"))

    it "parses a partially-applied pattern transformation spread over patterns" $
      "spread (fast) [2,1,1.5] $ s \"bd sn cp sn\"" `parsesTo`
        (spread (fast) [2,1,1.5] $ s "bd sn cp sn")

    it "parses a binary Num function spread over a simple Num pattern" $
      "n (spread (+) [2,3,4] \"1 2 3\")" `parsesTo`
        (n (spread (+) [2,3,4] "1 2 3"))

    it "parses an $ application spread over partially applied transformations of a non-Control Pattern" $
      "n (spread ($) [density 2, rev, slow 2] $ \"1 2 3 4\")" `parsesTo`
        (n (spread ($) [density 2, rev, slow 2] $ "1 2 3 4"))

    it "parses an $ application spread over transformations of a control pattern" $
      "spread ($) [fast 2,fast 4] $ s \"bd cp\"" `parsesTo`
        (spread ($) [fast 2,fast 4] $ s "bd cp")

    it "parses an $ application spread over partially applied transformations of a Control Pattern" $
      "spread ($) [density 2, rev, slow 2, striate 3] $ sound \"[bd*2 [~ bd]] [sn future]*2 cp jvbass*4\"" `parsesTo`
        (spread ($) [density 2, rev, slow 2, striate 3] $ sound "[bd*2 [~ bd]] [sn future]*2 cp jvbass*4")

    it "parses an off transformation" $
      "off 0.125 (fast 2) $ s \"bd sn cp glitch\"" `parsesTo`
        (off 0.125 (fast 2) $ s "bd sn cp glitch")

    it "parses a pattern rotation operator (1)" $
      "0.25 <~ (s \"bd sn cp glitch\")" `parsesTo`
        (0.25 <~ (s "bd sn cp glitch"))

    it "parses a pattern rotation operator (2)" $
      "0.25 <~ s \"bd sn cp glitch\"" `parsesTo`
        (0.25 <~ s "bd sn cp glitch")

    it "parses a pattern rotation operator (3)" $
      "\"0.25 0.125 0 0.5\" <~ s \"bd sn cp glitch\"" `parsesTo`
        ("0.25 0.125 0 0.5" <~ s "bd sn cp glitch")

    it "parses a pattern rotation operator (3) applied to a transformation with $" $
      "fast 4 $ \"<0 [0.125,0.25]>\" <~ s \"bd cp sn glitch:2\"" `parsesTo`
        (fast 4 $ "<0 [0.125,0.25]>" <~ s "bd cp sn glitch:2")
