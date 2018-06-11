{-# LANGUAGE OverloadedStrings #-}

module Model
    where

import Prelude
import Prelude hiding (any, mapM_)
import Control.Monad hiding (mapM_)
import Data.Foldable hiding (elem)
import Data.Maybe
import Data.Word8
import System.Environment
import Data.Char as Char
import Data.List
import Data.Matrix as Matrix
import Data.Cross
import qualified Data.Vector as V
import qualified Data.Vector.Storable as VS
import Foreign.C.Types
import SDL.Vect
import SDL (($=))
import System.IO
import qualified SDL
import Control.Lens

import Data.List.Split
import TGA
import Util
import Codec.Picture
import Codec.Picture.Types
import Camera
import SDL_Aux
import Light



data Model = Model {verts       :: V.Vector (V3 Double, Int),
                    faces       :: V.Vector ([(V3 Integer, Int)]),
                    norms       :: V.Vector (V3 Double, Int),
                    uvs         :: V.Vector (V2 Double, Int),
                    diffuse_map :: TGA_Header,
                    nfaces :: Int,
                    nverts :: Int}

load_model :: IO Model
load_model = do
    args <- getArgs
    content <- readFile (args !! 0)
    let linesOfFile = lines content
    
        verts = stringListToV3List $ concat $ map ((filter valid_obj_num) . words) $ filter (\l -> (case l of   (x:y:_) -> x == 'v' && y == ' '
                                                                                                                _ -> False)) linesOfFile

        norms = stringListToV3List $ concat $ map ((filter valid_obj_num) . words) $ filter (\l -> (case l of   (x:y:_) -> x == 'v' && y == 'n'
                                                                                                                _ -> False)) linesOfFile

        uvs   = stringListToV2List $ map ((filter valid_obj_num) . words) $ filter (\l -> (case l of    (x:y:xs) -> x == 'v' && y == 't'
                                                                                                        _ -> False)) linesOfFile
        
        faces1 =    map2 ((filter valid_obj_num) . (words) . (map (\c -> if (c == '/') then ' ' else c)) ) $ 
                                map words $ filter (\l -> (case l of (x:xs) -> x == 'f'
                                                                     _ -> False)) linesOfFile
                                                                     
        faces2 = stringListToV3ListI [z | x <- faces1, z <- x, not (null z)]
        faces3 = chunksOf 3 $ map (\n -> (n - 1)) faces2

        nats = 1 : map (+1) (nats)

        faces'' = (V.fromList (zipWith (\f i -> zipWith (\f' i' -> (f', (head i)+i')) f (nats)) faces3 (map (\x -> [x]) ((nats :: [Int])) :: [[Int]]))) :: V.Vector ([(V3 Integer, Int)])
        verts'' = (V.fromList (zipWith (\f i -> (f, i)) verts (nats :: [Int]))) :: V.Vector (V3 Double, Int)
        norms'' = (V.fromList (zipWith (\f i -> (f, i)) norms (nats :: [Int]))) :: V.Vector (V3 Double, Int)
        uvs'' =   (V.fromList (zipWith (\f i -> (f, i)) uvs (nats :: [Int]))) :: V.Vector (V2 Double, Int)

    diffuse_map <- read_tga "resources/african_head_diffuse.tga"
    
    return $ Model verts'' faces'' norms'' uvs'' diffuse_map (length faces'') (length verts'')



model_face :: Model -> Int -> [Integer]
model_face model ind = [x | face_v3 <- ((faces model) V.! ind), let V3 x y z = fst face_v3]

model_vert :: Model -> Int -> V3 Double
model_vert model ind = fst $ (verts model) V.! ind

model_uv :: Model -> Int -> Int -> V2 Int
model_uv model iface nvert = let V3 x y z = fst $ ((faces model) V.! iface) !! nvert
                                 V2 x' y' = fst $ (uvs model) V.! ( fromIntegral y)
                             in  V2  (floor (x' * (fromIntegral $ TGA.width $ diffuse_map model)))  (floor (y' * (fromIntegral $ TGA.height $ diffuse_map model))) ----- UPDATE THIS

model_diffuse :: Model -> V2 Int -> V4 Word8
model_diffuse model (V2 u v) = let  dm = diffuse_map model
                                    image = img dm
                                    PixelRGB8 r g b = pixelAt image u v
                                in V4 r g b 255

valid_obj_num :: String  -> Bool
valid_obj_num ""  = False
valid_obj_num xs  =
  case dropWhile Char.isDigit xs of
    ""       -> True
    ('.':ys) -> valid_obj_num ys
    ('-':ys) -> valid_obj_num ys
    ('e':'-':ys) -> all Char.isDigit ys
    _        -> False


