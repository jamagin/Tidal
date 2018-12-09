{-# LANGUAGE DeriveDataTypeable, TypeSynonymInstances, FlexibleInstances #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE DeriveFunctor #-}
{-# OPTIONS_GHC -fno-warn-orphans #-}

module Sound.Tidal.Pattern where

import           Prelude hiding ((<*), (*>))

import           Control.Applicative (liftA2)
import           Data.Bifunctor (Bifunctor(..))
import           Data.Data (Data) -- toConstr
import           Data.List (delete, findIndex, sort, intercalate)
import qualified Data.Map.Strict as Map
import           Data.Maybe (isJust, fromJust, catMaybes, fromMaybe)
import           Data.Ratio (numerator, denominator)
import           Data.Typeable (Typeable)

import           Sound.Tidal.Utils

------------------------------------------------------------------------
-- * Types

-- | Time is rational
type Time = Rational

-- | The 'sam' (start of cycle) for the given time value
sam :: Time -> Time
sam = fromIntegral . (floor :: Time -> Int)

-- | Turns a number into a (rational) time value. An alias for 'toRational'.
toTime :: Real a => a -> Rational
toTime = toRational

-- | The end point of the current cycle (and starting point of the next cycle)
nextSam :: Time -> Time
nextSam = (1+) . sam

-- | The position of a time value relative to the start of its cycle.
cyclePos :: Time -> Time
cyclePos t = t - sam t

-- | A time arc (start and finish)
data ArcF a = Arc { start :: a, finish :: a } deriving (Eq, Ord, Functor)

type Arc = ArcF Time

instance {-# OVERLAPPING #-} Show Arc where
  show (Arc s e) = prettyRat s ++ ">" ++ prettyRat e

instance Num a => Num (ArcF a) where
  negate      = fmap negate
  (+)         = liftA2 (+)
  (*)         = liftA2 (*)
  fromInteger = pure . fromInteger
  abs         = fmap abs
  signum      = fmap signum

instance (Fractional a) => Fractional (ArcF a) where
  recip        = fmap recip
  fromRational = pure . fromRational

sect :: Arc -> Arc -> Arc
sect (Arc s e) (Arc s' e') = Arc (max s s') (min e e')

-- | convex hull union
hull :: Arc -> Arc -> Arc
hull (Arc s e) (Arc s' e') = Arc (min s s') (max e e')

-- | @subArc i j@ is the timespan that is the intersection of @i@ and @j@.
-- intersection
-- The definition is a bit fiddly as results might be zero-width, but
-- not at the end of an non-zero-width arc - e.g. (0,1) and (1,2) do
-- not intersect, but (1,1) (1,1) does.
subArc :: Arc -> Arc -> Maybe Arc
subArc a@(Arc s e) b@(Arc s' e')
  | and [s'' == e'', s'' == e, s < e] = Nothing
  | and [s'' == e'', s'' == e', s' < e'] = Nothing
  | s'' <= e'' = Just (Arc s'' e'')
  | otherwise = Nothing
  where (Arc s'' e'') = sect a b

instance Applicative ArcF where
  pure t = Arc t t
  (<*>) (Arc sf ef) (Arc sx ex) = Arc (sf sx) (ef ex)

-- | The arc of the whole cycle that the given time value falls within
timeToCycleArc :: Time -> Arc
timeToCycleArc t = (Arc (sam t) ((sam t) + 1))

-- | A list of cycle numbers which are included in the given arc
cyclesInArc :: Integral a => Arc -> [a]
cyclesInArc (Arc s e)
  | s > e = []
  | s == e = [floor s]
  | otherwise = [floor s .. (ceiling e)-1]

-- | A list of arcs of the whole cycles which are included in the given arc
cycleArcsInArc :: Arc -> [Arc]
cycleArcsInArc = map (timeToCycleArc . (toTime :: Int -> Time)) . cyclesInArc

-- | Splits the given 'Arc' into a list of 'Arc's, at cycle boundaries.
arcCycles :: Arc -> [Arc]
arcCycles (Arc s e) | s >= e = []
                | sam s == sam e = [Arc s e]
                | otherwise = (Arc s (nextSam s)) : (arcCycles (Arc (nextSam s) e))

-- | Like arcCycles, but returns zero-width arcs
arcCyclesZW :: Arc -> [Arc]
arcCyclesZW (Arc s e) | s == e = [Arc s e]
                  | otherwise = arcCycles (Arc s e)

-- | Similar to 'fmap' but time is relative to the cycle (i.e. the
-- sam of the start of the arc)
mapCycle :: (Time -> Time) -> Arc -> Arc
mapCycle f (Arc s e) = Arc (sam' + (f $ s - sam')) (sam' + (f $ e - sam'))
         where sam' = sam s

-- | @isIn a t@ is @True@ if @t@ is inside
-- the arc represented by @a@.
isIn :: Arc -> Time -> Bool
isIn (Arc s e) t = t >= s && t < e

-- | An event is a value that's active during a timespan
-- The part should be equal to or fit inside the
-- whole
data EventF a b = Event
  { whole :: a
  , part :: a
  , event :: b
  } deriving (Eq, Ord, Functor)

type Event a = EventF (ArcF Time) a

instance Bifunctor EventF where
  bimap f g (Event w p e) = (Event (f w) (f p) (g e))

instance {-# OVERLAPPING #-} Show a => Show (Event a) where
  show (Event (Arc ws we) a@(Arc ps pe) e) =
    h ++ "(" ++ show a ++ ")" ++ t ++ "|" ++ show e
    where h | ws == ps = ""
            | otherwise = prettyRat ws ++ "-"
          t | we == pe = ""
            | otherwise = "-" ++ prettyRat we

-- | `True` if an `Event`'s starts is within given `Arc`
onsetIn :: Arc -> Event a -> Bool
onsetIn a e = isIn a (wholeStart e)

-- | Compares two lists of events, attempting to combine fragmented events in the process
-- for a 'truer' compare
compareDefrag :: (Eq a, Ord a) => [Event a] -> [Event a] -> Bool
compareDefrag as bs = (sort $ defragParts as) == (sort $ defragParts bs)

-- | Returns a list of events, with any adjacent parts of the same whole combined
defragParts :: Eq a => [Event a] -> [Event a]
defragParts [] = []
defragParts (e:[]) = (e:[])
defragParts (e:es) | isJust i = defraged:(defragParts (delete e' es))
                   | otherwise = e:(defragParts es)
  where i = findIndex (isAdjacent e) es
        e' = es !! (fromJust i)
        defraged = Event (whole e) u (event e)
        u = hull (part e) (part e')

-- | Returns 'True' if the two given events are adjacent parts of the same whole
isAdjacent :: Eq a => Event a -> Event a -> Bool
isAdjacent e e' = (whole e == whole e')
                  && (event e == event e')
                  && (((finish $ part e) == (start $ part e'))
                      ||
                      ((finish $ part e') == (start $ part e))
                     )

-- | Get the onset of an event's 'whole'
wholeStart :: Event a -> Time
wholeStart = start . whole

-- | Get the offset of an event's 'whole'
wholeFinish :: Event a -> Time
wholeFinish = finish . whole

-- | Get the onset of an event's 'whole'
eventPartStart :: Event a -> Time
eventPartStart = start . part

-- | Get the offset of an event's 'part'
eventPartFinish :: Event a -> Time
eventPartFinish = finish . part

-- | Get the timespan of an event's 'part'
eventPart :: Event a -> Arc
eventPart = part

eventValue :: Event a -> a
eventValue = event

eventHasOnset :: Event a -> Bool
eventHasOnset e = (start $ whole e) == (start $ part e)

toEvent :: (((Time, Time), (Time, Time)), a) -> Event a
toEvent (((ws, we), (ps, pe)), v) = Event (Arc ws we) (Arc ps pe) v

-- | an Arc and some named control values
data State = State {arc :: Arc,
                    controls :: ControlMap
                   }

-- | A function that represents events taking place over time
type Query a = (State -> [Event a])

-- | Also known as Continuous vs Discrete/Amorphous vs Pulsating etc.
data Nature = Analog | Digital
            deriving Eq

-- | A datatype that's basically a query, plus a hint about whether its events
-- are Analogue or Digital by nature
data Pattern a = Pattern {nature :: Nature, query :: Query a}

data Value = VS { svalue :: String }
           | VF { fvalue :: Double }
           | VI { ivalue :: Int }
           deriving (Eq,Ord,Typeable,Data)

type ControlMap = Map.Map String Value
type ControlPattern = Pattern ControlMap

------------------------------------------------------------------------
-- * Instances

instance Functor Pattern where
  -- | apply a function to all the values in a pattern
  fmap f p = p {query = (fmap (fmap f)) . query p}

instance Applicative Pattern where
  -- | Repeat the given value once per cycle, forever
  pure v = Pattern Digital $ \(State a _) ->
    map (\a' -> Event a' (sect a a') v) $ cycleArcsInArc a

  (<*>) pf@(Pattern Digital _) px@(Pattern Digital _) = Pattern Digital q
    where q st = catMaybes $ concat $ map match $ query pf st
            where
              match (Event fWhole fPart f) =
                map
                (\(Event xWhole xPart x) ->
                  do whole' <- subArc xWhole fWhole
                     part' <- subArc fPart xPart
                     return (Event whole' part' (f x))
                )
                (query px $ st {arc = fPart})
  (<*>) pf@(Pattern Digital _) px@(Pattern Analog _) = Pattern Digital q
    where q st = concatMap match $ query pf st
            where
              match (Event fWhole fPart f) =
                map
                (\e -> (Event fWhole fPart (f (event e))))
                (query px $ st {arc = pure (start fPart)})

  (<*>) pf@(Pattern Analog _) px@(Pattern Digital _) = Pattern Digital q
    where q st = concatMap match $ query px st
            where
              match (Event xWhole xPart x) =
                map
                (\e -> (Event xWhole xPart ((event e) x)))
                (query pf st {arc = (pure (start xPart))})
                
  (<*>) pf px = Pattern Analog q
    where q st = concatMap match $ query pf st
            where
              match ef =
                map
                (\ex -> (Event (arc st) (arc st) ((event ef) (event ex))))
                (query px st)

-- | Like <*>, but the structure only comes from the left
(<*) :: Pattern (a -> b) -> Pattern a -> Pattern b
(<*) pf@(Pattern Digital _) px = Pattern Digital q
  where q st = concatMap match $ query pf st
         where
            match (Event fWhole fPart f) =
              map
              (\e -> (Event fWhole fPart (f (event e)))) $
              query px $ st {arc = xQuery fWhole}
            xQuery (Arc s _) = pure s -- for discrete events, match with the onset

pf <* px = Pattern Analog q
  where q st = concatMap match $ query pf st
          where
            match (Event fWhole fPart f) =
              map
              (\e -> (Event fWhole fPart (f (event e)))) $
              query px st -- for continuous events, use the original query

-- | Like <*>, but the structure only comes from the right
(*>) :: Pattern (a -> b) -> Pattern a -> Pattern b
(*>) pf px@(Pattern Digital _) = Pattern Digital q
  where q st = concatMap match $ query px st
         where
            match (Event xWhole xPart x) =
              map
              (\e -> (Event xWhole xPart ((event e) x))) $
              query pf $ fQuery xWhole
            fQuery (Arc s _) = st {arc = pure s} -- for discrete events, match with the onset

pf *> px = Pattern Analog q
  where q st = concatMap match $ query px st
          where
            match (Event xWhole xPart x) =
              map
              (\e -> (Event xWhole xPart ((event e) x))) $
              query pf st -- for continuous events, use the original query

infixl 4 <*, *>

instance Monad Pattern where
  return = pure
  p >>= f = unwrap (f <$> p)

-- | Turns a pattern of patterns into a single pattern.
-- (this is actually 'join')
--
-- 1/ For query 'arc', get the events from the outer pattern @pp@
-- 2/ Query the inner pattern using the 'part' of the outer
-- 3/ For each inner event, set the whole and part to be the intersection
--    of the outer whole and part, respectively
-- 4/ Concatenate all the events together (discarding wholes/parts that didn't intersect)
--
-- TODO - what if a continuous pattern contains a discrete one, or vice-versa?

unwrap :: Pattern (Pattern a) -> Pattern a
unwrap pp = pp {query = q}
  where q st = concatMap (\(Event whole part p) -> catMaybes $ map (munge whole part) $ query p st {arc = part}) (query pp st)
        munge oWhole oPart (Event iWhole iPart v) =
          do
            w <- subArc oWhole iWhole
            p <- subArc oPart iPart
            return (Event w p v)

-- | Turns a pattern of patterns into a single pattern. Like @unwrap@,
-- but structure only comes from the inner pattern.
innerJoin :: Pattern (Pattern a) -> Pattern a
innerJoin pp = pp {query = q}
  where q st = concatMap (\(Event _ part p) -> catMaybes $ map munge $ query p st {arc = part}) (query pp st)
          where munge (Event iWhole iPart v) =
                  do 
                    p <- subArc (arc st) iPart
                    p' <- subArc p (arc st)
                    return (Event iWhole p' v)

-- | Turns a pattern of patterns into a single pattern. Like @unwrap@,
-- but structure only comes from the outer pattern.
outerJoin :: Pattern (Pattern a) -> Pattern a
outerJoin pp = pp {query = q}
  where q st = concatMap (\(Event whole part p) -> catMaybes $ map (munge whole part) $ query p st {arc = (pure (start whole))}) (query pp st)
          where munge oWhole oPart (Event _ _ v) =
                  do let w = oWhole
                     p <- subArc (arc st) oPart
                     return (Event w p v)

-- | Like @unwrap@, but cycles of the inner patterns are compressed to fit the
-- timespan of the outer whole (or the original query if it's a continuous pattern?)
-- TODO - what if a continuous pattern contains a discrete one, or vice-versa?
unwrapSqueeze :: Pattern (Pattern a) -> Pattern a
unwrapSqueeze pp = pp {query = q}
  where q st = concatMap (\(Event whole part p) -> catMaybes $ map (munge whole part) $ query (__compress whole p) st {arc = part}) (query pp st)
        munge oWhole oPart (Event iWhole iPart v) =
          do whole' <- subArc oWhole iWhole
             part' <- subArc oPart iPart
             return (Event whole' part' v)

noOv :: String -> a
noOv meth = error $ meth ++ ": not supported for patterns"

class TolerantEq a where
   (~==) :: a -> a -> Bool

instance TolerantEq Value where
         (VS a) ~== (VS b) = a == b
         (VI a) ~== (VI b) = a == b
         (VF a) ~== (VF b) = (abs (a - b)) < 0.000001
         _ ~== _ = False

instance TolerantEq ControlMap where
  a ~== b = (Map.differenceWith (\a' b' -> if a' ~== b' then Nothing else Just a') a b) == Map.empty

instance TolerantEq (Event ControlMap) where
  (Event w p x) ~== (Event w' p' x') = w == w' && p == p' && x ~== x'

instance TolerantEq a => TolerantEq ([a]) where
  as ~== bs = (length as == length bs) && (and $ map (\(a,b) -> a ~== b) $ zip as bs)

instance Eq (Pattern a) where
  (==) = noOv "(==)"

instance Ord a => Ord (Pattern a) where
  min = liftA2 min
  max = liftA2 max
  compare = noOv "compare"
  (<=) = noOv "(<=)"

instance Num a => Num (Pattern a) where
  negate      = fmap negate
  (+)         = liftA2 (+)
  (*)         = liftA2 (*)
  fromInteger = pure . fromInteger
  abs         = fmap abs
  signum      = fmap signum

instance Enum a => Enum (Pattern a) where
  succ           = fmap succ
  pred           = fmap pred
  toEnum         = pure . toEnum
  fromEnum       = noOv "fromEnum"
  enumFrom       = noOv "enumFrom"
  enumFromThen   = noOv "enumFromThen"
  enumFromTo     = noOv "enumFromTo"
  enumFromThenTo = noOv "enumFromThenTo"

instance (Num a, Ord a) => Real (Pattern a) where
  toRational = noOv "toRational"

instance (Integral a) => Integral (Pattern a) where
  quot          = liftA2 quot
  rem           = liftA2 rem
  div           = liftA2 div
  mod           = liftA2 mod
  toInteger     = noOv "toInteger"
  x `quotRem` y = (x `quot` y, x `rem` y)
  x `divMod`  y = (x `div`  y, x `mod` y)

instance (Fractional a) => Fractional (Pattern a) where
  recip        = fmap recip
  fromRational = pure . fromRational

instance (Floating a) => Floating (Pattern a) where
  pi    = pure pi
  sqrt  = fmap sqrt
  exp   = fmap exp
  log   = fmap log
  sin   = fmap sin
  cos   = fmap cos
  asin  = fmap asin
  atan  = fmap atan
  acos  = fmap acos
  sinh  = fmap sinh
  cosh  = fmap cosh
  asinh = fmap asinh
  atanh = fmap atanh
  acosh = fmap acosh

instance (RealFrac a) => RealFrac (Pattern a) where
  properFraction = noOv "properFraction"
  truncate       = noOv "truncate"
  round          = noOv "round"
  ceiling        = noOv "ceiling"
  floor          = noOv "floor"

instance (RealFloat a) => RealFloat (Pattern a) where
  floatRadix     = noOv "floatRadix"
  floatDigits    = noOv "floatDigits"
  floatRange     = noOv "floatRange"
  decodeFloat    = noOv "decodeFloat"
  encodeFloat    = ((.).(.)) pure encodeFloat
  exponent       = noOv "exponent"
  significand    = noOv "significand"
  scaleFloat n   = fmap (scaleFloat n)
  isNaN          = noOv "isNaN"
  isInfinite     = noOv "isInfinite"
  isDenormalized = noOv "isDenormalized"
  isNegativeZero = noOv "isNegativeZero"
  isIEEE         = noOv "isIEEE"
  atan2          = liftA2 atan2

instance Num (ControlMap) where
  negate      = ((applyFIS negate negate id) <$>)
  (+)         = Map.unionWith (fNum2 (+) (+))
  (*)         = Map.unionWith (fNum2 (*) (*))
  fromInteger i = Map.singleton "n" $ VI $ fromInteger i
  signum      = ((applyFIS signum signum id) <$>)
  abs         = ((applyFIS abs abs id) <$>)

instance Fractional ControlMap where
  recip        = fmap (applyFIS recip id id)
  fromRational = Map.singleton "speed" . VF . fromRational

showPattern :: Show a => Arc -> Pattern a -> String
showPattern a p = intercalate "\n" $ map show $ queryArc p a

instance (Show a) => Show (Pattern a) where
  show p = showPattern (Arc 0 1) p

instance Show Value where
  show (VS s) = ('"':s) ++ "\""
  show (VI i) = show i
  show (VF f) = show f ++ "f"

instance {-# OVERLAPPING #-} Show (ControlMap) where
  show m = intercalate ", " $ map (\(name, value) -> name ++ ": " ++ show value) $ Map.toList m

prettyRat :: Rational -> String
prettyRat r | unit == 0 && frac > 0 = showFrac (numerator frac) (denominator frac)
            | otherwise =  show unit ++ showFrac (numerator frac) (denominator frac)
  where unit = floor r :: Int
        frac = (r - (toRational unit))

showFrac :: Integer -> Integer -> String
showFrac 0 _ = ""
showFrac 1 2 = "½"
showFrac 1 3 = "⅓"
showFrac 2 3 = "⅔"
showFrac 1 4 = "¼"
showFrac 3 4 = "¾"
showFrac 1 5 = "⅕"
showFrac 2 5 = "⅖"
showFrac 3 5 = "⅗"
showFrac 4 5 = "⅘"
showFrac 1 6 = "⅙"
showFrac 5 6 = "⅚"
showFrac 1 7 = "⅐"
showFrac 1 8 = "⅛"
showFrac 3 8 = "⅜"
showFrac 5 8 = "⅝"
showFrac 7 8 = "⅞"
showFrac 1 9 = "⅑"
showFrac 1 10 = "⅒"

showFrac n d = fromMaybe plain $ do n' <- up n
                                    d' <- down d
                                    return $ n' ++ d'
  where plain = " " ++ show n ++ "/" ++ show d
        up 1 = Just "¹"
        up 2 = Just "²"
        up 3 = Just "³"
        up 4 = Just "⁴"
        up 5 = Just "⁵"
        up 6 = Just "⁶"
        up 7 = Just "⁷"
        up 8 = Just "⁸"
        up 9 = Just "⁹"
        up 0 = Just "⁰"
        up _ = Nothing
        down 1 = Just "₁"
        down 2 = Just "₂"
        down 3 = Just "₃"
        down 4 = Just "₄"
        down 5 = Just "₅"
        down 6 = Just "₆"
        down 7 = Just "₇"
        down 8 = Just "₈"
        down 9 = Just "₉"
        down 0 = Just "₀"
        down _ = Nothing

------------------------------------------------------------------------
-- * Internal functions

empty :: Pattern a
empty = Pattern {nature = Digital, query = const []}

queryArc :: Pattern a -> Arc -> [Event a]
queryArc p a = query p $ State a Map.empty 

isDigital :: Pattern a -> Bool
isDigital = (== Digital) . nature

isAnalog :: Pattern a -> Bool
isAnalog = not . isDigital

-- | Splits queries that span cycles. For example `query p (0.5, 1.5)` would be
-- turned into two queries, `(0.5,1)` and `(1,1.5)`, and the results
-- combined. Being able to assume queries don't span cycles often
-- makes transformations easier to specify.
splitQueries :: Pattern a -> Pattern a
splitQueries p = p {query = \st -> concatMap (\a -> query p st {arc = a}) $ arcCyclesZW (arc st)}

-- | Apply a function to the arcs/timespans (both whole and parts) of the result
withResultArc :: (Arc -> Arc) -> Pattern a -> Pattern a
withResultArc f p = p {query = map (\(Event w p e) -> Event (f w) (f p) e) . query p}

-- | Apply a function to the time (both start and end of the timespans
-- of both whole and parts) of the result
withResultTime :: (Time -> Time) -> Pattern a -> Pattern a
withResultTime f = withResultArc (\(Arc s e) -> Arc (f s) (f e))

-- | Apply a function to the timespan of the query
withQueryArc :: (Arc -> Arc) -> Pattern a -> Pattern a
withQueryArc f p = p {query = query p . (\(State a m) -> State (f a) m)}

-- | Apply a function to the time (both start and end) of the query
withQueryTime :: (Time -> Time) -> Pattern a -> Pattern a
withQueryTime f = withQueryArc (\(Arc s e) -> Arc (f s) (f e))

-- | @withEvent f p@ returns a new @Pattern@ with each event mapped over
-- function @f@.
withEvent :: (Event a -> Event b) -> Pattern a -> Pattern b
withEvent f p = p {query = map f . query p}

-- | @withEvent f p@ returns a new @Pattern@ with f applied to the resulting list of events for each query
-- function @f@.
withEvents :: ([Event a] -> [Event b]) -> Pattern a -> Pattern b
withEvents f p = p {query = f . query p}

-- | @withPart f p@ returns a new @Pattern@ with function @f@ applied
-- to the part.
withPart :: (Arc -> Arc) -> Pattern a -> Pattern a
withPart f = withEvent (\(Event w p v) -> (Event w (f p) v))

-- | Apply one of three functions to a Value, depending on its type
applyFIS :: (Double -> Double) -> (Int -> Int) -> (String -> String) -> Value -> Value
applyFIS f _ _ (VF f') = VF $ f f'
applyFIS _ f _ (VI i ) = VI $ f i
applyFIS _ _ f (VS s ) = VS $ f s

-- | Apply one of two functions to a Value, depending on its type (int
-- or float; strings are ignored)
fNum2 :: (Int -> Int -> Int) -> (Double -> Double -> Double) -> Value -> Value -> Value
fNum2 fInt _      (VI a) (VI b) = VI $ fInt a b
fNum2 _    fFloat (VF a) (VF b) = VF $ fFloat a b
fNum2 _    fFloat (VI a) (VF b) = VF $ fFloat (fromIntegral a) b
fNum2 _    fFloat (VF a) (VI b) = VF $ fFloat a (fromIntegral b)
fNum2 _    _      x      _      = x

getI :: Value -> Maybe Int
getI (VI i) = Just i
getI _  = Nothing

getF :: Value -> Maybe Double
getF (VF f) = Just f
getF _  = Nothing

getS :: Value -> Maybe String
getS (VS s) = Just s
getS _  = Nothing

__compress :: Arc -> Pattern a -> Pattern a
__compress (Arc s e) p | s > e = empty
                   | s > 1 || e > 1 = empty
                   | s < 0 || e < 0 = empty
                   | otherwise = s `rotR` _fastGap (1/(e-s)) p

__compressTo :: Arc -> Pattern a -> Pattern a
__compressTo (Arc s e) p = __compress (Arc (cyclePos s) (e-(sam s))) p

_fastGap :: Time -> Pattern a -> Pattern a
_fastGap 0 _ = empty
_fastGap r p = splitQueries $ 
  withResultArc (\(Arc s e) -> Arc (sam s + ((s - sam s)/r'))
                             (sam s + ((e - sam s)/r'))
                 ) $ p {query = f}
  where r' = max r 1
        -- zero width queries of the next sam should return zero in this case..
        f st@(State a _) | start a' == nextSam (start a) = []
                         | otherwise = query p st {arc = a'}
          where mungeQuery t = sam t + (min 1 $ r' * cyclePos t)
                a' = (\(Arc s e) -> Arc (mungeQuery s) (mungeQuery e)) a

-- | Shifts a pattern back in time by the given amount, expressed in cycles
rotL :: Time -> Pattern a -> Pattern a
rotL t p = withResultTime (subtract t) $ withQueryTime (+ t) p

-- | Shifts a pattern forward in time by the given amount, expressed in cycles
rotR :: Time -> Pattern a -> Pattern a
rotR t = rotL (0-t)

-- ** Event filters

-- | Remove events from patterns that to not meet the given test
filterValues :: (a -> Bool) -> Pattern a -> Pattern a
filterValues f p = p {query = (filter (f . event)) . query p}

-- | Turns a pattern of 'Maybe' values in to a pattern of values,
-- dropping the events of 'Nothing'.
filterJust :: Pattern (Maybe a) -> Pattern a
filterJust p = fromJust <$> (filterValues (isJust) p)

-- formerly known as playWhen
filterWhen :: (Time -> Bool) -> Pattern a -> Pattern a
filterWhen test p = p {query = filter (test . wholeStart) . query p}

playFor :: Time -> Time -> Pattern a -> Pattern a
playFor s e = filterWhen (\t -> and [t >= s, t < e])

-- ** Temporal parameter helpers

tParam :: (t1 -> t2 -> Pattern a) -> Pattern t1 -> t2 -> Pattern a
tParam f tv p = innerJoin $ (`f` p) <$> tv

tParam2 :: (a -> b -> c -> Pattern d) -> Pattern a -> Pattern b -> c -> Pattern d
tParam2 f a b p = innerJoin $ (\x y -> f x y p) <$> a <*> b

tParam3 :: (a -> b -> c -> Pattern d -> Pattern e) -> (Pattern a -> Pattern b -> Pattern c -> Pattern d -> Pattern e)
tParam3 f a b c p = innerJoin $ (\x y z -> f x y z p) <$> a <*> b <*> c

tParamSqueeze :: (a -> Pattern b -> Pattern c) -> (Pattern a -> Pattern b -> Pattern c)
tParamSqueeze f tv p = unwrapSqueeze $ (`f` p) <$> tv

-- | Mark values in the first pattern which match with at least one
-- value in the second pattern.
matchManyToOne :: (b -> a -> Bool) -> Pattern a -> Pattern b -> Pattern (Bool, b)
matchManyToOne f pa pb = pa {query = q}
  where q st = map match $ query pb st
          where
            match (Event xWhole xPart x) =
              Event xWhole xPart (or $ (map (f x) (as $ start xWhole)), x)
            as s = map event $ query pa $ fQuery s
            fQuery s = st {arc = (Arc s s)}
