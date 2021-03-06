{-# LANGUAGE OverloadedStrings #-}


        -- |‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾| -- 
        -- |                                                                        | -- 
        -- |                            UTILITY FUNCTIONS                           | -- 
        -- |                                                                        | -- 
        -- |                                                                        | -- 
        --  ‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾  -- 

module Util
    where

import Prelude hiding (any, mapM_)
import Control.Monad hiding (mapM_)
import Control.Arrow ((***))
import Data.Foldable hiding (elem)
import Data.Maybe
import Data.Word8
import Data.List as List
import Data.Cross
import SDL (($=))
import SDL.Vect
import qualified SDL
import qualified Data.Vector as Vector
import Data.Vec as Vec hiding (take, drop, foldr, map)
import qualified Data.Vec as Vec (take, drop, foldr, map)
import Codec.Picture
import Codec.Picture.Types
import Debug.Trace as Trace
import Foreign.C.Types
import Control.Parallel

    ---- |‾| -------------------------------------------------------------- |‾| ----
     --- | |                          Miscellaneous                         | | ---
      --- ‾------------------------------------------------------------------‾---

clamp_min :: Double -> Double -> Double -> Double
{-# INLINE clamp_min #-}
clamp_min x y minval = max (min x y) minval

clamp_max :: Double -> Double -> Double -> Double
{-# INLINE clamp_max #-}
clamp_max x y maxval = min (max x y) maxval

to_double :: Int -> Double
{-# INLINE to_double #-}
to_double x = fromIntegral x

debug :: (Show a) => a -> b -> b
debug x f =   Trace.trace (show x) f

    ---- |‾| -------------------------------------------------------------- |‾| ----
     --- | |                      List/Vector Helpers                       | | ---
      --- ‾------------------------------------------------------------------‾---
par2_reduce :: (Double, Vec.Vec4 Word8) -> (Double, Vec.Vec4 Word8) -> (Double, Vec.Vec4 Word8) 
{-# INLINE par2_reduce #-}
par2_reduce as bs  = (\a b  -> (\(depth1, color1) (depth2, color2) -> if depth1 > depth2 then (depth1, color1) else (depth2, color2)) a b ) as bs

par2 :: (a -> b -> c) -> (a -> b -> c)
{-# INLINE par2 #-}
par2 f x y = x `par` y `par` f x y

par4_reduce :: (Double, Vec.Vec4 Word8) -> (Double, Vec.Vec4 Word8) -> (Double, Vec.Vec4 Word8) -> (Double, Vec.Vec4 Word8) -> (Double, Vec.Vec4 Word8) 
par4_reduce as bs cs ds = (\(depth1, color1) (depth2, color2)  (depth3, color3)  (depth4, color4) -> 
                                                (let max_depth = List.maximum [depth1, depth2, depth3, depth4]
                                                 in case () of  
                                                                      _ | max_depth == depth1 -> (depth1, color1) 
                                                                        | max_depth == depth2 -> (depth2, color2)
                                                                        | max_depth == depth3 -> (depth3, color3)
                                                                        | max_depth == depth4 -> (depth4, color4))) as bs cs ds                                                       
par4 :: (a -> b -> c -> d -> e) -> (a -> b -> c -> d -> e)
par4 f  = \ x y s t -> x `par` y `par` s `par` t  `par` f x y s t


reduce_zbuffer :: [Vector.Vector (Double, Vec.Vec4 Word8)] ->  (Vector.Vector (Double, Vec4 Word8))
reduce_zbuffer zbuffers =  foldr (\veca vecb -> Vector.map (\((zindex1, rgba1),(zindex2, rgba2)) -> if zindex1 > zindex2 then (zindex1, rgba1) else (zindex2, rgba2)) (Vector.zip veca vecb) ) Vector.empty zbuffers

stringListToVec3List :: [String] -> [Vec3 Double]
stringListToVec3List str = case str of (x:xs) -> let (a:b:c:_) = take 3 (str) in ((Vec.fromList [read a,read b,read c]):(stringListToVec3List $ drop 3 str))
                                       [] -> []

stringListToVec2List :: [[String]] -> [Vec2 Double]
stringListToVec2List str = [(Vec.fromList [ (read a) ,(read b) ]) | (a:b:_) <- (str) ]

stringListToVec3ListI :: [[String]] -> [Vec3 Integer]
stringListToVec3ListI str = [(Vec.fromList [ (read a) ,(read b) , (read c)] ) | (a:b:c:_) <- (str) ]

replaceAt :: a -> Int -> Vector.Vector a -> Vector.Vector a
{-# INLINE replaceAt #-}
replaceAt newElement n array = (Vector.take n array) Vector.++  (newElement `Vector.cons` Vector.drop (n + 1) array)

    ---- |‾| -------------------------------------------------------------- |‾| ----
     --- | |                      Tuples & Mapping                          | | ---
      --- ‾------------------------------------------------------------------‾---

mapTuple2 :: (a -> b) -> (a, a) -> (b, b)
{-# INLINE mapTuple2 #-}
mapTuple2 f (a1, a2) = (f a1, f a2)

mapTuple3 :: (a -> b) -> (a, a, a) -> (b, b, b)
{-# INLINE mapTuple3 #-}
mapTuple3 f (a1, a2, a3) = (f a1, f a2, f a3)

mapTuple4 :: (a -> b) -> (a, a, a, a) -> (b, b, b, b)
{-# INLINE mapTuple4 #-}
mapTuple4 f (a1, a2, a3, a4) = (f a1, f a2, f a3, f a4)

map2 :: (Functor f) => (a -> b) -> f (f a) -> f (f b)
map2 f fa = fmap (fmap f) fa

map3 :: (Functor f) => (a -> b) -> f (f (f a)) -> f (f (f b))
map3 f fa = fmap (fmap (fmap f)) fa

listToTuple3 :: [a] -> (a, a, a)
listToTuple3 as = (as !! 0, as !! 1, as !! 2)

    ---- |‾| -------------------------------------------------------------- |‾| ----
     --- | |                      Vec Unpacking/Packing                     | | ---
      --- ‾------------------------------------------------------------------‾---


toVec2 :: a -> a -> Vec2 a
{-# INLINE toVec2 #-}
toVec2 x y = Vec.fromList [x,y]

toVec3 :: a -> a -> a -> Vec3 a
{-# INLINE toVec3 #-}
toVec3 x y z = Vec.fromList [x,y,z]

toVec4 :: a -> a -> a -> a -> Vec4 a
{-# INLINE toVec4 #-}
toVec4 x y z w = Vec.fromList [x,y,z,w]

toVec2Zeros ::  Vec2 Double
toVec2Zeros = Vec.fromList $ replicate 2 0.0

toVec3Zeros ::  Vec3 Double
toVec3Zeros = Vec.fromList $ replicate 3 0.0

toVec4Zeros ::  Vec4 Double
toVec4Zeros = Vec.fromList $ replicate 4 0.0

fromVec2 :: Vec2 a -> ( a , a )
{-# INLINE fromVec2 #-}
fromVec2 xy =  let [x,y] = Vec.toList xy
                in (x,y)

fromVec3 :: Vec3 a ->  (a , a, a)
{-# INLINE fromVec3 #-} 
fromVec3 xyz = let [x,y,z] = Vec.toList xyz
                in (x,y,z)

fromVec4 :: Vec4 a -> (a, a, a, a)
{-# INLINE fromVec4 #-}
fromVec4 xyzw = let [x,y,z,w] = Vec.toList xyzw 
                in (x,y,z,w)



setElemV2 :: Int -> Vec2 a -> a -> Vec2 a 
setElemV2 n v a = let (x, y) = fromVec2 v
                  in (case n of 0 -> toVec2 a y 
                                1 -> toVec2 x a 
                                _ -> toVec2 x y )


setElemV3 :: Int -> Vec3 a -> a -> Vec3 a 
setElemV3 n v a = let (x, y, z) = fromVec3 v
                  in (case n of 0 -> toVec3 a y z   
                                1 -> toVec3 x a z
                                2 -> toVec3 x y a
                                _ -> toVec3 x y z)

setElemV4 :: Int -> Vec4 a -> a -> Vec4 a 
setElemV4 n v a = let (x, y, z, w) = fromVec4 v
                  in (case n of 0 -> toVec4 a y z w  
                                1 -> toVec4 x a z w
                                2 -> toVec4 x y a w
                                3 -> toVec4 x y z a
                                _ -> toVec4 x y z w)

getElemV2 :: Int -> Vec2 a -> a 
getElemV2 n v   = let (x, y) = fromVec2 v
                  in (case n of 0 -> x
                                1 -> y
                                _ -> x)

getElemV3 :: Int -> Vec3 a -> a
getElemV3 n v = let (x, y, z) = fromVec3 v
                  in (case n of 0 -> x
                                1 -> y
                                2 -> z
                                _ -> x)

getElemV4 :: Int -> Vec4 a -> a 
getElemV4 n v   = let (x, y, z, w) = fromVec4 v
                  in (case n of 0 -> x
                                1 -> y
                                2 -> z
                                3 -> w
                                _ -> x)



    ---- |‾| -------------------------------------------------------------- |‾| ----
     --- | |                      Vec LinAlg & Conversions                  | | ---
      --- ‾------------------------------------------------------------------‾---
  

projectVec3to2 :: (Num a) => Vec3 a -> Vec2 a
projectVec3to2 v3 = let (x,y,z) = fromVec3 v3 in toVec2 x y 

projectVec4to2D :: Vec4 Double -> Vec2 Double
{-# INLINE projectVec4to2D #-}
projectVec4to2D v4 = let (x,y,z,w) = fromVec4 v4 in toVec2 (x/w) (y/w) --(x/z) (y/z) 

cartesianToHomogeneous ::  Vec3 Double -> Vec4 Double
{-# INLINE cartesianToHomogeneous #-}
cartesianToHomogeneous v3 = let (x,y,z) = fromVec3 v3 in toVec4 x y z 1


homogeneousToCartesian ::  Vec4 Double -> Vec3 Double
{-# INLINE homogeneousToCartesian #-}
homogeneousToCartesian v4 = let (x,y,z,w) = fromVec4 v4 in toVec3 (x/w) (y/w) (z/w)

or_Vec3 :: Vec3 Double -> Vec3 Double -> Vec3 Double
or_Vec3 (a) (b) = toVec3 (ay * bz - az * by)  (az * bx - ax * bz)  (ax * by - ay * bx)
            where (ax, ay, az) = fromVec3 a
                  (bx, by, bz) = fromVec3 b
              
    ---- |‾| -------------------------------------------------------------- |‾| ----
     --- | |                        RGBA Arithmetic                         | | ---
      --- ‾------------------------------------------------------------------‾---
  
mult_rgba_d ::  Vec4 Word8 -> Double -> Vec4 Word8
{-# INLINE mult_rgba_d #-}
mult_rgba_d rgba intensity =  let   scale =  case () of _ 
                                                            | intensity > 1.0 -> 1.0
                                                            | intensity < 0.0 -> 0.0
                                                            | otherwise -> intensity
                                    (r, g, b, a) = (mapTuple4 ((fromInteger) . (floor) . (scale *) . (fromIntegral)) (fromVec4 rgba) ) :: (Word8, Word8, Word8, Word8)
                              in    toVec4 r g b a

add_rgba_d ::  Vec4 Word8 -> Double -> Vec4 Word8
{-# INLINE add_rgba_d #-}
add_rgba_d rgba scalar =      let   (r, g, b, a) = (mapTuple4 (fromIntegral) (fromVec4 rgba)) :: (Double, Double, Double, Double)
                                    addword8 = (\channel -> case () of _ 
                                                                         | ((channel + scalar) >= 255.0) -> 254
                                                                         | ((channel + scalar) < 0.0  ) -> 0
                                                                         | otherwise -> (fromInteger $ floor (channel + scalar)) ) :: Double -> Word8
                                    (r', g', b', a') = (mapTuple4  ((addword8 ) . (fromIntegral). (fromIntegral)) (fromVec4 rgba)) 
                              in    toVec4 r' g' b' a' -- (fromInteger (floor a))
    ---- |‾| -------------------------------------------------------------- |‾| ----
     --- | |                 Vec to SDL.Vector Conversions                  | | ---
      --- ‾------------------------------------------------------------------‾---

vec2ToV2 :: Vec2 a -> V2 a
vec2ToV2 (x:.y:.()) = V2 x y

vec3ToV3 :: Vec3 a -> V3 a
vec3ToV3 (x:.y:.z:.()) = V3 x y z

vec4ToV4 :: Vec4 a -> V4 a
vec4ToV4 (x:.y:.z:.w:.()) = V4 x y z w



-- vec4ToV4 :: Vec4 a -> V4 a
-- vec4ToV4 (x:.y:.z:.w:.()) = V4 x y z w
