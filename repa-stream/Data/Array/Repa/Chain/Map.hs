
module Data.Array.Repa.Chain.Map
        ( map,          mapD
        , zipWith,      zipWithD
        , zipWith3
        , zipWith4)
where
import Data.Array.Repa.Chain.Base
import Prelude  hiding (map, zipWith, zipWith3)


-- map ------------------------------------------------------------------------
-- | Apply a function to every element of a chain.
map :: (a -> b) -> Chain a -> Chain b
map f (Chain len start next)
 = Chain len start next'
 where  next' ix s
         = case next ix s of
                Yield  s' x     -> Yield  s' (f x)
                Update s'       -> Update s'
{-# INLINE [1] map #-}


-- | Apply a function to every element of a distributed chain.
mapD :: (a -> b) -> DistChain a -> DistChain b
mapD f (DistChain distro frag)
 = DistChain distro frag'
 where  frag' c' = map f (frag c')
{-# INLINE [1] mapD #-}



-- zipWith ---------------------------------------------------------------------
data T2 a b
        = T2 !a !b


-- | Zip two chains with the same length.
--   If they don't have the same length then undefined.
zipWith :: (a -> b -> c) -> Chain a -> Chain b -> Chain c
zipWith f (Chain len1 start1 next1)
          (Chain _    start2 next2)
 = Chain len1 (T2 start1 start2) next'
 where  
        next' ix (T2 s1 s2)
         = case (next1 ix s1, next2 ix s2) of
                (Yield  s1' x1, Yield s2' x2)   -> Yield  (T2 s1' s2') (f x1 x2)
                (Update s1',    _)              -> Update (T2 s1' s2)
                (_,             Update s2')     -> Update (T2 s1  s2')
{-# INLINE [1] zipWith #-}


-- | Zip two chains that have the same distribution. 
--   If they don't have the same distribution then undefined.
zipWithD :: (a -> b -> c) -> DistChain a -> DistChain b -> DistChain c
zipWithD f (DistChain distro1 frag1) (DistChain _ frag2)
 = DistChain distro1 frag'
 where  frag' i = zipWith f (frag1 i) (frag2 i)
{-# INLINE [1] zipWithD #-}


-- | Zip three chains with the same length.
zipWith3 :: (a -> b -> c -> d)
         -> Chain a -> Chain b -> Chain c 
         -> Chain d

zipWith3 f c1 c2 c3 
 = zipWith 
        (\x1 (x2, x3) -> f x1 x2 x3)
        c1
        (zipWith (,) c2 c3)
{-# INLINE zipWith3 #-}


-- | Zip four chains with the same length.
zipWith4 :: (a -> b -> c -> d -> e)
         -> Chain a -> Chain b -> Chain c -> Chain d
         -> Chain e

zipWith4 f c1 c2 c3 c4 
 = zipWith 
        (\(T2 x1 x2) (T2 x3 x4) -> f x1 x2 x3 x4)
        (zipWith T2 c1 c2)
        (zipWith T2 c3 c4)
{-# INLINE zipWith4 #-}

