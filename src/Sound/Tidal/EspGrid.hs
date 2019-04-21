{-# LANGUAGE ScopedTypeVariables #-}

module Sound.Tidal.EspGrid (tidalEspGridLink,cpsEsp) where

import Control.Concurrent.MVar
import Control.Concurrent (forkIO,threadDelay)
import Control.Monad (forever)
import Control.Exception
import Sound.OSC.FD
import Sound.Tidal.Tempo

parseEspTempo :: [Datum] -> Maybe (Tempo -> Tempo)
parseEspTempo d = do
  on :: Integer <- datum_integral (d!!0)
  bpm <- datum_floating (d!!1)
  t1 :: Integer <- datum_integral (d!!2)
  t2 <- datum_integral (d!!3)
  n :: Integer <- datum_integral (d!!4)
  let nanos = (t1*1000000000) + t2
  return $ \t -> t {
    atTime = ut_to_ntpr $ realToFrac nanos / 1000000000,
    atCycle = fromIntegral n,
    cps = bpm/60,
    paused = on == 0
    }

changeTempo :: MVar Tempo -> Packet -> IO ()
changeTempo t (Packet_Message msg) =
  case parseEspTempo (messageDatum msg) of
    Just f -> modifyMVarMasked_ t $ \t0 -> return (f t0)
    Nothing -> putStrLn "Warning: Unable to parse message from EspGrid as Tempo"
changeTempo _ _ = putStrLn "Serious error: Can only process Packet_Message"

tidalEspGridLink :: MVar Tempo -> IO ()
tidalEspGridLink t = do
  socket <- openUDP "127.0.0.1" 5510
  _ <- forkIO $ forever $ do
    (do
      sendMessage socket $ Message "/esp/tempo/q" []
      response <- waitAddress socket "/esp/tempo/r"
      Sound.Tidal.EspGrid.changeTempo t response
      threadDelay 200000)
      `catch` (\e -> putStrLn $ "exception caught in tidalEspGridLink: " ++ show (e :: SomeException))
  return ()

cpsEsp :: Real t => t -> IO ()
cpsEsp t = do
  socket <- openUDP "127.0.0.1" 5510
  sendMessage socket $ Message "/esp/beat/tempo" [float (t*60)]
