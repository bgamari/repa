
-- | Converting `Stream`s and `Chain`s to and from generic `Vector`s.
--
--   * NOTE: Support for streams of unknown length is not complete.
--
module Data.Repa.Vector.Generic
        ( -- * Stream functions
          unstreamToVector2
        , unstreamToMVector2

          -- * Chain functions
        , chainOfVector
        , unchainToVector
        , unchainToMVector)
where
import Data.Repa.Chain                                  as C
import qualified Data.Vector.Generic                    as GV
import qualified Data.Vector.Generic.Mutable            as GM
import qualified Data.Vector.Fusion.Stream.Monadic      as S
import qualified Data.Vector.Fusion.Stream.Size         as S
import Control.Monad.Primitive
#include "repa-stream.h"


-------------------------------------------------------------------------------
-- | Unstream some elements to two separate vectors.
--
--   `Nothing` values are ignored.
--
unstreamToVector2
        :: (PrimMonad m, GV.Vector v a, GV.Vector v b)
        => S.Stream m (Maybe a, Maybe b)
                                -- ^ Source data.
        -> m (v a, v b)         -- ^ Resulting vectors.

unstreamToVector2 s
 = do   (mvec1, mvec2) <- unstreamToMVector2 s
        vec1    <- GV.unsafeFreeze mvec1
        vec2    <- GV.unsafeFreeze mvec2
        return (vec1, vec2)
{-# INLINE_STREAM unstreamToVector2 #-}


-- | Unstream some elements to two separate mutable vectors.
--
--   `Nothing` values are ignored.
--
unstreamToMVector2
        :: (PrimMonad m, GM.MVector v a, GM.MVector v b)
        => S.Stream m (Maybe a, Maybe b)                
                                -- ^ Source data.
        -> m (v (PrimState m) a, v (PrimState m) b)     
                                -- ^ Resulting vectors.

unstreamToMVector2 (S.Stream step s0 sz)
 = case sz of
        S.Exact i       -> unstreamToMVector2_max  i s0 step
        S.Max   i       -> unstreamToMVector2_max  i s0 step
        S.Unknown       -> error "repa-stream: finish unstreamToMVector2"
{-# INLINE_STREAM unstreamToMVector2 #-}

unstreamToMVector2_max nMax s0 step
 =  GM.unsafeNew nMax >>= \vecL
 -> GM.unsafeNew nMax >>= \vecR
 -> let 
        go !sPEC !iL !iR !s
         =  step s >>= \m
         -> case m of
                S.Yield (mL, mR) s'
                 -> do  !iL' <- case mL of
                                Nothing -> return iL
                                Just xL -> do GM.unsafeWrite vecL iL xL
                                              return (iL + 1)

                        !iR' <- case mR of
                                Nothing -> return iR
                                Just xR -> do GM.unsafeWrite vecR iR xR
                                              return (iR + 1)

                        go sPEC iL' iR' s'
                       
                S.Skip s' 
                 ->     go sPEC iL iR s'

                S.Done
                 ->     return  ( GM.unsafeSlice 0 iL vecL
                                , GM.unsafeSlice 0 iR vecR)
    in go S.SPEC 0 0 s0
{-# INLINE_STREAM unstreamToMVector2_max #-}


-------------------------------------------------------------------------------
-- | Produce a chain from a generic vector.
chainOfVector 
        :: (Monad m, GV.Vector v a)
        => v a -> Chain m Int a

chainOfVector vec
 = Chain (S.Exact len) 0 step
 where
        !len  = GV.length vec

        step !i
         | i >= len
         = return $ Done  i

         | otherwise    
         = return $ Yield (GV.unsafeIndex vec i) (i + 1)
        {-# INLINE_INNER step #-}
{-# INLINE_STREAM chainOfVector #-}


-------------------------------------------------------------------------------
-- | Compute a chain into a generic vector.
unchainToVector
        :: (PrimMonad m, GV.Vector v a)
        => C.Chain m s a  -> m (v a, s)
unchainToVector chain
 = do   (mvec, c') <- unchainToMVector chain
        vec        <- GV.unsafeFreeze mvec
        return (vec, c')
{-# INLINE_STREAM unchainToVector #-}


-- | Compute a chain into a generic mutable vector.
unchainToMVector
        :: (PrimMonad m, GM.MVector v a)
        => Chain m s a
        -> m (v (PrimState m) a, s)

unchainToMVector (Chain sz s0 step)
 = case sz of
        S.Exact i       -> unchainToMVector_max     i  s0 step
        S.Max i         -> unchainToMVector_max     i  s0 step
        S.Unknown       -> unchainToMVector_unknown 32 s0 step
{-# INLINE_STREAM unchainToMVector #-}


-- unchain when we known the maximum size of the vector.
unchainToMVector_max nMax s0 step 
 =  GM.unsafeNew nMax >>= \vec
 -> let 
        go !sPEC !i !s
         =  step s >>= \m
         -> case m of
                Yield e s'
                 -> do  GM.unsafeWrite vec i e
                        go sPEC (i + 1) s'

                Skip s' -> go sPEC i s'
                Done s' -> return (GM.unsafeSlice 0 i vec, s')
        {-# INLINE_INNER go #-}

    in  go S.SPEC 0 s0
{-# INLINE_STREAM unchainToMVector_max #-}


-- unchain when we don't know the maximum size of the vector.
unchainToMVector_unknown nStart s0 step
 =  GM.unsafeNew nStart >>= \vec0
 -> let 
        go !sPEC !vec !i !n !s
         =  step s >>= \m
         -> case m of
                Yield e s'
                 | i >= n       
                 -> do  vec'    <- GM.unsafeGrow vec n
                        GM.unsafeWrite vec' i e
                        go sPEC vec' (i + 1) (n + n) s'

                 | otherwise
                 -> do  GM.unsafeWrite vec i e
                        go sPEC vec  (i + 1) n s'

                Skip s' -> go sPEC vec i n s'
                Done s' -> return (GM.unsafeSlice 0 i vec, s')
        {-# INLINE_INNER go #-}

    in go S.SPEC vec0 0 nStart s0
{-# INLINE_STREAM unchainToMVector_unknown #-}

