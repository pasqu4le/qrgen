module Main where
import Data.QRCode
import Data.Char (chr)
import Data.Word (Word8)
import Graphics.Image (writeImage, Image(..), fromListsR)
import Graphics.Image.ColorSpace (Pixel( PixelY ))
import Graphics.Image.Interface.Vector (VU(..))
import Graphics.Image.Processing (scale, Nearest(..), Border(..))
import Options.Applicative
import Data.Semigroup ((<>))

-- options

data Generator = Generator {input :: String, border :: Int, scaling :: Double,
                            out :: OutPut}
data OutPut = FileOutput FilePath | StdOut

-- argument parsing functions

opts :: Parser Generator
opts = Generator
  <$> strOption
    ( long "input"
    <> short 'i'
    <> metavar "STRING"
    <> help "Input text for the QR code" )
  <*> option auto
    ( long "border"
    <> short 'b'
    <> metavar "INT"
    <> help "Border size (1 or more suggested)"
    <> showDefault
    <> value 3)
  <*> option auto
    ( long "scale"
    <> short 's'
    <> metavar "DOUBLE"
    <> help "Scale the image by a factor (ignored by terminal)"
    <> showDefault
    <> value 10.0 )
  <*> (fileOut <|> stdOut)

fileOut :: Parser OutPut
fileOut = FileOutput <$> strOption
  (  long "output"
  <> short 'o'
  <> metavar "FILENAME"
  <> help "Write result to output image" )

stdOut :: Parser OutPut
stdOut = flag StdOut StdOut
  ( long "print"
  <> short 'p'
  <> help "Write to terminal (default)" )

main :: IO ()
main = generate =<< execParser options
  where
    options = info (opts <**> helper)
      ( fullDesc
     <> progDesc "QR code generator"
     <> header "Simple QR code generator; outputs to Image File or Terminal" )

-- actual generator functions

generate :: Generator -> IO ()
generate (Generator inputString border scaling output) = do
  qrcode <- encodeString inputString Nothing QR_ECLEVEL_L QR_MODE_KANJI True
  let width = getQRCodeWidth qrcode
      matrix = applyBorder border width $ toMatrix qrcode
  outputResult output scaling matrix

applyBorder :: Int -> Int -> [[Word8]] -> [[Word8]]
applyBorder n w matrix = addition ++ map (applyOffset n) matrix ++ addition
  where addition = replicate n $ replicate (2*n + w) 0

applyOffset :: Int -> [Word8] -> [Word8]
applyOffset n line = offset ++ line ++ offset
  where offset = replicate n 0

outputResult :: OutPut -> Double -> [[Word8]] -> IO ()
outputResult output s = case output of
  FileOutput filePath -> writeImage filePath . scale Nearest Edge (s,s) . fromListsR VU . map (map (PixelY . toDouble))
  _ -> mapM_ putStrLn . toBlockLines

toDouble :: Word8 -> Double
toDouble 0 = 1.0
toDouble _ = 0.0

toBlockLines :: [[Word8]] -> [String]
toBlockLines [] = []
toBlockLines (x1:x2:xs) = zipWith toBlock x1 x2 : toBlockLines xs
toBlockLines [x] = [map (`toBlock` 0) x]

toBlock :: Word8 -> Word8 -> Char
toBlock a b = case (a, b) of
  (0,0) -> '\x2588'
  (0,1) -> '\x2580'
  (1,0) -> '\x2584'
  _ -> ' '
