
-- | The @repa-plugin@ rewrites client code to use these primitives.
--
--   The plugin will use whatever names are in scope, so if you want to debug
--   your code you can import a different implementation of these primitives
--   into the module to be vectorized.
--
module Data.Array.Repa.Series.Prim
        ( Primitives (..)
        , primitives )
where
import Data.Array.Repa.Series.Rate
import Data.Array.Repa.Series.Process
import Data.Array.Repa.Series.Vector    as V
import Data.Array.Repa.Series.Series    as S
import Data.Array.Repa.Series.Ref       as Ref
import Data.Array.Repa.Series.Prim.Utils
import Data.Array.Repa.Series.Prim.Loop
import Data.Array.Repa.Series.Prim.Int
import Data.Array.Repa.Series.Prim.Word
import Data.Array.Repa.Series.Prim.Float
import Data.Array.Repa.Series.Prim.Double
import GHC.Exts
import GHC.Types


-- | Primitives needed by the repa-plugin.
data Primitives
  = Primitives
  { -- Types ----------------------------------------------
    prim_Series                 :: forall k a. Series k a
  , prim_Vector                 :: forall a.   Vector a
  , prim_Ref                    :: forall a.   Ref a
  , prim_Down4                  :: forall k.   Down4 k
  , prim_Down8                  :: forall k.   Down8 k
  , prim_Tail4                  :: forall k.   Tail4 k
  , prim_Tail8                  :: forall k.   Tail8 k

    -- Series ---------------------------------------------
  , prim_natOfRateNat           :: forall k.   RateNat k  -> Word#
  , prim_rateOfSeries           :: forall k a. Series k a -> RateNat k
  , prim_down4                  :: forall k a. RateNat (Down4 k) -> Series k a -> Series (Down4 k) a
  , prim_down8                  :: forall k a. RateNat (Down8 k) -> Series k a -> Series (Down8 k) a
  , prim_tail4                  :: forall k a. RateNat (Tail4 k) -> Series k a -> Series (Tail4 k) a
  , prim_tail8                  :: forall k a. RateNat (Tail8 k) -> Series k a -> Series (Tail8 k) a

    -- Vector ---------------------------------------------
  , prim_tailVector4            :: forall k a. RateNat (Tail4 k) -> Vector a   -> Vector a
  , prim_tailVector8            :: forall k a. RateNat (Tail8 k) -> Vector a   -> Vector a

    -- Control --------------------------------------------
  , prim_makeProcess            :: (W -> W) -> Process

  , prim_loop                   :: Word#  -> (Word# -> W -> W)           
                                -> W -> W

  , prim_guard                  :: Ref Word -> Bool -> (Word# -> W -> W) 
                                -> W -> W

  , prim_split4                 :: forall k
                                .  RateNat k
                                -> (RateNat (Down4 k) -> W -> W)
                                -> (RateNat (Tail4 k) -> W -> W)
                                -> W -> W

  , prim_split8                 :: forall k
                                .  RateNat k
                                -> (RateNat (Down8 k) -> W -> W)
                                -> (RateNat (Tail8 k) -> W -> W)
                                -> W -> W

    -- Int ------------------------------------------------
  , prim_newRefInt              :: Int#                                 -> W -> (# W, Ref Int #)
  , prim_readRefInt             :: Ref Int                              -> W -> (# W, Int# #)
  , prim_writeRefInt            :: Ref Int -> Int#                      -> W -> W

  , prim_newVectorInt           :: Word#                                -> W -> (# W, Vector Int #)
  , prim_readVectorInt          :: Vector Int -> Word#                  -> W -> (# W, Int# #)
  , prim_writeVectorInt         :: Vector Int -> Word# -> Int#          -> W -> W
  , prim_truncVectorInt         :: Word# -> Vector Int                  -> W -> W

  , prim_nextInt                :: forall k
                                .  Series k Int -> Word#                -> W -> (# W, Int# #)

    -- Word ------------------------------------------------
  , prim_newRefWord             :: Word#                                -> W -> (# W, Ref Word  #)
  , prim_readRefWord            :: Ref Word                             -> W -> (# W, Word# #)
  , prim_writeRefWord           :: Ref Word -> Word#                    -> W -> W

  , prim_newVectorWord          :: Word#                                -> W -> (# W, Vector Word #)
  , prim_readVectorWord         :: Vector Word -> Word#                 -> W -> (# W, Word# #)
  , prim_writeVectorWord        :: Vector Word -> Word# -> Word#        -> W -> W
  , prim_truncVectorWord        :: Word# -> Vector Word                 -> W -> W

  , prim_nextWord               :: forall k
                                .  Series k Word -> Word#               -> W -> (# W, Word# #)

    -- Float ------------------------------------------------
  , prim_newRefFloat            :: Float#                               -> W -> (# W, Ref Float #)
  , prim_readRefFloat           :: Ref Float                            -> W -> (# W, Float# #)
  , prim_writeRefFloat          :: Ref Float -> Float#                  -> W -> W

  , prim_newVectorFloat         :: Word#                                -> W -> (# W, Vector Float #)
  , prim_readVectorFloat        :: Vector Float -> Word#                -> W -> (# W, Float# #)
  , prim_writeVectorFloat       :: Vector Float -> Word# -> Float#      -> W -> W
  , prim_writeVectorFloatX4     :: Vector Float -> Word# -> FloatX4#    -> W -> W
  , prim_writeVectorFloatX8     :: Vector Float -> Word# -> FloatX8#    -> W -> W
  , prim_truncVectorFloat       :: Word# -> Vector Float                -> W -> W

  , prim_nextFloat              :: forall k
                                .  Series k Float -> Word#              -> W -> (# W, Float# #)

  , prim_next4Float             :: forall k
                                .  Series (Down4 k) Float -> Word#      -> W -> (# W, FloatX4# #)

  , prim_next8Float             :: forall k
                                .  Series (Down8 k) Float -> Word#      -> W -> (# W, FloatX8# #)

  , prim_projFloatX4_0          :: FloatX4# -> Float#
  , prim_projFloatX4_1          :: FloatX4# -> Float#
  , prim_projFloatX4_2          :: FloatX4# -> Float#
  , prim_projFloatX4_3          :: FloatX4# -> Float#

  , prim_projFloatX8_0          :: FloatX8# -> Float#
  , prim_projFloatX8_1          :: FloatX8# -> Float#
  , prim_projFloatX8_2          :: FloatX8# -> Float#
  , prim_projFloatX8_3          :: FloatX8# -> Float#
  , prim_projFloatX8_4          :: FloatX8# -> Float#
  , prim_projFloatX8_5          :: FloatX8# -> Float#
  , prim_projFloatX8_6          :: FloatX8# -> Float#
  , prim_projFloatX8_7          :: FloatX8# -> Float#

    -- Double ------------------------------------------------
  , prim_newRefDouble           :: Double#                              -> W -> (# W, Ref Double #)
  , prim_readRefDouble          :: Ref Double                           -> W -> (# W, Double# #)
  , prim_writeRefDouble         :: Ref Double -> Double#                -> W -> W

  , prim_newVectorDouble        :: Word#                                -> W -> (# W, Vector Double #)
  , prim_readVectorDouble       :: Vector Double -> Word#               -> W -> (# W, Double# #)
  , prim_writeVectorDouble      :: Vector Double -> Word# -> Double#    -> W -> W
  , prim_writeVectorDoubleX2    :: Vector Double -> Word# -> DoubleX2#  -> W -> W
  , prim_writeVectorDoubleX4    :: Vector Double -> Word# -> DoubleX4#  -> W -> W
  , prim_truncVectorDouble      :: Word# -> Vector Double               -> W -> W

  , prim_nextDouble             :: forall k
                                .  Series k Double -> Word#             -> W -> (# W, Double# #)

  , prim_next2Double            :: forall k
                                .  Series (Down2 k) Float -> Word#      -> W -> (# W, DoubleX2# #)

  , prim_next4Double            :: forall k
                                .  Series (Down4 k) Float -> Word#      -> W -> (# W, DoubleX4# #)
  }


-- | Table of primitives used by the repa-plugin.
primitives :: Primitives
primitives
  = Primitives
  { -- These bindings are only used as proxies to get the associated type constructor.
    -- They don't need value level definitions.
    prim_Series = error "repa-series.primitives: you can't touch this."
  , prim_Vector = error "repa-series.primitives: you can't touch this."
  , prim_Ref    = error "repa-series.primitives: you can't touch this."
  , prim_Down4  = error "repa-series.primitives: you can't touch this."
  , prim_Down8  = error "repa-series.primitives: you can't touch this."
  , prim_Tail4  = error "repa-series.primitives: you can't touch this."
  , prim_Tail8  = error "repa-series.primitives: you can't touch this."


    -- Series ----------------------------------
  , prim_rateOfSeries           = S.rateOfSeries
  , prim_down4                  = down4
  , prim_down8                  = down8
  , prim_tail4                  = S.tail4
  , prim_tail8                  = S.tail8
  , prim_natOfRateNat           = rateOfRateNat

    -- Vector ----------------------------------
  , prim_tailVector4            = V.tail4
  , prim_tailVector8            = V.tail8

    -- Control ---------------------------------
  , prim_makeProcess            = makeProcess
  , prim_loop                   = repa_loop
  , prim_guard                  = repa_guard
  , prim_split4                 = repa_split4
  , prim_split8                 = repa_split8

    -- Int --------------------------------------
  , prim_newRefInt              = repa_newRefInt
  , prim_readRefInt             = repa_readRefInt
  , prim_writeRefInt            = repa_writeRefInt

  , prim_newVectorInt           = repa_newVectorInt
  , prim_readVectorInt          = repa_readVectorInt
  , prim_writeVectorInt         = repa_writeVectorInt
  , prim_truncVectorInt         = repa_truncVectorInt

  , prim_nextInt                = repa_nextInt

    -- Word --------------------------------------
  , prim_newRefWord             = repa_newRefWord
  , prim_readRefWord            = repa_readRefWord
  , prim_writeRefWord           = repa_writeRefWord

  , prim_newVectorWord          = repa_newVectorWord
  , prim_readVectorWord         = repa_readVectorWord
  , prim_writeVectorWord        = repa_writeVectorWord
  , prim_truncVectorWord        = repa_truncVectorWord

  , prim_nextWord               = repa_nextWord

    -- Float --------------------------------------
  , prim_newRefFloat            = repa_newRefFloat
  , prim_readRefFloat           = repa_readRefFloat
  , prim_writeRefFloat          = repa_writeRefFloat

  , prim_newVectorFloat         = repa_newVectorFloat
  , prim_readVectorFloat        = repa_readVectorFloat
  , prim_writeVectorFloat       = repa_writeVectorFloat
  , prim_writeVectorFloatX4     = repa_writeVectorFloatX4
  , prim_writeVectorFloatX8     = repa_writeVectorFloatX8
  , prim_truncVectorFloat       = repa_truncVectorFloat

  , prim_nextFloat              = repa_nextFloat
  , prim_next4Float             = repa_next4Float
  , prim_next8Float             = repa_next8Float

  , prim_projFloatX4_0          = \x -> case unpackFloatX4# x of { (# f, _, _, _ #) -> f }
  , prim_projFloatX4_1          = \x -> case unpackFloatX4# x of { (# _, f, _, _ #) -> f }
  , prim_projFloatX4_2          = \x -> case unpackFloatX4# x of { (# _, _, f, _ #) -> f }
  , prim_projFloatX4_3          = \x -> case unpackFloatX4# x of { (# _, _, _, f #) -> f }

  , prim_projFloatX8_0          = \x -> case unpackFloatX8# x of { (# f, _, _, _, _, _, _, _ #) -> f }
  , prim_projFloatX8_1          = \x -> case unpackFloatX8# x of { (# _, f, _, _, _, _, _, _ #) -> f }
  , prim_projFloatX8_2          = \x -> case unpackFloatX8# x of { (# _, _, f, _, _, _, _, _ #) -> f }
  , prim_projFloatX8_3          = \x -> case unpackFloatX8# x of { (# _, _, _, f, _, _, _, _ #) -> f }
  , prim_projFloatX8_4          = \x -> case unpackFloatX8# x of { (# _, _, _, _, f, _, _, _ #) -> f }
  , prim_projFloatX8_5          = \x -> case unpackFloatX8# x of { (# _, _, _, _, _, f, _, _ #) -> f }
  , prim_projFloatX8_6          = \x -> case unpackFloatX8# x of { (# _, _, _, _, _, _, f, _ #) -> f }
  , prim_projFloatX8_7          = \x -> case unpackFloatX8# x of { (# _, _, _, _, _, _, _, f #) -> f }

    -- Double --------------------------------------
  , prim_newRefDouble           = repa_newRefDouble
  , prim_readRefDouble          = repa_readRefDouble
  , prim_writeRefDouble         = repa_writeRefDouble

  , prim_newVectorDouble        = repa_newVectorDouble
  , prim_readVectorDouble       = repa_readVectorDouble
  , prim_writeVectorDouble      = repa_writeVectorDouble
  , prim_writeVectorDoubleX2    = repa_writeVectorDoubleX2
  , prim_writeVectorDoubleX4    = repa_writeVectorDoubleX4
  , prim_truncVectorDouble      = repa_truncVectorDouble

  , prim_nextDouble             = repa_nextDouble
  , prim_next2Double            = repa_next2Double
  , prim_next4Double            = repa_next4Double
  }

