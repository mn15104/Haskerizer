{-# LANGUAGE CPP #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedStrings #-}

module TGA where


import Prelude hiding (any, mapM_)
import Control.Monad hiding (mapM_)
import Data.Foldable hiding (elem)
import Data.Maybe
import Foreign.C.Types
import SDL.Vect
import Data.Word8
import Data.Binary.Get
import Data.Word
import SDL (($=))
import qualified SDL
import qualified Data.ByteString as B
import Codec.Picture
import Codec.Picture.Types
import Data.Vector.Storable as V

-- data TGA_Header_t = TGA_Header_t {  idlength :: Char,
--                                 colormaptype :: Char,
--                                 datatypecode :: Char,
--                                 colormaporigin :: CShort,
--                                 colormaplength :: CShort,
--                                 colormapdepth :: Char,
--                                 x_origin :: CShort,
--                                 y_origin :: CShort,
--                                 width :: CShort, --17
--                                 height :: CShort,
--                                 bitsperpixel :: Char,
--                                 imagedescriptor :: Char
--                             }

data TGA_Header = TGA_Header {  width :: Int,
								height :: Int,
								imgdata :: V.Vector (PixelBaseComponent PixelRGB8),
                                bitsperpixel :: Int
                            }
				 | TGA_Error

read_tga :: String -> IO TGA_Header
read_tga filepath = do
	bytestr <- B.readFile filepath
	
	let contents = decodeTga bytestr
	    s = getWord16be
		
	return $ case contents of 
					Left s  -> TGA_Error
					Right d -> (case d of
						ImageRGB8  p' -> TGA_Header (imageWidth $   p')  (imageHeight $   p') ((imageData p'):: V.Vector (PixelBaseComponent PixelRGB8))  (8) 
						-- ImageRGBA8 p  -> TGA_Header (imageWidth $   p )  (imageHeight $   p ) (imageData p)  (8) 
						_ -> TGA_Error)
